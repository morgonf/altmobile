/*
SPDX-FileCopyrightText: 2026 morgonf

SPDX-License-Identifier: MIT
*/

import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.newstuff as NewStuff

// ALT Mobile: выбор обоев. Касание миниатюры только показывает её крупно
// сверху, записывает обои кнопка «Установить». Переключатель «Также на
// экран блокировки» (или на рабочий стол) ставит те же обои в оба места.
Kirigami.ScrollablePage {
    id: page

    // home или lock: откуда открыта страница
    property string target: "home"
    property string selected: ""
    property string selectedPreview: ""

    title: target === "home" ? "Обои рабочего стола" : "Обои экрана блокировки"

    Component.onCompleted: {
        const current = target === "home" ? kcm.homeWallpaper : kcm.lockWallpaper;
        selectedPreview = current;
    }

    NewStuff.Dialog {
        id: wallpaperStore
        configFile: "wallpaper-mobile.knsrc"
        onEntryEvent: (entry, event) => kcm.rescan()
        onVisibleChanged: if (!visible) kcm.rescan()
    }

    FileDialog {
        id: fileDialog
        title: "Картинка для обоев"
        nameFilters: ["Изображения (*.jpg *.jpeg *.png *.webp *.avif *.jxl)"]
        currentFolder: "file://" + StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        onAccepted: {
            const path = kcm.addWallpaper(selectedFile);
            if (path) {
                page.selected = path;
                page.selectedPreview = path;
            }
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // Крупный предпросмотр в пропорциях экрана
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(page.width * 0.55, Kirigami.Units.gridUnit * 12)
            Layout.preferredHeight: Layout.preferredWidth * 2.17
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.alternateBackgroundColor

            Image {
                anchors.fill: parent
                source: page.selectedPreview ? "file://" + page.selectedPreview : ""
                sourceSize.height: 1200
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        QQC2.Switch {
            id: bothSwitch
            Layout.alignment: Qt.AlignHCenter
            text: page.target === "home" ? "Также на экран блокировки" : "Также на рабочий стол"
        }

        QQC2.Button {
            Layout.alignment: Qt.AlignHCenter
            icon.name: "dialog-ok-apply"
            text: "Установить"
            highlighted: true
            enabled: page.selected !== ""
            onClicked: {
                const home = page.target === "home" || bothSwitch.checked;
                const lock = page.target === "lock" || bothSwitch.checked;
                kcm.setWallpaper(page.selected, home, lock);
                kcm.pop();
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.largeSpacing

            QQC2.Button {
                icon.name: "document-open"
                text: "Из файлов"
                onClicked: fileDialog.open()
            }
            QQC2.Button {
                icon.name: "get-hot-new-stuff"
                text: "Загрузить"
                onClicked: wallpaperStore.open()
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            Repeater {
                model: kcm.wallpapers
                delegate: QQC2.AbstractButton {
                    id: thumb
                    required property var modelData
                    readonly property bool isSelected: page.selected === modelData.source

                    Layout.fillWidth: true
                    Layout.preferredHeight: width * 2.17
                    onClicked: {
                        page.selected = modelData.source;
                        page.selectedPreview = modelData.preview;
                    }

                    contentItem: Item {
                        Image {
                            anchors.fill: parent
                            source: thumb.modelData.preview ? "file://" + thumb.modelData.preview : ""
                            sourceSize.width: 300
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: thumb.isSelected ? 4 : 0
                            border.color: Kirigami.Theme.highlightColor
                        }
                        QQC2.Label {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            padding: Kirigami.Units.smallSpacing
                            text: thumb.modelData.name
                            elide: Text.ElideRight
                            color: "white"
                            background: Rectangle { color: "#80000000" }
                        }
                    }
                }
            }
        }
    }
}
