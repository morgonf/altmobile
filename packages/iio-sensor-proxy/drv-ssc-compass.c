/*
 * Copyright (c) 2023-2025 Dylan Van Assche
 * Copyright (c) 2026 morgonf
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3 as published by
 * the Free Software Foundation.
 */

/*
 * Compass for SSC devices whose SLPI firmware has no virtual compass
 * (OnePlus 6T: no rotation vector, no calibrated magnetometer).
 *
 * The heading is computed here from the raw SSC magnetometer and
 * accelerometer, which the SLPI already reports in the same device frame
 * (Android convention: x right, y to the top edge, z out of the screen).
 * The hard-iron offset of the magnetometer is estimated online with a
 * sphere fit over samples spread across all directions and persisted in
 * STATE_FILE, so the compass is right from the next start.
 *
 * Sensors are created asynchronously: the *_new_sync() calls of libssc
 * iterate the main context, and a D-Bus call dispatched during that
 * iteration crashed the daemon on start-up.
 */

#include "drivers.h"

#include <math.h>
#include <stdio.h>
#include <string.h>
#include <gio/gio.h>
#include <libssc-sensor.h>
#include <libssc-sensor-accelerometer.h>
#include <libssc-sensor-magnetometer.h>

#define STATE_FILE "/var/lib/iio-sensor-proxy/mag-calibration"
#define N_BINS 26
#define BIN_MAX_AGE_US (30 * 60 * G_USEC_PER_SEC)
#define FIT_EVERY 10
#define FILTER_ALPHA 0.2

typedef struct {
	double v[3];
	gint64 time;
	gboolean used;
} Bin;

typedef struct DrvData {
	SSCSensorMagnetometer *mag;
	SSCSensorAccelerometer *accel;
	GCancellable *cancellable;
	gulong mag_id;
	gulong accel_id;
	gboolean want_polling;
	gboolean polling;

	double accel_f[3];
	double mag_f[3];
	gboolean have_accel;
	gboolean have_mag;

	double offset[3];
	double radius;
	gboolean calibrated;
	Bin bins[N_BINS];
	guint new_samples;
	/* Until the first fit: centre of the min/max box as a rough offset */
	double minv[3];
	double maxv[3];
	gboolean have_box;
} DrvData;

static gboolean
ssc_compass_discover (GUdevDevice *device)
{
	/* Only the udev type is checked: opening SSC sensors synchronously
	 * here spins the main loop before the daemon is ready. */
	if (!drv_check_udev_sensor_type (device, "ssc-compass", NULL))
		return FALSE;

	g_debug ("Found SSC compass (magnetometer + accelerometer) at %s",
		 g_udev_device_get_sysfs_path (device));
	return TRUE;
}

static void
load_calibration (DrvData *d)
{
	g_autofree char *contents = NULL;
	double x, y, z, r;

	if (!g_file_get_contents (STATE_FILE, &contents, NULL, NULL))
		return;
	if (sscanf (contents, "%lf %lf %lf %lf", &x, &y, &z, &r) != 4)
		return;
	d->offset[0] = x;
	d->offset[1] = y;
	d->offset[2] = z;
	d->radius = r;
	d->calibrated = TRUE;
	g_debug ("SSC compass: loaded hard-iron offset %.1f %.1f %.1f, field %.1f uT", x, y, z, r);
}

static void
save_calibration (DrvData *d)
{
	g_autofree char *contents = NULL;
	g_autoptr(GError) error = NULL;

	contents = g_strdup_printf ("%.2f %.2f %.2f %.2f\n",
				    d->offset[0], d->offset[1], d->offset[2], d->radius);
	if (!g_file_set_contents (STATE_FILE, contents, -1, &error))
		g_warning ("SSC compass: saving calibration failed: %s", error->message);
}

/* Direction bin of a vector: each component rounded to -1, 0 or 1,
 * 26 bins in total (the zero vector is excluded). */
static int
bin_index (const double u[3])
{
	int idx = 0;
	for (int i = 0; i < 3; i++) {
		int c = (u[i] > 0.4) ? 2 : (u[i] < -0.4) ? 0 : 1;
		idx = idx * 3 + c;
	}
	/* 13 is (0, 0, 0) */
	return idx > 13 ? idx - 1 : idx;
}

/* Solve a 4x4 linear system in place, Gaussian elimination with pivoting. */
static gboolean
solve4 (double a[4][5])
{
	for (int col = 0; col < 4; col++) {
		int piv = col;
		for (int r = col + 1; r < 4; r++)
			if (fabs (a[r][col]) > fabs (a[piv][col]))
				piv = r;
		if (fabs (a[piv][col]) < 1e-9)
			return FALSE;
		if (piv != col)
			for (int k = 0; k < 5; k++) {
				double t = a[col][k];
				a[col][k] = a[piv][k];
				a[piv][k] = t;
			}
		for (int r = 0; r < 4; r++) {
			if (r == col)
				continue;
			double f = a[r][col] / a[col][col];
			for (int k = col; k < 5; k++)
				a[r][k] -= f * a[col][k];
		}
	}
	for (int r = 0; r < 4; r++)
		a[r][4] /= a[r][r];
	return TRUE;
}

/* Sphere fit over the filled bins: |m - c|^2 = r^2, linear in (c, r^2 - |c|^2).
 * Accepted only with samples on both sides of every axis. */
static void
try_fit (DrvData *d)
{
	double a[4][5] = { { 0 } };
	gboolean pos[3] = { FALSE }, neg[3] = { FALSE };
	double c[3], r, rms = 0.0;
	int n = 0;

	for (int b = 0; b < N_BINS; b++) {
		const double *m = d->bins[b].v;
		double row[4] = { 2 * m[0], 2 * m[1], 2 * m[2], 1.0 };
		double rhs = m[0] * m[0] + m[1] * m[1] + m[2] * m[2];

		if (!d->bins[b].used)
			continue;
		n++;
		for (int i = 0; i < 4; i++) {
			for (int j = 0; j < 4; j++)
				a[i][j] += row[i] * row[j];
			a[i][4] += row[i] * rhs;
		}
	}
	if (n < 10)
		return;

	if (!solve4 (a))
		return;
	for (int i = 0; i < 3; i++)
		c[i] = a[i][4];
	r = a[3][4] + c[0] * c[0] + c[1] * c[1] + c[2] * c[2];
	if (r <= 0)
		return;
	r = sqrt (r);

	for (int b = 0; b < N_BINS; b++) {
		double u[3], len = 0.0;
		if (!d->bins[b].used)
			continue;
		for (int i = 0; i < 3; i++) {
			u[i] = d->bins[b].v[i] - c[i];
			len += u[i] * u[i];
		}
		len = sqrt (len);
		rms += (len - r) * (len - r);
		for (int i = 0; i < 3; i++) {
			if (u[i] / len > 0.4)
				pos[i] = TRUE;
			if (u[i] / len < -0.4)
				neg[i] = TRUE;
		}
	}
	rms = sqrt (rms / n);

	for (int i = 0; i < 3; i++)
		if (!pos[i] || !neg[i])
			return;
	/* Earth field is 25-65 uT; the sensor scale on the 6T reads ~43 */
	if (r < 15 || r > 90 || rms > 0.1 * r)
		return;

	{
		double moved = sqrt ((c[0] - d->offset[0]) * (c[0] - d->offset[0]) +
				     (c[1] - d->offset[1]) * (c[1] - d->offset[1]) +
				     (c[2] - d->offset[2]) * (c[2] - d->offset[2]));
		memcpy (d->offset, c, sizeof c);
		d->radius = r;
		d->calibrated = TRUE;
		if (moved > 1.0) {
			g_debug ("SSC compass: new hard-iron offset %.1f %.1f %.1f, field %.1f uT, rms %.1f, %d bins",
				 c[0], c[1], c[2], r, rms, n);
			save_calibration (d);
		}
	}
}

static void
add_sample (DrvData *d, const double m[3])
{
	gint64 now = g_get_monotonic_time ();
	double u[3], len = 0.0;
	int b;

	for (int i = 0; i < 3; i++) {
		if (!d->have_box || m[i] < d->minv[i])
			d->minv[i] = m[i];
		if (!d->have_box || m[i] > d->maxv[i])
			d->maxv[i] = m[i];
	}
	d->have_box = TRUE;

	for (int i = 0; i < 3; i++) {
		double centre = d->calibrated ? d->offset[i] : (d->minv[i] + d->maxv[i]) / 2;
		u[i] = m[i] - centre;
		len += u[i] * u[i];
	}
	len = sqrt (len);
	if (len < 1e-3)
		return;
	for (int i = 0; i < 3; i++)
		u[i] /= len;

	for (b = 0; b < N_BINS; b++)
		if (d->bins[b].used && now - d->bins[b].time > BIN_MAX_AGE_US)
			d->bins[b].used = FALSE;

	b = bin_index (u);
	memcpy (d->bins[b].v, m, sizeof d->bins[b].v);
	d->bins[b].time = now;
	d->bins[b].used = TRUE;

	if (++d->new_samples >= FIT_EVERY) {
		d->new_samples = 0;
		try_fit (d);
	}
}

static void
cross (const double a[3], const double b[3], double out[3])
{
	out[0] = a[1] * b[2] - a[2] * b[1];
	out[1] = a[2] * b[0] - a[0] * b[2];
	out[2] = a[0] * b[1] - a[1] * b[0];
}

/* Azimuth of the device y axis (top edge) from magnetic north, as Android
 * SensorManager.getRotationMatrix() + getOrientation() compute it. */
static gboolean
compute_heading (DrvData *d, double *heading)
{
	double m[3], h[3], mv[3], hn = 0.0, an = 0.0;

	for (int i = 0; i < 3; i++)
		m[i] = d->mag_f[i] - d->offset[i];
	cross (m, d->accel_f, h);
	for (int i = 0; i < 3; i++) {
		hn += h[i] * h[i];
		an += d->accel_f[i] * d->accel_f[i];
	}
	hn = sqrt (hn);
	an = sqrt (an);
	/* Free fall or field parallel to gravity */
	if (an < 0.1 * 9.81 || hn < 0.1)
		return FALSE;
	{
		double a[3] = { d->accel_f[0] / an, d->accel_f[1] / an, d->accel_f[2] / an };
		for (int i = 0; i < 3; i++)
			h[i] /= hn;
		cross (a, h, mv);
	}
	*heading = atan2 (h[1], mv[1]) * 180.0 / G_PI;
	if (*heading < 0)
		*heading += 360.0;
	return TRUE;
}

static void
accel_cb (SSCSensorAccelerometer *sensor, gfloat x, gfloat y, gfloat z, gpointer user_data)
{
	SensorDevice *sensor_device = user_data;
	DrvData *d = (DrvData *) sensor_device->priv;
	double v[3] = { x, y, z };

	for (int i = 0; i < 3; i++)
		d->accel_f[i] = d->have_accel ? d->accel_f[i] + FILTER_ALPHA * (v[i] - d->accel_f[i]) : v[i];
	d->have_accel = TRUE;
}

static void
mag_cb (SSCSensorMagnetometer *sensor, gfloat x, gfloat y, gfloat z, gpointer user_data)
{
	SensorDevice *sensor_device = user_data;
	DrvData *d = (DrvData *) sensor_device->priv;
	double v[3] = { x, y, z };
	CompassReadings readings;
	double heading;

	add_sample (d, v);
	for (int i = 0; i < 3; i++)
		d->mag_f[i] = d->have_mag ? d->mag_f[i] + FILTER_ALPHA * (v[i] - d->mag_f[i]) : v[i];
	d->have_mag = TRUE;

	if (!d->have_accel || !d->calibrated)
		return;
	if (!compute_heading (d, &heading))
		return;

	readings.heading = heading;
	sensor_device->callback_func (sensor_device, (gpointer) &readings, sensor_device->user_data);
}

static void
apply_polling (SensorDevice *sensor_device)
{
	DrvData *d = (DrvData *) sensor_device->priv;

	if (!d->mag || !d->accel || d->want_polling == d->polling)
		return;

	if (d->want_polling) {
		d->mag_id = g_signal_connect (d->mag, "measurement", G_CALLBACK (mag_cb), sensor_device);
		d->accel_id = g_signal_connect (d->accel, "measurement", G_CALLBACK (accel_cb), sensor_device);
		d->have_accel = d->have_mag = FALSE;
		ssc_sensor_accelerometer_open (d->accel, d->cancellable, NULL, NULL);
		ssc_sensor_magnetometer_open (d->mag, d->cancellable, NULL, NULL);
	} else {
		g_clear_signal_handler (&d->mag_id, d->mag);
		g_clear_signal_handler (&d->accel_id, d->accel);
		ssc_sensor_magnetometer_close (d->mag, d->cancellable, NULL, NULL);
		ssc_sensor_accelerometer_close (d->accel, d->cancellable, NULL, NULL);
	}
	d->polling = d->want_polling;
}

static void
mag_ready (GObject *source, GAsyncResult *res, gpointer user_data)
{
	SensorDevice *sensor_device = user_data;
	g_autoptr(GError) error = NULL;
	SSCSensorMagnetometer *mag = ssc_sensor_magnetometer_new_finish (res, &error);

	if (!mag) {
		if (!g_error_matches (error, G_IO_ERROR, G_IO_ERROR_CANCELLED))
			g_warning ("Creating SSC magnetometer failed: %s", error->message);
		return;
	}
	((DrvData *) sensor_device->priv)->mag = mag;
	apply_polling (sensor_device);
}

static void
accel_ready (GObject *source, GAsyncResult *res, gpointer user_data)
{
	SensorDevice *sensor_device = user_data;
	g_autoptr(GError) error = NULL;
	SSCSensorAccelerometer *accel = ssc_sensor_accelerometer_new_finish (res, &error);

	if (!accel) {
		if (!g_error_matches (error, G_IO_ERROR, G_IO_ERROR_CANCELLED))
			g_warning ("Creating SSC accelerometer for compass failed: %s", error->message);
		return;
	}
	((DrvData *) sensor_device->priv)->accel = accel;
	apply_polling (sensor_device);
}

static SensorDevice *
ssc_compass_open (GUdevDevice *device)
{
	SensorDevice *sensor_device;
	DrvData *d;

	sensor_device = g_new0 (SensorDevice, 1);
	sensor_device->name = g_strdup ("SSC magnetometer compass");
	sensor_device->priv = g_new0 (DrvData, 1);
	d = (DrvData *) sensor_device->priv;
	d->cancellable = g_cancellable_new ();
	load_calibration (d);

	ssc_sensor_magnetometer_new (d->cancellable, mag_ready, sensor_device);
	ssc_sensor_accelerometer_new (d->cancellable, accel_ready, sensor_device);

	return sensor_device;
}

static void
ssc_compass_set_polling (SensorDevice *sensor_device, gboolean state)
{
	DrvData *d = (DrvData *) sensor_device->priv;

	d->want_polling = state;
	apply_polling (sensor_device);
}

static void
ssc_compass_close (SensorDevice *sensor_device)
{
	DrvData *d = (DrvData *) sensor_device->priv;

	g_cancellable_cancel (d->cancellable);
	g_clear_object (&d->cancellable);
	if (d->mag)
		g_clear_signal_handler (&d->mag_id, d->mag);
	if (d->accel)
		g_clear_signal_handler (&d->accel_id, d->accel);
	g_clear_object (&d->mag);
	g_clear_object (&d->accel);
	g_clear_pointer (&sensor_device->name, g_free);
	g_clear_pointer (&sensor_device->priv, g_free);
	g_free (sensor_device);
}

SensorDriver ssc_compass = {
	.driver_name = "SSC compass sensor",
	.type = DRIVER_TYPE_COMPASS,

	.discover = ssc_compass_discover,
	.open = ssc_compass_open,
	.set_polling = ssc_compass_set_polling,
	.close = ssc_compass_close,
};
