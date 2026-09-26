#!/bin/sh
# Вернуть Phosh вместо Plasma Mobile.
set -e
systemctl disable plasma-mobile.service
systemctl enable phosh.service
readlink -f /etc/systemd/system/display-manager.service
