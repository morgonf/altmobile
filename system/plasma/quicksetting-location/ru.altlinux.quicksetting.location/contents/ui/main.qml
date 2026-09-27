// Быстрая настройка «Местоположение» для Plasma Mobile (ALT Mobile, OnePlus 6T).
// Выключено: служба geoclue запрещена (systemctl mask), программы не
// получают координаты, GPS модема выключен. Состояние читается из systemd
// (UnitFileState у geoclue.service), переключают его системные службы
// alt-location-off и alt-location-on; запуск только их разрешает
// 51-alt-mobile-location.rules (polkit).
import QtQuick
import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS
import org.kde.plasma.workspace.dbus as DBus

QS.QuickSetting {
    id: root

    readonly property string state: unit.properties.UnitFileState ?? ""

    text: "Местоположение"
    icon: "gps"
    enabled: state !== "masked" && state !== "masked-runtime"
    status: enabled ? "Программы могут узнавать, где вы" : "Выключено"

    DBus.Properties {
        id: unit
        busType: DBus.BusType.System
        service: "org.freedesktop.systemd1"
        path: "/org/freedesktop/systemd1/unit/geoclue_2eservice"
        iface: "org.freedesktop.systemd1.Unit"
    }

    // UnitFileState приходит без сигнала об изменении после mask/unmask
    Timer {
        id: refresh
        interval: 700
        repeat: true
        property int left: 0
        onTriggered: { unit.updateAll(); if (--left <= 0) stop(); }
    }

    function toggle() {
        DBus.SystemBus.asyncCall({
            "service": "org.freedesktop.systemd1",
            "path": "/org/freedesktop/systemd1",
            "iface": "org.freedesktop.systemd1.Manager",
            "member": "StartUnit",
            "signature": "(ss)",
            "arguments": [new DBus.string(enabled ? "alt-location-off.service" : "alt-location-on.service"),
                          new DBus.string("replace")],
        });
        refresh.left = 6;
        refresh.start();
    }
}
