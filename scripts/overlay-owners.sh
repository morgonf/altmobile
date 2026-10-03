#!/bin/sh
# Файлы пакетов, подменённые нашими сборками, и пакеты-владельцы.
# Ищет копии оригиналов (*.orig рядом с файлом и каталог копий libcamera)
# и файлы, которые не проходят проверку rpm -V по содержимому.
# Вывод: «пакет<TAB>файл», в конце список пакетов.
export PATH=/sbin:/usr/sbin:$PATH
T=$(mktemp)
find /usr /etc -xdev -name '*.orig' 2>/dev/null | while read -r o; do
	f=${o%.orig}
	p=$(rpm -qf --qf '%{NAME}\n' "$f" 2>/dev/null | head -1)
	case "$p" in ""|*"не принадлежит"*|*"not owned"*) p="(ничей)";; esac
	printf '%s\t%s\n' "$p" "$f"
done >> "$T"
for f in /usr/lib64/libcamera.so.0.7.2 /usr/lib64/libcamera-base.so.0.7.2 \
	/usr/lib64/libcamera/ipa/ipa_soft_simple.so /usr/bin/plasma-camera; do
	[ -e "$f" ] && printf '%s\t%s\n' "$(rpm -qf --qf '%{NAME}\n' "$f" | head -1)" "$f"
done >> "$T"
sort -u "$T"
echo "== пакеты"
cut -f1 "$T" | sort -u
rm -f "$T"
# Изменённое содержимое (rpm -V, признак 5) у пакетов, которые мы трогали
echo "== rpm -V"
rpm -qa --qf '%{NAME}\n' | grep -E '^(kwin|plasma|kf6-kirigami|kscreen|bluedevil|kaccounts|libcamera|iio-sensor|neard|gnome-compass|polkit-kde|powerdevil|plasma-keyboard|libxslt)' |
	sort -u | while read -r p; do
	rpm -V "$p" 2>/dev/null | awk -v p="$p" '$1 ~ /^..5/ && $2 != "c" {print p "\t" $NF}'
done
