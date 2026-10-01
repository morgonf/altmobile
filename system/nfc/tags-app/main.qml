// SPDX-FileCopyrightText: 2026 morgonf
// SPDX-License-Identifier: MIT
//
// «Метки»: чтение и запись меток NFC для ALT Mobile (OnePlus 6T).
// Три вкладки: «Прочитать» (последняя метка и действия с её записями),
// «Записать» (ссылка, текст, сеть Wi-Fi, контакт на следующую поднесённую
// метку), «История». Вся работа в службе пользователя alt-nfc
// (ru.altlinux.Nfc на шине сеанса, system/nfc/alt-nfc.py): она читает
// метки через neard, пишет их (Tag.Write) и ведёт историю.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard 1 as FormCard
import org.kde.plasma.workspace.dbus as DBus

Kirigami.ApplicationWindow {
    id: app

    title: "Метки"
    width: Kirigami.Units.gridUnit * 22
    height: Kirigami.Units.gridUnit * 38

    property var history: []
    readonly property var lastTag: history.length > 0 ? history[0] : null
    readonly property bool enabled_: nfc.properties.Enabled ?? false
    readonly property bool locked: nfc.properties.Locked ?? false
    readonly property bool available: nfc.properties.Available ?? false
    readonly property bool running: nfc.properties.Enabled !== undefined
    readonly property bool writePending: nfc.properties.WritePending ?? false
    readonly property var lastWrite: {
        const s = app.str(nfc.properties.LastWrite);
        return s ? JSON.parse(s) : null;
    }

    // Модуль org.kde.plasma.workspace.dbus отдаёт строки D-Bus объектом
    // {"value": ...}, а логические значения обычными
    function str(x) {
        if (x === undefined || x === null) {
            return "";
        }
        return (typeof x === "object" && "value" in x) ? String(x.value) : String(x);
    }

    DBus.Properties {
        id: nfc
        busType: DBus.BusType.Session
        service: "ru.altlinux.Nfc"
        path: "/ru/altlinux/Nfc"
        iface: "ru.altlinux.Nfc"
    }

    function call(member, signature, args, onReply) {
        DBus.SessionBus.asyncCall({
            "service": "ru.altlinux.Nfc",
            "path": "/ru/altlinux/Nfc",
            "iface": "ru.altlinux.Nfc",
            "member": member,
            "signature": signature,
            "arguments": args,
        }, reply => { if (onReply) onReply(reply.value); }, reply => {
            if (reply.error) {
                errorMessage.text = reply.error.message;
                errorMessage.visible = true;
            }
        });
    }

    // Последний полученный текст истории. Присваиваем history только при
    // изменении: пересоздание карточек каждые 1,5 с занимало на телефоне
    // почти всё это время, приложение грузило ядро на 100 % и не успевало
    // обновлять интерфейс
    property string historyJson: ""

    function refresh() {
        call("GetHistory", "", [], value => {
            const text = app.str(value);
            if (text === app.historyJson) {
                return;
            }
            app.historyJson = text;
            try {
                app.history = JSON.parse(text);
            } catch (e) {
                app.history = [];
            }
        });
    }

    function act(record) {
        call("Act", "(s)", [new DBus.string(JSON.stringify(record))]);
    }

    function recordTitle(r) {
        switch (r.kind) {
        case "URI": case "SmartPoster": return r.title || "Ссылка";
        case "Text": return "Текст";
        case "WiFi": return "Сеть Wi-Fi";
        case "Contact": return "Контакт";
        case "MIME": return "Данные";
        case "AAR": return "Приложение Android";
        }
        return r.kind;
    }

    function recordText(r) {
        switch (r.kind) {
        case "URI": case "SmartPoster": return r.uri;
        case "Text": return r.text;
        case "WiFi": return r.ssid + (r.key ? "" : " (без пароля)");
        case "Contact": {
            const fn = (r.vcard || "").split(/\r?\n/).find(l => l.toUpperCase().startsWith("FN:"));
            return fn ? fn.substring(3) : "";
        }
        case "MIME": return r.mime + (r.size !== undefined ? ", " + r.size + " байт" : "");
        case "AAR": return r.package;
        }
        return "";
    }

    function recordAction(r) {
        switch (r.kind) {
        case "URI": case "SmartPoster": return "Открыть";
        case "Text": return "Копировать";
        case "WiFi": return "Подключиться";
        case "Contact": return "Сохранить";
        }
        return "";
    }

    function tagKind(t) {
        if (t.records && t.records.length > 0) {
            return "Метка с данными";
        }
        return t.protocol === "ISO-DEP" ? "Карта (банковская, пропуск, документ)" : "Метка без данных";
    }

    // История обновляется, пока окно открыто
    Timer {
        interval: 1500
        repeat: true
        running: app.visible
        triggeredOnStart: true
        onTriggered: app.refresh()
    }

    footer: ColumnLayout {
        spacing: 0

        Kirigami.InlineMessage {
            id: errorMessage
            Layout.fillWidth: true
            type: Kirigami.MessageType.Error
            showCloseButton: true
        }

        Kirigami.NavigationTabBar {
            Layout.fillWidth: true
            actions: [
                Kirigami.Action {
                    icon.name: "nfc"
                    text: "Прочитать"
                    checked: app.pageStack.currentItem === readPage
                    onTriggered: app.pageStack.replace(readPage)
                },
                Kirigami.Action {
                    icon.name: "document-edit"
                    text: "Записать"
                    checked: app.pageStack.currentItem === writePage
                    onTriggered: app.pageStack.replace(writePage)
                },
                Kirigami.Action {
                    icon.name: "view-history"
                    text: "История"
                    checked: app.pageStack.currentItem === historyPage
                    onTriggered: app.pageStack.replace(historyPage)
                }
            ]
        }
    }

    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.ToolBar
    pageStack.initialPage: readPage

    // Строка с заголовком и пояснением. Готовая FormTextDelegate с
    // переносом пояснения на телефоне уходила в бесконечный пересчёт
    // раскладки (100 % ЦП), поэтому своя
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

    // Строка записи с действием справа. Без вложенных раскладок вокруг
    // делегата и с Layout.preferredWidth: 0 у подписей: иначе перенос
    // текста и раскладка пересчитывали друг друга без конца
    component ActionRow: FormCard.AbstractFormDelegate {
        id: actionRoot
        property string description
        property string actionText
        Layout.fillWidth: true
        contentItem: RowLayout {
            spacing: Kirigami.Units.largeSpacing
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: Kirigami.Units.smallSpacing
                QQC2.Label {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    text: actionRoot.text
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    visible: text !== ""
                    text: actionRoot.description
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    color: Kirigami.Theme.disabledTextColor
                    font: Kirigami.Theme.smallFont
                }
            }
            QQC2.Label {
                visible: text !== ""
                text: actionRoot.actionText
                color: Kirigami.Theme.linkColor
            }
        }
    }

    // Поле ввода в карточке. Готовые поля FormCard зовут i18ndc, которого
    // нет у запуска через qml-qt6, поэтому свои
    component Field: FormCard.AbstractFormDelegate {
        id: fieldRoot
        property string label
        property alias value: input.text
        property alias placeholderText: input.placeholderText
        property alias inputMethodHints: input.inputMethodHints
        property alias echoMode: input.echoMode
        background: null
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            QQC2.Label {
                Layout.fillWidth: true
                // Ширина задаётся раскладкой, иначе перенос текста и
                // раскладка гоняли друг друга по кругу (100 % ЦП)
                Layout.preferredWidth: 0
                text: fieldRoot.label
                wrapMode: Text.WordWrap
            }
            QQC2.TextField {
                id: input
                Layout.fillWidth: true
            }
        }
    }

    // Состояние NFC и переключатель, если выключен
    component NfcState: FormCard.FormCard {
        FormCard.FormSwitchDelegate {
            text: "NFC"
            description: !app.running ? "Служба alt-nfc не запущена"
                       : !app.available ? "Адаптер не найден"
                       : !app.enabled_ ? "Выключено"
                       : app.locked ? "Метки читаются после разблокировки"
                       : "Включено"
            enabled: app.running
            checked: app.enabled_
            onToggled: app.call("SetEnabled", "(b)", [new DBus.bool(checked)])
        }
    }

    FormCard.FormCardPage {
        id: readPage
        visible: false
        // Без полосы прокрутки: её появление сужало страницу, текст
        // переносился иначе, полоса пропадала, и так по кругу (100 % ЦП)
        verticalScrollBarPolicy: QQC2.ScrollBar.AlwaysOff
        title: "Прочитать"

        NfcState {
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Kirigami.Units.iconSizes.enormous
                implicitHeight: implicitWidth
                source: "nfc"
                color: Kirigami.Theme.highlightColor
                isMask: true
            }
            QQC2.Label {
                Layout.fillWidth: true
                // Ширина задаётся раскладкой, иначе перенос текста и
                // раскладка гоняли друг друга по кругу (100 % ЦП)
                Layout.preferredWidth: 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Поднесите метку или карту к задней крышке телефона"
            }
        }

        FormCard.FormHeader {
            visible: app.lastTag !== null
            title: "Последняя метка"
        }

        FormCard.FormCard {
            visible: app.lastTag !== null

            InfoRow {
                text: app.lastTag ? app.tagKind(app.lastTag) : ""
                description: app.lastTag
                    ? new Date(app.lastTag.time * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat)
                      + " · " + app.lastTag.type + " · " + app.lastTag.protocol
                      + (app.lastTag.uid ? "\nUID " + app.lastTag.uid : "")
                    : ""
            }

            Repeater {
                model: app.lastTag ? app.lastTag.records : []
                delegate: ActionRow {
                    required property var modelData
                    text: app.recordTitle(modelData)
                    description: app.recordText(modelData)
                    actionText: app.recordAction(modelData)
                    onClicked: if (actionText) app.act(modelData)
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
                // Ширина задаётся раскладкой, иначе перенос текста и
                // раскладка гоняли друг друга по кругу (100 % ЦП)
                Layout.preferredWidth: 0
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.rightMargin: Kirigami.Units.gridUnit
            Layout.topMargin: Kirigami.Units.largeSpacing
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            visible: app.lastTag !== null && app.lastTag.records.length === 0
            text: "На этой метке нет данных NFC (ссылки, текста, сети, контакта). Транспортные и банковские карты хранят данные в защищённом виде, телефон видит только их тип и номер UID."
        }
    }

    FormCard.FormCardPage {
        id: writePage
        visible: false
        // Без полосы прокрутки: её появление сужало страницу, текст
        // переносился иначе, полоса пропадала, и так по кругу (100 % ЦП)
        verticalScrollBarPolicy: QQC2.ScrollBar.AlwaysOff
        title: "Записать"

        property int kind: 0
        readonly property var kinds: ["URI", "Text", "WiFi", "Contact"]

        function request() {
            const k = kinds[kind];
            if (k === "URI") {
                let u = uriField.value.trim();
                if (u && !/^[a-z][a-z0-9+.-]*:/i.test(u)) {
                    u = "https://" + u;
                }
                return { "kind": k, "uri": u };
            }
            if (k === "Text") {
                return { "kind": k, "text": textField.value, "lang": "ru" };
            }
            if (k === "WiFi") {
                return { "kind": k, "ssid": ssidField.value, "key": keyField.value };
            }
            return { "kind": k, "name": nameField.value, "phone": phoneField.value, "email": emailField.value };
        }

        readonly property bool valid: {
            switch (kinds[kind]) {
            case "URI": return uriField.value.trim().length > 0;
            case "Text": return textField.value.length > 0;
            case "WiFi": return ssidField.value.length > 0;
            case "Contact": return nameField.value.length > 0;
            }
            return false;
        }

        NfcState {
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        FormCard.FormHeader {
            title: "Что записать"
        }

        FormCard.FormCard {
            FormCard.FormComboBoxDelegate {
                text: "Тип"
                displayMode: FormCard.FormComboBoxDelegate.Dialog
                model: ["Ссылка", "Текст", "Сеть Wi-Fi", "Контакт"]
                currentIndex: writePage.kind
                onActivated: index => writePage.kind = index
            }

            FormCard.FormDelegateSeparator {}

            Field {
                id: uriField
                visible: writePage.kind === 0
                label: "Адрес"
                placeholderText: "https://example.ru"
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
            }
            Field {
                id: textField
                visible: writePage.kind === 1
                label: "Текст"
            }
            Field {
                id: ssidField
                visible: writePage.kind === 2
                label: "Имя сети (SSID)"
                inputMethodHints: Qt.ImhNoAutoUppercase
            }
            Field {
                id: keyField
                visible: writePage.kind === 2
                label: "Пароль (пусто для открытой сети)"
                echoMode: TextInput.Password
            }
            Field {
                id: nameField
                visible: writePage.kind === 3
                label: "Имя"
            }
            Field {
                id: phoneField
                visible: writePage.kind === 3
                label: "Телефон"
                inputMethodHints: Qt.ImhDialableCharactersOnly
            }
            Field {
                id: emailField
                visible: writePage.kind === 3
                label: "Почта"
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
            }
        }

        FormCard.FormCard {
            Layout.topMargin: Kirigami.Units.largeSpacing

            FormCard.FormButtonDelegate {
                visible: !app.writePending
                icon.name: "document-save"
                text: "Записать на метку"
                description: "Затем поднесите метку к задней крышке"
                enabled: writePage.valid && app.enabled_ && !app.locked
                onClicked: app.call("WriteTag", "(s)", [new DBus.string(JSON.stringify(writePage.request()))])
            }

            InfoRow {
                visible: app.writePending
                text: "Поднесите метку для записи"
                description: "Держите её у задней крышки, пока не появится сообщение"
            }

            FormCard.FormDelegateSeparator { visible: app.writePending }

            FormCard.FormButtonDelegate {
                visible: app.writePending
                icon.name: "dialog-cancel"
                text: "Отменить запись"
                onClicked: app.call("CancelWrite", "", [])
            }
        }

        FormCard.FormSectionText {
            visible: !app.writePending && app.lastWrite !== null
            text: app.lastWrite ? (app.lastWrite.ok ? "Метка записана." : "Не удалось записать (" + app.lastWrite.message + ").") : ""
        }

        FormCard.FormSectionText {
            text: "Подходят записываемые метки NFC, например наклейки NTAG213 и NTAG215. Транспортные и банковские карты записать нельзя."
        }
    }

    // История на ListView: у делегата ширина списка, петле раскладки
    // взяться неоткуда (FormCard с Repeater вешал приложение на 100 % ЦП)
    Kirigami.ScrollablePage {
        id: historyPage
        visible: false
        title: "История"

        actions: [
            Kirigami.Action {
                icon.name: "edit-clear-history"
                text: "Очистить"
                enabled: app.history.length > 0
                onTriggered: app.call("ClearHistory", "", [], () => app.refresh())
            }
        ]

        ListView {
            model: app.history

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 4
                visible: parent.count === 0
                text: "Меток пока не было"
            }

            delegate: QQC2.ItemDelegate {
                id: row
                required property var modelData
                width: ListView.view.width
                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Label {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        text: row.modelData.records.length > 0
                              ? row.modelData.records.map(r => app.recordTitle(r) + " " + app.recordText(r)).join("; ")
                              : app.tagKind(row.modelData)
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        wrapMode: Text.WordWrap
                        color: Kirigami.Theme.disabledTextColor
                        font: Kirigami.Theme.smallFont
                        text: new Date(row.modelData.time * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat)
                              + " · " + row.modelData.type + (row.modelData.uid ? " · UID " + row.modelData.uid : "")
                    }
                }
            }
        }
    }
}
