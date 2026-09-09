import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
    id: root

    property string notice: "Touch-first development session"

    component TouchButton: Rectangle {
        id: button

        required property string label
        property string detail: ""
        property bool selected: false
        property color accent: "#74a7ff"
        signal activated()

        width: 72
        height: 64
        radius: 18
        color: touch.pressed ? Qt.lighter(accent, 1.12)
                             : selected ? accent : "#263248"
        border.width: selected ? 2 : 1
        border.color: selected ? "#d9e7ff" : "#45536a"

        Column {
            anchors.centerIn: parent
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: button.label
                color: button.selected ? "#0d1522" : "#f4f7ff"
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }

            Text {
                visible: button.detail.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: button.detail
                color: button.selected ? "#18263a" : "#aebbd0"
                font.pixelSize: 11
            }
        }

        MouseArea {
            id: touch
            anchors.fill: parent
            onClicked: button.activated()
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Timer {
        id: noticeReset
        interval: 2500
        onTriggered: root.notice = "Touch-first development session"
    }

    PanelWindow {
        id: topBar

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 68
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#e6151c29"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "hh:mm")
                    color: "#f7f9ff"
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    width: 1
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#506078"
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        model: [1, 2, 3, 4]

                        delegate: Rectangle {
                            required property int modelData

                            property bool active: Hyprland.focusedWorkspace !== null
                                && Hyprland.focusedWorkspace.id === modelData

                            width: 46
                            height: 46
                            radius: 15
                            color: workspaceTouch.pressed ? "#91baff"
                                 : active ? "#74a7ff" : "#273349"
                            border.width: 1
                            border.color: active ? "#dce8ff" : "#46556e"

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: active ? "#0d1522" : "#e6ecf7"
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: workspaceTouch
                                anchors.fill: parent
                                onClicked: Hyprland.dispatch("workspace " + modelData)
                            }
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Rectangle {
                    width: Math.min(noticeText.implicitWidth + 30, 330)
                    height: 42
                    radius: 14
                    color: "#263248"
                    border.width: 1
                    border.color: "#45536a"

                    Text {
                        id: noticeText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, 300)
                        text: root.notice
                        color: "#c9d5e8"
                        font.pixelSize: 15
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: "#68d391"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    PanelWindow {
        id: dockPanel

        anchors {
            bottom: true
            left: true
            right: true
        }

        implicitHeight: 112
        color: "transparent"

        Rectangle {
            width: 390
            height: 88
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            radius: 30
            color: "#ed1a2232"
            border.width: 1
            border.color: "#53627b"

            Row {
                anchors.centerIn: parent
                spacing: 16

                TouchButton {
                    label: "A"
                    detail: "Apps"
                    accent: "#d08cff"
                    onActivated: {
                        root.notice = "App drawer is the next shell slice"
                        noticeReset.restart()
                    }
                }

                TouchButton {
                    label: ">_"
                    detail: "Terminal"
                    accent: "#74a7ff"
                    onActivated: Hyprland.dispatch("exec uwsm app -- foot")
                }

                TouchButton {
                    label: "▦"
                    detail: "Overview"
                    accent: "#73d6b2"
                    onActivated: {
                        root.notice = "Overview is not implemented yet"
                        noticeReset.restart()
                    }
                }

                TouchButton {
                    label: "USB"
                    detail: "Recovery"
                    accent: "#efad64"
                    onActivated: {
                        root.notice = "USB SSH recovery is online"
                        noticeReset.restart()
                    }
                }
            }
        }
    }
}
