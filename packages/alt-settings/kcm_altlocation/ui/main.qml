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

// ALT Mobile: «Местоположение». Общий переключатель (как кнопка в шторке),
// программы, которые сейчас получают координаты, и как телефон их находит.
KCM.SimpleKCM {
    id: root

    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

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
                text: "Определять местоположение"
                description: kcm.busy ? "Подождите…"
                           : kcm.enabled ? "Программы могут запросить координаты"
                           : "Программы не получают координаты, GPS выключен"
                enabled: !kcm.busy
                checked: kcm.enabled
                onToggled: kcm.setEnabled(checked)
            }
        }

        FormCard.FormSectionText {
            visible: kcm.error !== ""
            text: "Не удалось: " + kcm.error
            color: Kirigami.Theme.negativeTextColor
        }

        FormCard.FormHeader {
            visible: kcm.enabled
            title: "Сейчас используют"
        }

        FormCard.FormCard {
            visible: kcm.enabled

            InfoRow {
                text: kcm.clients === 0 ? "Никто"
                    : kcm.clients === 1 ? "Одна программа"
                    : "Программ: " + kcm.clients
                description: kcm.clients > 0 ? "Какие именно, служба местоположения не сообщает" : ""
            }
        }

        FormCard.FormSectionText {
            text: "Место определяется по спутникам GPS приёмником модема, SIM-карта для этого не нужна, под крышей и в первые минуты координат может не быть. Если есть интернет, телефон дополнительно отправляет адреса видимых сетей Wi-Fi службе BeaconDB и получает примерное место, а без сетей Wi-Fi место грубо оценивается по IP-адресу. Переключатель тот же, что кнопка «Местоположение» в шторке."
        }
    }
}
