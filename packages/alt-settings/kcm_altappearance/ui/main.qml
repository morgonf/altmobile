/*
SPDX-FileCopyrightText: 2026 morgonf

SPDX-License-Identifier: MIT
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard 1 as FormCard
import org.kde.newstuff as NewStuff

// ALT Mobile: «Тема и обои». Глобальная тема (ALT Mobile тёмная и
// светлая первыми, затем остальные установленные) выбирается касанием
// карточки и применяется кнопкой «Применить тему», обои при этом сохраняются. Темы можно загрузить из KDE Store
// или поставить из архива. Обои выбираются на отдельной странице с крупным
// предпросмотром и ставятся кнопкой «Установить».
KCM.SimpleKCM {
    id: root

    // Тема, выбранная касанием. Применяет её кнопка, а не касание: при
    // прокрутке сетки касание легко попадает в чужую карточку
    property string selectedTheme: ""
    readonly property bool themePending: {
        for (const t of kcm.themes) {
            if (t.id === selectedTheme) {
                return !t.current;
            }
        }
        return false;
    }

    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    component ThemeCard: QQC2.AbstractButton {
        id: card
        required property var modelData
        // Выбрана касанием (ещё не применена) или текущая, если ничего не выбрано
        readonly property bool current: root.selectedTheme ? root.selectedTheme === modelData.id : modelData.current

        Layout.fillWidth: true
        implicitHeight: column.implicitHeight + Kirigami.Units.largeSpacing
        onClicked: root.selectedTheme = modelData.id

        contentItem: ColumnLayout {
            id: column
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                Layout.preferredHeight: Layout.preferredWidth * 2.17
                radius: Kirigami.Units.cornerRadius
                color: Kirigami.Theme.alternateBackgroundColor
                border.width: card.current ? 3 : 1
                border.color: card.current ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor

                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    source: card.modelData.preview ? "file://" + card.modelData.preview : ""
                    sourceSize.width: 400
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    visible: !card.modelData.preview
                    source: "preferences-desktop-theme-global"
                    implicitWidth: Kirigami.Units.iconSizes.huge
                    implicitHeight: implicitWidth
                }
            }

            QQC2.RadioButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: Kirigami.Units.gridUnit * 7
                text: card.modelData.name
                checked: card.current
                onClicked: card.clicked()
                contentItem: QQC2.Label {
                    leftPadding: parent.indicator.width + parent.spacing
                    text: parent.text
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    FileDialog {
        id: themeFileDialog
        title: "Архив глобальной темы"
        nameFilters: ["Темы Plasma (*.tar.gz *.tar.xz *.tgz *.zip)"]
        onAccepted: kcm.installTheme(selectedFile)
    }

    NewStuff.Dialog {
        id: themeStore
        configFile: "lookandfeel.knsrc"
        onEntryEvent: (entry, event) => kcm.rescan()
        onVisibleChanged: if (!visible) kcm.rescan()
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
            GridLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                columns: 2
                rowSpacing: Kirigami.Units.largeSpacing

                Repeater {
                    model: kcm.themes
                    delegate: ThemeCard {}
                }
            }

            FormCard.FormDelegateSeparator { visible: root.themePending }

            FormCard.FormButtonDelegate {
                visible: root.themePending
                icon.name: "dialog-ok-apply"
                text: "Применить тему"
                onClicked: {
                    kcm.applyTheme(root.selectedTheme);
                    root.selectedTheme = "";
                }
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormButtonDelegate {
                icon.name: "get-hot-new-stuff"
                text: "Загрузить темы"
                description: "Из каталога KDE Store, нужен интернет"
                onClicked: themeStore.open()
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormButtonDelegate {
                icon.name: "document-open"
                text: "Установить тему из файла"
                onClicked: themeFileDialog.open()
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
