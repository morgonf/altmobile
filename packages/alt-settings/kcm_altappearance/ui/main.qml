/*
SPDX-FileCopyrightText: 2026 morgonf

SPDX-License-Identifier: MIT
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard 1 as FormCard

// ALT Mobile: «Тема и обои». Вид (тёмный или светлый) меняется сразу
// касанием карточки. Обои выбираются на отдельной странице с крупным
// предпросмотром и ставятся кнопкой «Установить».
KCM.SimpleKCM {
    id: root

    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    component ThemeCard: QQC2.AbstractButton {
        id: card
        required property bool darkVariant
        required property string label
        required property string preview
        readonly property bool current: kcm.dark === darkVariant

        Layout.fillWidth: true
        implicitHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 2
        onClicked: if (!current) kcm.setDark(darkVariant)

        contentItem: ColumnLayout {
            id: column
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                Layout.preferredHeight: Layout.preferredWidth * 2.17
                radius: Kirigami.Units.cornerRadius
                color: "transparent"
                border.width: card.current ? 3 : 1
                border.color: card.current ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor

                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    source: card.preview
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            QQC2.RadioButton {
                Layout.alignment: Qt.AlignHCenter
                text: card.label
                checked: card.current
                onClicked: card.clicked()
            }
        }
    }

    component WallpaperRow: FormCard.AbstractFormDelegate {
        id: row
        required property string label
        required property string preview
        required property string target

        onClicked: kcm.push("WallpaperPicker.qml", { "target": target })

        contentItem: RowLayout {
            spacing: Kirigami.Units.largeSpacing

            Image {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                Layout.preferredHeight: Kirigami.Units.gridUnit * 6.5
                source: row.preview ? "file://" + row.preview : ""
                sourceSize.width: Kirigami.Units.gridUnit * 6
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: row.label
                wrapMode: Text.WordWrap
            }

            FormCard.FormArrow {
                direction: Qt.RightArrow
            }
        }
    }

    ColumnLayout {
        spacing: 0

        FormCard.FormHeader {
            title: "Тема"
        }

        FormCard.FormCard {
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing

                ThemeCard {
                    darkVariant: true
                    label: "Тёмная"
                    preview: "file:///usr/share/plasma/look-and-feel/org.altlinux.mobile/contents/previews/fullscreenpreview.jpg"
                }
                ThemeCard {
                    darkVariant: false
                    label: "Светлая"
                    preview: "file:///usr/share/plasma/look-and-feel/org.altlinux.mobile.light/contents/previews/fullscreenpreview.jpg"
                }
            }
        }

        FormCard.FormSectionText {
            text: "Тёмная тема бережёт заряд, потому что на экране AMOLED чёрные точки не светятся."
        }

        FormCard.FormHeader {
            title: "Обои"
        }

        FormCard.FormCard {
            WallpaperRow {
                label: "Рабочий стол"
                preview: kcm.homeWallpaper
                target: "home"
            }

            FormCard.FormDelegateSeparator {}

            WallpaperRow {
                label: "Экран блокировки"
                preview: kcm.lockWallpaper
                target: "lock"
            }
        }
    }
}
