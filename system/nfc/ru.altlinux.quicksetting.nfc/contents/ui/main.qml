// Быстрая настройка «NFC» для Plasma Mobile (ALT Mobile, OnePlus 6T).
// Состояние и переключение через службу пользователя alt-nfc
// (ru.altlinux.Nfc на шине сеанса, system/nfc/alt-nfc.py): она хранит выбор,
// включает и выключает адаптер neard и держит опрос меток.
import QtQuick
import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS
import org.kde.plasma.workspace.dbus as DBus

QS.QuickSetting {
    id: root

    readonly property bool adapterPresent: nfc.properties.Available ?? false
    readonly property bool locked: nfc.properties.Locked ?? false

    text: "NFC"
    icon: "nfc"
    enabled: nfc.properties.Enabled ?? false
    available: true
    settingsCommand: "plasma-settings -m kcm_altnfc"
    status: !root.adapterPresent ? "Нет адаптера"
          : !enabled ? "Выключено"
          : locked ? "Ждёт разблокировки"
          : "Поднесите метку"

    DBus.Properties {
        id: nfc
        busType: DBus.BusType.Session
        service: "ru.altlinux.Nfc"
        path: "/ru/altlinux/Nfc"
        iface: "ru.altlinux.Nfc"
    }

    function toggle() {
        DBus.SessionBus.asyncCall({
            "service": "ru.altlinux.Nfc",
            "path": "/ru/altlinux/Nfc",
            "iface": "ru.altlinux.Nfc",
            "member": "SetEnabled",
            "signature": "(b)",
            "arguments": [new DBus.bool(!enabled)],
        });
    }
}
