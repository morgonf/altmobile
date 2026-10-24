import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

ApplicationWindow {
    id: win
    visible: true
    title: "Джарвис"
    width: 400
    height: 800
    color: "#05080d"

    property color accent: assistant.state === "thinking" ? "#ffb347"
                                  : assistant.state === "listening" ? "#7ff9ff" : "#3fd5ff"
    readonly property string statusText: ({
        idle: "Коснитесь реактора и говорите",
        listening: "Слушаю…",
        thinking: "Думаю…",
        speaking: "Говорю… (коснитесь, чтобы прервать)"
    })[assistant.state]

    Behavior on accent { ColorAnimation { duration: 300 } }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // --- реактор ---
        Item {
            id: reactor
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(win.width * 0.8, win.height * 0.4)

            property real size: Math.min(width, height)
            property real pulse: 1.0
            property real spin: 0

            SequentialAnimation on pulse {
                loops: Animation.Infinite
                running: assistant.state !== "listening"
                NumberAnimation { to: assistant.state === "speaking" ? 1.06 : 1.02; duration: assistant.state === "speaking" ? 350 : 1600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: assistant.state === "speaking" ? 350 : 1600; easing.type: Easing.InOutSine }
            }
            NumberAnimation on spin {
                from: 0; to: 360; loops: Animation.Infinite
                duration: assistant.state === "thinking" ? 1500 : 12000
            }

            Item {
                anchors.centerIn: parent
                width: reactor.size
                height: reactor.size
                scale: assistant.state === "listening" ? 1.0 + assistant.level * 0.25 : reactor.pulse
                Behavior on scale { NumberAnimation { duration: 90 } }

                // свечение
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.9; height: width; radius: width / 2
                    color: "transparent"
                    border.width: width * 0.02
                    border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.25)
                }
                // внешнее кольцо из сегментов
                Repeater {
                    model: 10
                    Shape {
                        anchors.fill: parent
                        rotation: reactor.spin + index * 36
                        ShapePath {
                            strokeColor: win.accent
                            strokeWidth: reactor.size * 0.035
                            fillColor: "transparent"
                            capStyle: ShapePath.FlatCap
                            PathAngleArc {
                                centerX: reactor.size / 2; centerY: reactor.size / 2
                                radiusX: reactor.size * 0.40; radiusY: radiusX
                                startAngle: 0; sweepAngle: 24
                            }
                        }
                    }
                }
                // внутреннее кольцо, крутится навстречу
                Repeater {
                    model: 3
                    Shape {
                        anchors.fill: parent
                        rotation: -reactor.spin * 1.5 + index * 120
                        ShapePath {
                            strokeColor: Qt.lighter(win.accent, 1.3)
                            strokeWidth: reactor.size * 0.02
                            fillColor: "transparent"
                            PathAngleArc {
                                centerX: reactor.size / 2; centerY: reactor.size / 2
                                radiusX: reactor.size * 0.28; radiusY: radiusX
                                startAngle: 0; sweepAngle: 80
                            }
                        }
                    }
                }
                // ядро
                Rectangle {
                    anchors.centerIn: parent
                    width: reactor.size * 0.3; height: width; radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "white" }
                        GradientStop { position: 0.5; color: win.accent }
                        GradientStop { position: 1.0; color: Qt.darker(win.accent, 2.5) }
                    }
                    opacity: 0.85 + (assistant.state === "listening" ? assistant.level * 0.15 : 0)
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: assistant.tap()
            }
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: win.statusText
            color: win.accent
            font.pixelSize: 15
            font.letterSpacing: 1
        }

        // --- лента разговора ---
        ListView {
            id: chat
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: assistant.messages
            onCountChanged: positionViewAtEnd()
            onContentHeightChanged: positionViewAtEnd()

            delegate: Item {
                required property var modelData
                width: chat.width
                height: bubble.height

                Rectangle {
                    id: bubble
                    readonly property bool mine: modelData.role === "user"
                    readonly property bool sys: modelData.role === "system"
                    anchors.right: mine ? parent.right : undefined
                    anchors.left: mine ? undefined : parent.left
                    width: Math.min(chat.width * (sys ? 1.0 : 0.85), txt.implicitWidth + 24)
                    height: txt.implicitHeight + 16
                    radius: 12
                    color: mine ? "#13304a" : sys ? "transparent" : "#0c1a24"
                    border.color: sys ? "#1e3a4a" : Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.35)
                    border.width: 1

                    Text {
                        id: txt
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        text: modelData.text === "" ? "…" : modelData.text
                        wrapMode: Text.Wrap
                        color: bubble.sys ? "#6f8fa3" : "#e3f6ff"
                        font.pixelSize: bubble.sys ? 12 : 16
                        font.family: bubble.sys ? "monospace" : ""
                    }
                }
            }
        }

        // --- подтверждение действия ---
        Rectangle {
            Layout.fillWidth: true
            visible: assistant.pending !== ""
            implicitHeight: confirmRow.implicitHeight + 20
            radius: 12
            color: "#2a1c08"
            border.color: "#ffb347"

            ColumnLayout {
                id: confirmRow
                anchors.fill: parent
                anchors.margins: 10
                Label {
                    Layout.fillWidth: true
                    text: "Выполнить: " + assistant.pending + "?"
                    color: "#ffd9a0"
                    wrapMode: Text.Wrap
                    font.pixelSize: 16
                }
                RowLayout {
                    Layout.fillWidth: true
                    Button { Layout.fillWidth: true; text: "Да"; onClicked: assistant.confirm(true) }
                    Button { Layout.fillWidth: true; text: "Нет"; onClicked: assistant.confirm(false) }
                }
            }
        }

        // --- ввод текстом ---
        RowLayout {
            Layout.fillWidth: true
            TextField {
                id: input
                Layout.fillWidth: true
                placeholderText: "Или напишите…"
                color: "#e3f6ff"
                placeholderTextColor: "#4f6f83"
                background: Rectangle { radius: 10; color: "#0c1a24"; border.color: "#1e3a4a" }
                onAccepted: send.clicked()
            }
            Button {
                id: send
                text: "➤"
                onClicked: { assistant.send(input.text); input.text = "" }
            }
        }
    }
}
