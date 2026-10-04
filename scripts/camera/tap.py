#!/usr/bin/python3
# Виртуальный сенсорный экран для проверок: tap.py X Y [удержание_с [X2 Y2]]
# С X2 Y2 это свайп: палец идёт от X Y до X2 Y2 за время удержания.
# Координаты в точках экрана 1080x2340. Нужен доступ к /dev/uinput.
import fcntl, os, struct, sys, time
X, Y = int(sys.argv[1]), int(sys.argv[2])
HOLD = float(sys.argv[3]) if len(sys.argv) > 3 else 0.08
X2, Y2 = (int(sys.argv[4]), int(sys.argv[5])) if len(sys.argv) > 5 else (X, Y)
W, H = 1080, 2340
EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
BTN_TOUCH = 0x14a
ABS_X, ABS_Y, ABS_MT_SLOT, ABS_MT_POSITION_X, ABS_MT_POSITION_Y, ABS_MT_TRACKING_ID = 0, 1, 0x2f, 0x35, 0x36, 0x39
UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_ABSBIT, UI_SET_PROPBIT = 0x40045564, 0x40045565, 0x40045567, 0x4004556e
UI_DEV_CREATE, UI_DEV_DESTROY = 0x5501, 0x5502
INPUT_PROP_DIRECT = 1
fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
for ev in (EV_SYN, EV_KEY, EV_ABS):
    fcntl.ioctl(fd, UI_SET_EVBIT, ev)
fcntl.ioctl(fd, UI_SET_KEYBIT, BTN_TOUCH)
for a in (ABS_X, ABS_Y, ABS_MT_SLOT, ABS_MT_POSITION_X, ABS_MT_POSITION_Y, ABS_MT_TRACKING_ID):
    fcntl.ioctl(fd, UI_SET_ABSBIT, a)
fcntl.ioctl(fd, UI_SET_PROPBIT, INPUT_PROP_DIRECT)
absmax = [0] * 64; absmin = [0] * 64
absmax[ABS_X] = absmax[ABS_MT_POSITION_X] = W - 1
absmax[ABS_Y] = absmax[ABS_MT_POSITION_Y] = H - 1
absmax[ABS_MT_SLOT] = 4; absmax[ABS_MT_TRACKING_ID] = 65535
name = b"alt-test-touch"
dev = struct.pack("80sHHHHi", name, 3, 1, 1, 1, 0) + struct.pack("64i", *absmax) + struct.pack("64i", *absmin) + struct.pack("64i", *([0]*64)) + struct.pack("64i", *([0]*64))
os.write(fd, dev)
fcntl.ioctl(fd, UI_DEV_CREATE)
time.sleep(1.0)  # KWin must pick the device up
def ev(t, c, v):
    s, us = divmod(time.time(), 1)
    os.write(fd, struct.pack("llHHi", int(s), int(us * 1e6), t, c, v))
ev(EV_ABS, ABS_MT_SLOT, 0); ev(EV_ABS, ABS_MT_TRACKING_ID, 1)
ev(EV_ABS, ABS_MT_POSITION_X, X); ev(EV_ABS, ABS_MT_POSITION_Y, Y)
ev(EV_ABS, ABS_X, X); ev(EV_ABS, ABS_Y, Y)
ev(EV_KEY, BTN_TOUCH, 1); ev(EV_SYN, 0, 0)
STEPS = 20 if (X2, Y2) != (X, Y) else 1
for i in range(1, STEPS + 1):
    time.sleep(HOLD / STEPS)
    if STEPS > 1:
        x = X + (X2 - X) * i // STEPS; y = Y + (Y2 - Y) * i // STEPS
        ev(EV_ABS, ABS_MT_POSITION_X, x); ev(EV_ABS, ABS_MT_POSITION_Y, y)
        ev(EV_ABS, ABS_X, x); ev(EV_ABS, ABS_Y, y); ev(EV_SYN, 0, 0)
ev(EV_ABS, ABS_MT_TRACKING_ID, -1); ev(EV_KEY, BTN_TOUCH, 0); ev(EV_SYN, 0, 0)
time.sleep(0.3)
fcntl.ioctl(fd, UI_DEV_DESTROY)
os.close(fd)
