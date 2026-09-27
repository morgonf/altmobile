// Разблокировка SIM-карты для Plasma Mobile на OnePlus 6T.
// Экран как у ввода PIN телефона: заголовок, кружки вместо цифр и своя
// цифровая панель. Системная клавиатура не открывается вовсе (раньше
// сначала выезжала полная, потом менялась на цифровую). Код уходит прямо в
// ModemManager (Sim.SendPin, после трёх ошибок Sim.SendPuk с новым PIN).
// Путь SIM, вид замка и число попыток передаёт alt-sim-unlock после «--».
// Без пароля пользователя вызов разрешает 50-alt-mobile-sim.rules (polkit).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.dbus as DBus

Kirigami.ApplicationWindow {
    id: root

    readonly property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    readonly property string simPath: args[0] ?? ""
    property bool puk: args[1] === "sim-puk"
    property int retries: parseInt(args[2] ?? "-1")
    // Для PUK два шага: сначала сам PUK, потом новый PIN
    property string pukCode: ""
    property string entry: ""
    property bool busy: false
    property bool done: false
    property string error: ""

    readonly property bool askNewPin: puk && pukCode.length > 0
    readonly property int maxLength: 8
    readonly property bool entryValid: (puk && !askNewPin) ? entry.length === 8
                                                           : entry.length >= 4 && entry.length <= 8

    title: "SIM-карта"
    width: Kirigami.Units.gridUnit * 20
    height: Kirigami.Units.gridUnit * 34

    function retriesText(n) {
        if (n < 0)
            return "";
        const m10 = n % 10, m100 = n % 100;
        const word = (m10 === 1 && m100 !== 11) ? "попытка"
            : (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) ? "попытки" : "попыток";
        return "Осталось " + n + " " + word;
    }

    function press(digit) {
        if (busy || done || entry.length >= maxLength)
            return;
        error = "";
        entry += digit;
    }

    function erase() {
        if (!busy && !done)
            entry = entry.slice(0, -1);
    }

    function submit() {
        if (busy || done || !entryValid)
            return;
        if (puk && !askNewPin) {
            pukCode = entry;
            entry = "";
            return;
        }
        busy = true;
        error = "";
        const msg = {
            "service": "org.freedesktop.ModemManager1",
            "path": simPath,
            "iface": "org.freedesktop.ModemManager1.Sim",
            "member": puk ? "SendPuk" : "SendPin",
            // сигнатура в скобках, как у Introspect: без них Encoder теряет аргументы
            "signature": puk ? "(ss)" : "(s)",
            "arguments": puk ? [new DBus.string(pukCode), new DBus.string(entry)]
                             : [new DBus.string(entry)],
        };
        DBus.SystemBus.asyncCall(msg, reply => {
            busy = false;
            done = true;
            entry = "";
            closeTimer.start();
        }, reply => {
            busy = false;
            entry = "";
            pukCode = "";
            const name = reply.error ? reply.error.name : "";
            if (name.indexOf("IncorrectPassword") >= 0) {
                if (retries > 0)
                    retries -= 1;
                if (!puk && retries === 0) {
                    puk = true;
                    retries = 10;
                    error = "PIN-код заблокирован";
                } else {
                    error = "Неверный код";
                }
            } else {
                error = "Не удалось: " + (reply.error ? reply.error.message : "нет ответа от модема");
            }
        });
    }

    Timer {
        id: closeTimer
        interval: 1200
        onTriggered: Qt.quit()
    }

    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None
    pageStack.initialPage: Kirigami.Page {
        id: page
        padding: Kirigami.Units.gridUnit
        focus: true

        // Физическая клавиатура, если подключена
        Keys.onPressed: event => {
            if (event.text >= "0" && event.text <= "9" && event.text.length === 1)
                root.press(event.text);
            else if (event.key === Qt.Key_Backspace)
                root.erase();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.submit();
            else
                return;
            event.accepted = true;
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            Item { Layout.fillHeight: true }

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Kirigami.Units.iconSizes.large
                implicitHeight: Kirigami.Units.iconSizes.large
                source: root.done ? "dialog-ok" : "smartphone"
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                level: 2
                text: root.done ? "SIM-карта разблокирована"
                    : root.askNewPin ? "Новый PIN-код"
                    : root.puk ? "PUK-код SIM-карты"
                    : "PIN-код SIM-карты"
            }

            QQC2.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: root.error ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
                text: root.done ? "Мобильная связь подключается"
                    : root.busy ? "Проверка…"
                    : root.error ? root.error + (root.retries >= 0 ? ". " + root.retriesText(root.retries) : "")
                    : root.askNewPin ? "От 4 до 8 цифр"
                    : root.puk ? "8 цифр из документов к SIM-карте. " + root.retriesText(root.retries)
                    : root.retriesText(root.retries)
            }

            // Кружки вместо введённых цифр
            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                spacing: Kirigami.Units.largeSpacing
                visible: !root.done
                Repeater {
                    model: root.entry.length
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Kirigami.Units.gridUnit * 0.7
                        height: width
                        radius: width / 2
                        color: Kirigami.Theme.textColor
                    }
                }
            }

            Item { Layout.preferredHeight: Kirigami.Units.largeSpacing }

            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: 3
                rowSpacing: Kirigami.Units.largeSpacing
                columnSpacing: Kirigami.Units.gridUnit * 1.5
                visible: !root.done

                Repeater {
                    model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "erase", "0", "ok"]
                    delegate: QQC2.RoundButton {
                        required property string modelData
                        readonly property bool digit: modelData.length === 1

                        Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 4
                        focusPolicy: Qt.NoFocus
                        flat: !digit
                        text: digit ? modelData : ""
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.8
                        icon.name: modelData === "erase" ? "edit-clear"
                                 : modelData === "ok" ? "dialog-ok-apply" : ""
                        icon.width: Kirigami.Units.iconSizes.medium
                        icon.height: Kirigami.Units.iconSizes.medium
                        enabled: !root.busy && (modelData === "ok" ? root.entryValid
                                               : modelData === "erase" ? root.entry.length > 0 : true)
                        highlighted: modelData === "ok" && root.entryValid
                        onClicked: modelData === "erase" ? root.erase()
                                 : modelData === "ok" ? root.submit()
                                 : root.press(modelData)
                        onPressAndHold: if (modelData === "erase") root.entry = ""
                    }
                }
            }

            Item { Layout.fillHeight: true }

            QQC2.Button {
                Layout.alignment: Qt.AlignHCenter
                flat: true
                visible: !root.done
                text: "Позже"
                onClicked: Qt.quit()
            }
        }
    }
}
