// Разблокировка SIM-карты для Plasma Mobile на OnePlus 6T.
// Окно в стиле настроек (карточки FormCard), код уходит прямо в
// ModemManager (Sim.SendPin или Sim.SendPuk). Пути модема и SIM, вид замка
// и число попыток передаёт alt-sim-unlock после «--».
// Без пароля пользователя вызов разрешает 50-alt-mobile-sim.rules (polkit).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import org.kde.plasma.workspace.dbus as DBus

Kirigami.ApplicationWindow {
    id: root

    readonly property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    readonly property string simPath: args[0] ?? ""
    property bool puk: args[1] === "sim-puk"
    property int retries: parseInt(args[2] ?? "-1")
    property bool busy: false
    property bool done: false
    property string error: ""

    title: "SIM-карта"
    width: Kirigami.Units.gridUnit * 20
    height: Kirigami.Units.gridUnit * 30

    function retriesText(n) {
        if (n < 0)
            return "";
        const m10 = n % 10, m100 = n % 100;
        const word = (m10 === 1 && m100 !== 11) ? "попытка"
            : (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) ? "попытки" : "попыток";
        return "Осталось " + n + " " + word;
    }

    function submit() {
        if (busy || !valid())
            return;
        busy = true;
        error = "";
        const msg = {
            "service": "org.freedesktop.ModemManager1",
            "path": simPath,
            "iface": "org.freedesktop.ModemManager1.Sim",
            "member": puk ? "SendPuk" : "SendPin",
            // сигнатура в скобках, как у Introspect: без них Encoder теряет аргументы
            "signature": puk ? "(ss)" : "(s)",
            "arguments": puk ? [new DBus.string(pukField.text), new DBus.string(pinField.text)]
                             : [new DBus.string(pinField.text)],
        };
        DBus.SystemBus.asyncCall(msg, reply => {
            busy = false;
            done = true;
            closeTimer.start();
        }, reply => {
            busy = false;
            pinField.clear();
            pukField.clear();
            const name = reply.error ? reply.error.name : "";
            if (name.indexOf("IncorrectPassword") >= 0) {
                if (retries > 0)
                    retries -= 1;
                if (!puk && retries === 0) {
                    puk = true;
                    retries = 10;
                    error = "PIN-код заблокирован. Введите PUK-код из документов к SIM-карте и новый PIN-код.";
                } else {
                    error = "Неверный код. " + retriesText(retries) + ".";
                }
            } else {
                error = "Не удалось разблокировать: " + (reply.error ? reply.error.message : "нет ответа от модема");
            }
            (puk ? pukField : pinField).forceActiveFocus();
        });
    }

    function valid() {
        const pinOk = /^[0-9]{4,8}$/.test(pinField.text);
        return puk ? pinOk && /^[0-9]{8}$/.test(pukField.text) : pinOk;
    }

    Timer {
        id: closeTimer
        interval: 1500
        onTriggered: Qt.quit()
    }

    pageStack.initialPage: FormCard.FormCardPage {
        title: "Разблокировка SIM-карты"

        FormCard.FormHeader {
            title: root.puk ? "PUK-код" : "PIN-код"
        }

        FormCard.FormCard {
            FormCard.FormTextDelegate {
                icon.name: "smartphone"
                text: root.done ? "SIM-карта разблокирована"
                    : root.puk ? "PIN-код заблокирован после трёх ошибок"
                    : "SIM-карта защищена PIN-кодом"
                description: root.done ? "Мобильная связь подключается."
                    : root.puk ? "Введите PUK-код из документов к SIM-карте и придумайте новый PIN-код. " + root.retriesText(root.retries) + "."
                    : "Введите PIN-код, чтобы пользоваться звонками и мобильным интернетом. " + root.retriesText(root.retries) + "."
                textItem.wrapMode: Text.WordWrap
                descriptionItem.wrapMode: Text.WordWrap
            }

            FormCard.FormDelegateSeparator { visible: root.puk && !root.done }

            FormCard.FormPasswordFieldDelegate {
                id: pukField
                visible: root.puk && !root.done
                label: "PUK-код"
                maximumLength: 8
                inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                enabled: !root.busy
                onAccepted: pinField.forceActiveFocus()
            }

            FormCard.FormDelegateSeparator { visible: !root.done }

            FormCard.FormPasswordFieldDelegate {
                id: pinField
                visible: !root.done
                label: root.puk ? "Новый PIN-код" : "PIN-код"
                maximumLength: 8
                inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                enabled: !root.busy
                statusMessage: root.error
                status: Kirigami.MessageType.Error
                onAccepted: root.submit()
            }

            FormCard.FormDelegateSeparator { visible: !root.done }

            FormCard.FormButtonDelegate {
                visible: !root.done
                icon.name: root.busy ? "view-refresh" : "unlock"
                text: root.busy ? "Проверка…" : "Разблокировать"
                enabled: !root.busy && (pinField.text.length > 0)
                onClicked: root.submit()
            }
        }

        FormCard.FormCard {
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: !root.done

            FormCard.FormButtonDelegate {
                icon.name: "dialog-cancel"
                text: "Позже"
                description: "Звонки и мобильный интернет останутся недоступны. Разблокировать можно из уведомления."
                onClicked: Qt.quit()
            }
        }
    }

    Component.onCompleted: Qt.callLater(() => (root.puk ? pukField : pinField).forceActiveFocus())
}
