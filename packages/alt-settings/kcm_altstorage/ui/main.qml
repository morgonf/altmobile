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

// ALT Mobile: «Хранилище». Занятое и свободное место, из чего оно
// складывается, очистка кэша приложений и скачанных пакетов.
KCM.SimpleKCM {
    id: root

    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    readonly property real used: kcm.total - kcm.free

    ColumnLayout {
        spacing: 0

        FormCard.FormCard {
            Layout.topMargin: Kirigami.Units.largeSpacing

            FormCard.AbstractFormDelegate {
                background: null
                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: kcm.total > 0 ? "Занято " + kcm.formatSize(root.used) + " из " + kcm.formatSize(kcm.total) : "Подсчёт…"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                    }
                    // Доли, а не байты: стиль рисует полосу через целые 32 бита
                    QQC2.ProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        value: kcm.total > 0 ? root.used / kcm.total : 0
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        visible: kcm.total > 0
                        text: "Свободно " + kcm.formatSize(kcm.free)
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }

        FormCard.FormHeader {
            title: "Что занимает место"
        }

        FormCard.FormCard {
            Repeater {
                model: kcm.categories
                delegate: FormCard.AbstractFormDelegate {
                    required property var modelData
                    background: null
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing
                        Kirigami.Icon {
                            source: modelData.icon
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: implicitWidth
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            RowLayout {
                                Layout.fillWidth: true
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    elide: Text.ElideRight
                                }
                                QQC2.Label {
                                    text: kcm.formatSize(modelData.bytes)
                                    color: Kirigami.Theme.disabledTextColor
                                }
                            }
                            QQC2.ProgressBar {
                                Layout.fillWidth: true
                                from: 0
                                to: 1
                                value: root.used > 0 ? modelData.bytes / root.used : 0
                            }
                        }
                    }
                }
            }

            FormCard.AbstractFormDelegate {
                visible: kcm.busy
                background: null
                contentItem: RowLayout {
                    QQC2.BusyIndicator {
                        running: kcm.busy
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: implicitWidth
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: "Подсчёт…"
                    }
                }
            }
        }

        FormCard.FormHeader {
            title: "Очистка"
        }

        FormCard.FormCard {
            FormCard.FormButtonDelegate {
                icon.name: "edit-clear-all"
                text: "Очистить кэш приложений"
                description: kcm.formatSize(kcm.cacheBytes) + ". Приложения создадут его заново, первый запуск может быть медленнее"
                enabled: !kcm.busy && kcm.cacheBytes > 0
                onClicked: cacheDialog.open()
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormButtonDelegate {
                icon.name: "package-x-generic"
                text: "Удалить скачанные пакеты"
                description: kcm.packagesBytes > 0 ? kcm.formatSize(kcm.packagesBytes) + ". Установленные программы останутся, нужен PIN-код"
                                                   : "Скачанных пакетов нет"
                enabled: !kcm.busy && kcm.packagesBytes > 0
                onClicked: kcm.cleanPackages()
            }
        }

        FormCard.FormSectionText {
            visible: kcm.error !== ""
            text: "Не удалось: " + kcm.error
            color: Kirigami.Theme.negativeTextColor
        }
    }

    Kirigami.PromptDialog {
        id: cacheDialog
        title: "Очистить кэш приложений?"
        subtitle: "Будет удалено " + kcm.formatSize(kcm.cacheBytes) + ". Ваши файлы и настройки не пострадают."
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: kcm.clearCache()
    }
}
