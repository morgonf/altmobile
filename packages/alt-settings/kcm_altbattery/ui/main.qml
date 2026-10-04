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

// ALT Mobile: «Здоровье батареи». Износ по оценке датчика заряда и
// ограничение заряда.
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

        FormCard.FormHeader {
            title: "Износ"
        }

        FormCard.FormCard {
            InfoRow {
                text: kcm.health < 0 ? "Датчик ещё не оценил износ"
                    : "Ёмкость " + kcm.health + " % от новой"
                description: kcm.health < 0 ? "Оценка появится после нескольких циклов заряда"
                    : "Около " + Math.round(kcm.designCapacity * kcm.health / 100) + " мА·ч из " + kcm.designCapacity + ". Оценку даёт датчик заряда по своим замерам, она обновляется раз в час"
            }
        }

        FormCard.FormSectionText {
            visible: kcm.health >= 0 && kcm.health < 80
            text: "Батарея заметно изношена. Программно ёмкость не вернуть, поможет только замена батареи. Замедлить дальнейший износ поможет ограничение заряда."
        }

        FormCard.FormHeader {
            title: "Зарядка"
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                text: "Ограничить заряд до " + kcm.limit + " %"
                description: kcm.busy ? "Подождите…"
                           : kcm.limitEnabled ? "Зарядка отключается на " + kcm.limit + " % и включается снова на " + kcm.resume + " %"
                           : "Телефон заряжается до 100 %"
                enabled: !kcm.busy
                checked: kcm.limitEnabled
                onToggled: kcm.setLimitEnabled(checked)
            }
        }

        FormCard.FormSectionText {
            visible: kcm.error !== ""
            text: "Не удалось: " + kcm.error
            color: Kirigami.Theme.negativeTextColor
        }

        FormCard.FormSectionText {
            text: "Батарея стареет быстрее, пока держит полный заряд. Если телефон подолгу лежит на зарядке, ограничение замедляет износ, зато без зарядки он проработает меньше. Пока зарядка отключена, телефон работает от батареи даже с подключённым кабелем, и в строке состояния видна разрядка."
        }
    }
}
