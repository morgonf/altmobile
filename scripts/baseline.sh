#!/bin/sh
# Исходные замеры системы (часть 0 docs/phosh-exit-and-tuning.md).
# Запуск от altlinux, вывод в каталог $1 (по умолчанию /tmp/.private/altlinux/baseline).
# Сон на время замера запрещён, экран не трогается.
D=${1:-/tmp/.private/altlinux/baseline}
mkdir -p "$D"
export PATH=/sbin:/usr/sbin:$PATH

{
	echo "== uptime"; uptime
	echo "== kernel"; uname -r
	echo "== rpm"; rpm -qa | wc -l
} > "$D/summary.txt"

rpm -qa --qf "%{NAME}\t%{VERSION}-%{RELEASE}\t%{SIZE}\n" | sort > "$D/rpm.txt"
grep -i -E "^(phosh|phoc|squeekboard|gnome-calls|chatty|feedbackd|gmobile|gnome-settings-daemon|alt-tweaks|tuner|foldy|gnome-contacts|phosh-antispam|gnome-|libadwaita)" "$D/rpm.txt" > "$D/rpm-gnome.txt"

df -h / /boot 2>/dev/null > "$D/df.txt"
btrfs filesystem df / 2>/dev/null >> "$D/df.txt"

systemctl list-unit-files --state=enabled --no-legend > "$D/units-system.txt"
systemctl --user list-unit-files --state=enabled --no-legend > "$D/units-user.txt"
systemctl list-units --type=service --state=running --no-legend > "$D/running-system.txt"
systemctl --user list-units --type=service --state=running --no-legend > "$D/running-user.txt"
ls /etc/xdg/autostart ~/.config/autostart 2>/dev/null > "$D/autostart.txt"

systemd-analyze > "$D/boot.txt" 2>&1
systemd-analyze blame > "$D/blame.txt" 2>&1
systemd-analyze critical-chain > "$D/critical-chain.txt" 2>&1
systemd-analyze --user blame > "$D/blame-user.txt" 2>&1

free -m > "$D/free.txt"
# Память по процессам: PSS из smaps_rollup (smem на телефоне нет)
for p in /proc/[0-9]*; do
	pss=$(awk '/^Pss:/{print $2}' "$p/smaps_rollup" 2>/dev/null)
	[ -n "$pss" ] && [ "$pss" -gt 0 ] && printf "%s\t%s\t%s\n" "$pss" "${p#/proc/}" "$(tr '\0' ' ' < "$p/cmdline" | cut -c1-100)"
done | sort -rn > "$D/pss.txt"
awk -F'\t' '{s+=$1} END{print "PSS сумма МБ:", int(s/1024)}' "$D/pss.txt" >> "$D/free.txt"

# Пробуждения: прерывания и переключения контекста за 60 с при выключенном экране
cat /proc/interrupts > "$D/irq-0.txt"; s0=$(awk '/^ctxt/{print $2}' /proc/stat)
sleep 60
cat /proc/interrupts > "$D/irq-60.txt"; s1=$(awk '/^ctxt/{print $2}' /proc/stat)
echo "переключений контекста за 60 с: $((s1 - s0))" >> "$D/summary.txt"

# Батарея: счётчик заряда bq27411 и ток
for f in /sys/class/power_supply/*/; do
	echo "== $f"; grep -H . "$f"uevent 2>/dev/null
done > "$D/battery.txt"
