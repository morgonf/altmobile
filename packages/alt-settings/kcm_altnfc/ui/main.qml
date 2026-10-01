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

// ALT Mobile: «NFC». Переключатель, состояние, что телефон умеет и
// история меток. Работа в службе alt-nfc (ru.altlinux.Nfc).
KCM.SimpleKCM {
    id: root

    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    function recordText(r) {
        switch (r.kind) {
        case "URI":
        case "SmartPoster":
            return (r.title ? r.title + ", " : "") + r.uri;
        case "Text":
            return "Текст «" + r.text + "»";
        case "WiFi":
            return "Сеть Wi-Fi " + r.ssid;
        case "Contact":
            return "Контакт";
        case "MIME":
            return "Данные " + r.mime;
        case "AAR":
            return "Приложение Android " + r.package;
        }
        return r.kind;
    }

    function tagSummary(t) {
        if (t.records && t.records.length > 0) {
            return t.records.map(recordText).join("; ");
        }
        return t.protocol === "ISO-DEP" ? "Карта без данных NFC (банковская, пропуск)" : "Метка без данных NFC";
    }

    // Строка с заголовком и пояснением. Готовая FormTextDelegate с переносом
    // уходила в бесконечный пересчёт раскладки (100 % ЦП в «Метках»)
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
                text: "NFC"
                description: !kcm.running ? "Служба alt-nfc не запущена"
                           : !kcm.available ? "Адаптер не найден"
                           : !kcm.enabled ? "Выключено"
                           : kcm.locked ? "Метки читаются после разблокировки"
                           : "Поднесите метку к задней крышке"
                enabled: kcm.running
                checked: kcm.enabled
                onToggled: kcm.setEnabled(checked)
            }
        }

        FormCard.FormSectionText {
            text: "Телефон читает метки и карты NFC (MIFARE Ultralight и NTAG, ISO-DEP). Ссылки, сети Wi-Fi, текст и контакты с меток предлагаются в уведомлении. Пока экран заблокирован, метки не читаются. Оплата телефоном невозможна, пропуска и ключи на 125 кГц NFC не видит."
        }

        FormCard.FormHeader {
            title: "Последние метки"
        }

        FormCard.FormCard {
            InfoRow {
                visible: kcm.history.length === 0
                text: "Меток пока не было"
            }

            Repeater {
                model: kcm.history
                delegate: InfoRow {
                    required property var modelData
                    text: root.tagSummary(modelData)
                    description: new Date(modelData.time * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat)
                                 + " · " + modelData.type + (modelData.uid ? " · UID " + modelData.uid : "")
                }
            }

            FormCard.FormDelegateSeparator { visible: kcm.history.length > 0 }

            FormCard.FormButtonDelegate {
                visible: kcm.history.length > 0
                icon.name: "edit-clear-history"
                text: "Очистить историю"
                onClicked: kcm.clearHistory()
            }
        }
    }
}
