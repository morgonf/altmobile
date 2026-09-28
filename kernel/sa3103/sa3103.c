// SPDX-License-Identifier: GPL-2.0
/*
 * SA3103 voice coil motor (lens focus actuator).
 *
 * Found on the rear cameras of some OnePlus 6T (fajita) units instead of the
 * LC898217XC described in the mainline device tree: I2C addresses 0x0c
 * (IMX519) and 0x0d (IMX376K). The register interface was taken from the
 * Android camera module data (com.qti.sensormodule.liteon_*_sa3103_actuator)
 * and checked on the device:
 *   0x81  control, write 0x01 after power-up to enable the driver stage
 *   0x82  position bits 11..8
 *   0x83  position bits 7..0
 * Position is a 12-bit DAC code, 0..4095.
 *
 * Copyright (c) 2026 morgonf
 */

#include <linux/delay.h>
#include <linux/i2c.h>
#include <linux/module.h>
#include <linux/pm_runtime.h>
#include <linux/regulator/consumer.h>
#include <media/v4l2-ctrls.h>
#include <media/v4l2-device.h>
#include <media/v4l2-subdev.h>

#define SA3103_REG_CONTROL	0x81
#define SA3103_REG_POS_H	0x82
#define SA3103_REG_POS_L	0x83
#define SA3103_CONTROL_ENABLE	0x01

#define SA3103_MAX_POS		4095
/*
 * The focus control exposes only the useful travel of the IMX519 module:
 * below ~1100 the lens rests on its end stop, above ~2200 nothing is in
 * focus. A narrower range makes libcamera's percent-based autofocus sweep
 * spend its steps where the focus actually changes.
 */
#define SA3103_FOCUS_MIN	1000
#define SA3103_FOCUS_MAX	2400
/*
 * IMX519 module, measured 28.09.2026: lens at rest below ~1100, infinity
 * about 1300-1400, 0.5 m about 1700, 10-15 cm about 2000, blurred above
 * ~2200. 1450 keeps roughly 1 m to infinity sharp as a fixed focus.
 */
#define SA3103_DEFAULT_POS	1450

static const char * const sa3103_supply_names[] = {
	"vdd",
	"vana",
};

struct sa3103 {
	struct v4l2_subdev sd;
	struct v4l2_ctrl_handler ctrls;
	struct v4l2_ctrl *focus;
	struct regulator_bulk_data supplies[ARRAY_SIZE(sa3103_supply_names)];
};

static inline struct sa3103 *to_sa3103(struct v4l2_subdev *sd)
{
	return container_of(sd, struct sa3103, sd);
}

static int sa3103_write(struct sa3103 *sa, u8 reg, u8 val)
{
	struct i2c_client *client = v4l2_get_subdevdata(&sa->sd);
	int ret = i2c_smbus_write_byte_data(client, reg, val);

	if (ret)
		dev_err(&client->dev, "write 0x%02x to reg 0x%02x failed: %d\n", val, reg, ret);
	return ret;
}

static int sa3103_set_position(struct sa3103 *sa, u16 pos)
{
	int ret;

	ret = sa3103_write(sa, SA3103_REG_POS_H, (pos >> 8) & 0x0f);
	if (ret)
		return ret;
	return sa3103_write(sa, SA3103_REG_POS_L, pos & 0xff);
}

static int sa3103_power_on(struct device *dev)
{
	struct sa3103 *sa = to_sa3103(dev_get_drvdata(dev));
	int ret;

	ret = regulator_bulk_enable(ARRAY_SIZE(sa->supplies), sa->supplies);
	if (ret)
		return ret;

	/* Let the supplies settle before the first I2C access */
	usleep_range(2000, 3000);

	ret = sa3103_write(sa, SA3103_REG_CONTROL, SA3103_CONTROL_ENABLE);
	if (ret)
		goto err;
	usleep_range(1000, 1500);

	ret = sa3103_set_position(sa, sa->focus->val);
	if (ret)
		goto err;
	return 0;

err:
	regulator_bulk_disable(ARRAY_SIZE(sa->supplies), sa->supplies);
	return ret;
}

static int sa3103_power_off(struct device *dev)
{
	struct sa3103 *sa = to_sa3103(dev_get_drvdata(dev));

	return regulator_bulk_disable(ARRAY_SIZE(sa->supplies), sa->supplies);
}

static int sa3103_set_ctrl(struct v4l2_ctrl *ctrl)
{
	struct sa3103 *sa = container_of(ctrl->handler, struct sa3103, ctrls);
	struct device *dev = sa->sd.dev;
	int ret = 0;

	if (ctrl->id != V4L2_CID_FOCUS_ABSOLUTE)
		return -EINVAL;

	/* Powered off: the value is applied at the next power-up */
	if (!pm_runtime_get_if_in_use(dev))
		return 0;

	ret = sa3103_set_position(sa, ctrl->val);
	pm_runtime_put_autosuspend(dev);
	return ret;
}

static const struct v4l2_ctrl_ops sa3103_ctrl_ops = {
	.s_ctrl = sa3103_set_ctrl,
};

static int sa3103_open(struct v4l2_subdev *sd, struct v4l2_subdev_fh *fh)
{
	return pm_runtime_resume_and_get(sd->dev);
}

static int sa3103_close(struct v4l2_subdev *sd, struct v4l2_subdev_fh *fh)
{
	pm_runtime_put_autosuspend(sd->dev);
	return 0;
}

static const struct v4l2_subdev_internal_ops sa3103_internal_ops = {
	.open = sa3103_open,
	.close = sa3103_close,
};

static const struct v4l2_subdev_ops sa3103_ops = { };

static int sa3103_probe(struct i2c_client *client)
{
	struct device *dev = &client->dev;
	struct sa3103 *sa;
	unsigned int i;
	int ret;

	sa = devm_kzalloc(dev, sizeof(*sa), GFP_KERNEL);
	if (!sa)
		return -ENOMEM;

	for (i = 0; i < ARRAY_SIZE(sa3103_supply_names); i++)
		sa->supplies[i].supply = sa3103_supply_names[i];
	ret = devm_regulator_bulk_get(dev, ARRAY_SIZE(sa->supplies), sa->supplies);
	if (ret)
		return dev_err_probe(dev, ret, "failed to get supplies\n");

	v4l2_i2c_subdev_init(&sa->sd, client, &sa3103_ops);
	sa->sd.flags |= V4L2_SUBDEV_FL_HAS_DEVNODE;
	sa->sd.internal_ops = &sa3103_internal_ops;
	sa->sd.entity.function = MEDIA_ENT_F_LENS;

	v4l2_ctrl_handler_init(&sa->ctrls, 1);
	sa->focus = v4l2_ctrl_new_std(&sa->ctrls, &sa3103_ctrl_ops, V4L2_CID_FOCUS_ABSOLUTE,
				      SA3103_FOCUS_MIN, SA3103_FOCUS_MAX, 1,
				      SA3103_DEFAULT_POS);
	if (sa->ctrls.error) {
		ret = sa->ctrls.error;
		goto err_ctrls;
	}
	sa->sd.ctrl_handler = &sa->ctrls;

	ret = media_entity_pads_init(&sa->sd.entity, 0, NULL);
	if (ret)
		goto err_ctrls;

	pm_runtime_set_autosuspend_delay(dev, 1000);
	pm_runtime_use_autosuspend(dev);
	pm_runtime_enable(dev);

	ret = v4l2_async_register_subdev(&sa->sd);
	if (ret)
		goto err_pm;

	dev_info(dev, "SA3103 lens actuator\n");
	return 0;

err_pm:
	pm_runtime_disable(dev);
	pm_runtime_dont_use_autosuspend(dev);
	media_entity_cleanup(&sa->sd.entity);
err_ctrls:
	v4l2_ctrl_handler_free(&sa->ctrls);
	return ret;
}

static void sa3103_remove(struct i2c_client *client)
{
	struct v4l2_subdev *sd = i2c_get_clientdata(client);
	struct sa3103 *sa = to_sa3103(sd);

	v4l2_async_unregister_subdev(sd);
	pm_runtime_disable(&client->dev);
	if (!pm_runtime_status_suspended(&client->dev))
		sa3103_power_off(&client->dev);
	pm_runtime_set_suspended(&client->dev);
	pm_runtime_dont_use_autosuspend(&client->dev);
	media_entity_cleanup(&sd->entity);
	v4l2_ctrl_handler_free(&sa->ctrls);
}

static const struct of_device_id sa3103_of_match[] = {
	{ .compatible = "altmobile,sa3103" },
	{ }
};
MODULE_DEVICE_TABLE(of, sa3103_of_match);

/* For testing without device tree: echo sa3103 0x0c > .../i2c-16/new_device */
static const struct i2c_device_id sa3103_id[] = {
	{ "sa3103" },
	{ }
};
MODULE_DEVICE_TABLE(i2c, sa3103_id);

static DEFINE_RUNTIME_DEV_PM_OPS(sa3103_pm_ops, sa3103_power_off, sa3103_power_on, NULL);

static struct i2c_driver sa3103_driver = {
	.driver = {
		.name = "sa3103",
		.of_match_table = sa3103_of_match,
		.pm = pm_ptr(&sa3103_pm_ops),
	},
	.probe = sa3103_probe,
	.id_table = sa3103_id,
	.remove = sa3103_remove,
};
module_i2c_driver(sa3103_driver);

MODULE_DESCRIPTION("SA3103 lens voice coil motor driver");
MODULE_AUTHOR("morgonf");
MODULE_LICENSE("GPL");
