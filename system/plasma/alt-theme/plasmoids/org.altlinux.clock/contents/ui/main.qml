/*
 * SPDX-FileCopyrightText: 2026 morgonf <morgonf@altlinux.org>
 * SPDX-License-Identifier: MIT
 *
 * Часы главного экрана для темы ALT Mobile. Стандартные «Цифровые часы»
 * на рабочем столе вписывают время в высоту области и не дают задать
 * размер: в одной клетке мелко, в двух огромно. Здесь размеры заданы,
 * начертание общее для темы (обычное), день недели на своей строке.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.clock
import org.kde.plasma.private.mobileshell as MobileShell

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    Clock {
        id: clock
    }

    component ClockLabel: PC3.Label {
        color: "white"
        Layout.alignment: Qt.AlignHCenter
        layer.enabled: true
        layer.effect: MobileShell.TextDropShadow {
            blurMax: 16
        }
    }

    fullRepresentation: Item {
        Layout.minimumHeight: column.implicitHeight

        ColumnLayout {
            id: column
            anchors.centerIn: parent
            spacing: 0

            ClockLabel {
                text: clock.dateTime.toLocaleTimeString(Qt.locale(), "hh:mm")
                font.pixelSize: 77
            }
            ClockLabel {
                text: clock.dateTime.toLocaleDateString(Qt.locale(), "dddd")
                font.pixelSize: 20
            }
            ClockLabel {
                text: clock.dateTime.toLocaleDateString(Qt.locale(), "d MMMM")
                font.pixelSize: 20
            }
        }
    }
}
