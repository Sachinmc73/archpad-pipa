import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: menu

    property bool open: false
    property string pendingAction: ""

    signal dismissed()

    visible: open
    focusable: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archpad-power-menu"

    Process {
        id: actionRunner
    }

    Timer {
        id: confirmTimeout
        interval: 4000
        onTriggered: menu.pendingAction = ""
    }

    function dismiss(): void {
        menu.pendingAction = ""
        confirmTimeout.stop()
        menu.open = false
        menu.dismissed()
    }

    function triggerAction(action: string): void {
        if (action === "sleep") {
            dismiss()
            actionRunner.exec(["systemctl", "suspend"])
            return
        }

        if (action === "logout") {
            if (menu.pendingAction !== "logout") {
                menu.pendingAction = "logout"
                confirmTimeout.restart()
                return
            }
            dismiss()
            actionRunner.exec(["loginctl", "terminate-user", "archpad"])
            return
        }

        if (action === "restart") {
            if (menu.pendingAction !== "restart") {
                menu.pendingAction = "restart"
                confirmTimeout.restart()
                return
            }
            dismiss()
            actionRunner.exec(["systemctl", "reboot"])
            return
        }

        if (action === "poweroff") {
            if (menu.pendingAction !== "poweroff") {
                menu.pendingAction = "poweroff"
                confirmTimeout.restart()
                return
            }
            dismiss()
            actionRunner.exec(["systemctl", "poweroff"])
            return
        }
    }

    // Scrim / Backdrop dismisses menu when tapped outside
    Rectangle {
        anchors.fill: parent
        color: "#b3080e18"

        MouseArea {
            anchors.fill: parent
            onClicked: menu.dismiss()
        }

        // Center card
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 440)
            height: contentCol.implicitHeight + 48
            radius: 28
            color: "#162032"
            border.width: 1
            border.color: "#3a4a64"

            // Prevent backdrop click when tapping card body
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: contentCol
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 24
                }
                spacing: 16

                // Header
                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: "#22324c"
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "⏻"
                            color: "#74a7ff"
                            font.pixelSize: 20
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Power"
                            color: "#f4f7ff"
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: menu.pendingAction.length > 0
                                  ? "Tap again to confirm destructive action"
                                  : "Select system power operation"
                            color: menu.pendingAction.length > 0 ? "#efad64" : "#94a3b8"
                            font.pixelSize: 12
                        }
                    }
                }

                // Divider
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#28374e"
                }

                // Action cards
                Column {
                    width: parent.width
                    spacing: 10

                    // 1. Sleep
                    Rectangle {
                        id: sleepBtn
                        width: parent.width
                        height: 64
                        radius: 18
                        color: sleepTouch.pressed ? "#273854" : "#1c293e"
                        border.width: 1
                        border.color: "#384a66"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            spacing: 16

                            Text {
                                text: "☾"
                                color: "#74a7ff"
                                font.pixelSize: 22
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: "Sleep"
                                    color: "#f4f7ff"
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                }

                                Text {
                                    text: "Lock session and suspend tablet"
                                    color: "#8fa1ba"
                                    font.pixelSize: 11
                                }
                            }
                        }

                        MouseArea {
                            id: sleepTouch
                            anchors.fill: parent
                            onClicked: menu.triggerAction("sleep")
                        }
                    }

                    // 2. Log Out
                    Rectangle {
                        id: logoutBtn
                        property bool confirming: menu.pendingAction === "logout"

                        width: parent.width
                        height: 64
                        radius: 18
                        color: confirming ? (logoutTouch.pressed ? "#8a5818" : "#593708")
                                          : (logoutTouch.pressed ? "#273854" : "#1c293e")
                        border.width: 1
                        border.color: confirming ? "#f6ad55" : "#384a66"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            spacing: 16

                            Text {
                                text: "→]"
                                color: logoutBtn.confirming ? "#fed7aa" : "#aebbd0"
                                font.pixelSize: 18
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: logoutBtn.confirming ? "Confirm Log Out" : "Log Out"
                                    color: logoutBtn.confirming ? "#ffedd5" : "#f4f7ff"
                                    font.pixelSize: 16
                                    font.weight: logoutBtn.confirming ? Font.Bold : Font.Medium
                                }

                                Text {
                                    text: logoutBtn.confirming ? "Tap again to end session" : "Close user session and return to greeter"
                                    color: logoutBtn.confirming ? "#fbd38d" : "#8fa1ba"
                                    font.pixelSize: 11
                                }
                            }
                        }

                        MouseArea {
                            id: logoutTouch
                            anchors.fill: parent
                            onClicked: menu.triggerAction("logout")
                        }
                    }

                    // 3. Restart
                    Rectangle {
                        id: restartBtn
                        property bool confirming: menu.pendingAction === "restart"

                        width: parent.width
                        height: 64
                        radius: 18
                        color: confirming ? (restartTouch.pressed ? "#8a5818" : "#593708")
                                          : (restartTouch.pressed ? "#273854" : "#1c293e")
                        border.width: 1
                        border.color: confirming ? "#f6ad55" : "#384a66"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            spacing: 16

                            Text {
                                text: "↻"
                                color: restartBtn.confirming ? "#fed7aa" : "#efad64"
                                font.pixelSize: 22
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: restartBtn.confirming ? "Confirm Restart" : "Restart"
                                    color: restartBtn.confirming ? "#ffedd5" : "#f4f7ff"
                                    font.pixelSize: 16
                                    font.weight: restartBtn.confirming ? Font.Bold : Font.Medium
                                }

                                Text {
                                    text: restartBtn.confirming ? "Tap again to reboot tablet" : "Reboot the operating system"
                                    color: restartBtn.confirming ? "#fbd38d" : "#8fa1ba"
                                    font.pixelSize: 11
                                }
                            }
                        }

                        MouseArea {
                            id: restartTouch
                            anchors.fill: parent
                            onClicked: menu.triggerAction("restart")
                        }
                    }

                    // 4. Shut Down
                    Rectangle {
                        id: poweroffBtn
                        property bool confirming: menu.pendingAction === "poweroff"

                        width: parent.width
                        height: 64
                        radius: 18
                        color: confirming ? (poweroffTouch.pressed ? "#881e1e" : "#5c1313")
                                          : (poweroffTouch.pressed ? "#273854" : "#1c293e")
                        border.width: 1
                        border.color: confirming ? "#fc8181" : "#384a66"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            spacing: 16

                            Text {
                                text: "⏻"
                                color: poweroffBtn.confirming ? "#fed7d7" : "#ff6666"
                                font.pixelSize: 20
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: poweroffBtn.confirming ? "Confirm Shut Down" : "Shut Down"
                                    color: poweroffBtn.confirming ? "#fff5f5" : "#f4f7ff"
                                    font.pixelSize: 16
                                    font.weight: poweroffBtn.confirming ? Font.Bold : Font.Medium
                                }

                                Text {
                                    text: poweroffBtn.confirming ? "Tap again to power off" : "Fully power off the tablet hardware"
                                    color: poweroffBtn.confirming ? "#feb2b2" : "#8fa1ba"
                                    font.pixelSize: 11
                                }
                            }
                        }

                        MouseArea {
                            id: poweroffTouch
                            anchors.fill: parent
                            onClicked: menu.triggerAction("poweroff")
                        }
                    }
                }

                // Cancel Button
                Rectangle {
                    width: parent.width
                    height: 48
                    radius: 16
                    color: cancelTouch.pressed ? "#223148" : "#182234"
                    border.width: 1
                    border.color: "#334158"

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: "#c9d5e8"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: cancelTouch
                        anchors.fill: parent
                        onClicked: menu.dismiss()
                    }
                }
            }
        }
    }
}
