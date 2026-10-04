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

// ALT Mobile: «Доступ по SSH». Переключатель сервера SSH (включение
// подтверждается PIN-кодом), адреса для входа, ключи и настройки входа.
KCM.SimpleKCM {
    id: root

    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    readonly property bool passwordLogin: kcm.settings.passwordauthentication === "yes"
                                          || kcm.settings.kbdinteractiveauthentication === "yes"
    readonly property bool rootLogin: kcm.settings.permitrootlogin !== undefined
                                      && kcm.settings.permitrootlogin !== "no"
    readonly property string port: kcm.settings.port || "22"

    // Строка с заголовком и пояснением, переносится по словам
    component InfoRow: FormCard.AbstractFormDelegate {
        id: infoRoot
        property string description
        background: null
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            QQC2.Label {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: infoRoot.text
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
            QQC2.Label {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                visible: text !== ""
                text: infoRoot.description
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
            }
        }
    }

    ColumnLayout {
        spacing: 0

        FormCard.FormCard {
            Layout.topMargin: Kirigami.Units.largeSpacing

            FormCard.FormSwitchDelegate {
                text: "Доступ по SSH"
                description: kcm.busy ? "Подождите…"
                           : kcm.active ? (kcm.enabledAtBoot ? "Включён, в том числе после перезагрузки" : "Включён до перезагрузки")
                           : (kcm.enabledAtBoot ? "Выключен до перезагрузки" : "Выключен")
                enabled: !kcm.busy
                checked: kcm.active
                onToggled: kcm.setEnabled(checked)
            }
        }

        FormCard.FormSectionText {
            visible: kcm.error !== ""
            text: "Не удалось: " + kcm.error
            color: Kirigami.Theme.negativeTextColor
        }

        FormCard.FormSectionText {
            text: "С включённым доступом на телефон можно войти с компьютера и управлять им из терминала. Включайте его, только когда это нужно, и только в доверенной сети."
        }

        FormCard.FormHeader {
            visible: kcm.active
            title: "Как войти"
        }

        FormCard.FormCard {
            visible: kcm.active

            InfoRow {
                visible: kcm.addresses.length === 0
                text: "Телефон не подключён к сети"
            }

            Repeater {
                model: kcm.addresses
                delegate: InfoRow {
                    required property string modelData
                    text: "ssh " + (root.port !== "22" ? "-p " + root.port + " " : "") + kcm.userName + "@" + (modelData.indexOf(":") >= 0 ? "[" + modelData + "]" : modelData)
                    description: modelData.indexOf(":") >= 0 ? "Адрес IPv6" : "Адрес в локальной сети"
                }
            }
        }

        FormCard.FormHeader {
            title: "Вход"
        }

        FormCard.FormCard {
            InfoRow {
                text: kcm.keyCount === 0 ? "Ключей нет"
                    : kcm.keyCount === 1 ? "Разрешён 1 ключ"
                    : "Разрешено ключей: " + kcm.keyCount
                description: kcm.keyCount === 0 && !root.passwordLogin
                             ? "Войти не получится: добавьте открытый ключ компьютера в ~/.ssh/authorized_keys"
                             : "Список в ~/.ssh/authorized_keys"
            }

            FormCard.FormDelegateSeparator {}

            InfoRow {
                visible: kcm.settings.port !== undefined
                text: root.passwordLogin ? "Вход по паролю разрешён" : "Вход по паролю запрещён"
                description: root.passwordLogin ? "Пароль подбирают перебором, надёжнее входить только по ключу"
                                                : "Войти можно только по ключу"
            }

            FormCard.FormDelegateSeparator { visible: kcm.settings.port !== undefined }

            InfoRow {
                visible: kcm.settings.port !== undefined
                text: root.rootLogin ? "Вход для root разрешён" : "Вход для root запрещён"
                description: root.rootLogin ? "" : "Права root после входа дают su и sudo"
            }
        }
    }
}
