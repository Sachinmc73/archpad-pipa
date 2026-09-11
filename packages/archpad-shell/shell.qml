import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property string notice: "ArchPad"
    property bool quickSettingsOpen: false
    property bool powerMenuOpen: false

    component TouchButton: Rectangle {
        id: button

        required property string label
        property string detail: ""
        property bool selected: false
        property color accent: "#74a7ff"
        signal activated()

        width: 72
        height: 64
        radius: 20
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
        onTriggered: root.notice = "ArchPad"
    }

    Process {
        id: lockRunner
    }

    IpcHandler {
        target: "power"

        function open(): void {
            root.quickSettingsOpen = false
            root.powerMenuOpen = true
        }

        function close(): void {
            root.powerMenuOpen = false
        }

        function toggle(): void {
            root.quickSettingsOpen = false
            root.powerMenuOpen = !root.powerMenuOpen
        }
    }

    PowerMenu {
        id: powerMenu
        open: root.powerMenuOpen
        onDismissed: root.powerMenuOpen = false
    }

    QuickSettings {
        id: quickSettings
        expanded: root.quickSettingsOpen
        onDismissed: root.quickSettingsOpen = false
        onLockRequested: {
            root.quickSettingsOpen = false
            lockRunner.exec(["loginctl", "lock-session"])
        }
        onPowerMenuRequested: {
            root.quickSettingsOpen = false
            root.powerMenuOpen = true
        }
        onSettingsRequested: {
            root.quickSettingsOpen = false
            root.notice = "ArchPad Settings is the next package"
            noticeReset.restart()
        }
        onUnavailableRequested: feature => {
            root.notice = feature + " is not packaged yet"
            noticeReset.restart()
        }
    }

    PanelWindow {
        id: desktop

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        color: "#0a1020"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "archpad-desktop"

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#18284a" }
                GradientStop { position: 0.48; color: "#101a32" }
                GradientStop { position: 1.0; color: "#080d19" }
            }
        }

        Rectangle {
            width: Math.max(parent.width, parent.height) * 0.72
            height: width
            radius: width / 2
            x: parent.width * 0.52
            y: -height * 0.26
            color: "#164f80d8"
        }

        Rectangle {
            width: Math.max(parent.width, parent.height) * 0.56
            height: width
            radius: width / 2
            x: -width * 0.48
            y: parent.height * 0.62
            color: "#123e8c8c"
        }
    }

    PanelWindow {
        id: topBar

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 38
        exclusiveZone: 38
        color: "transparent"
        WlrLayershell.namespace: "archpad-topbar"

        Rectangle {
            anchors.fill: parent
            color: "#e6151c29"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "hh:mm")
                    color: "#f7f9ff"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    width: 1
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#506078"
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: [1, 2, 3, 4]

                        delegate: Rectangle {
                            required property int modelData

                            property bool active: Hyprland.focusedWorkspace !== null
                                && Hyprland.focusedWorkspace.id === modelData

                            width: 28
                            height: 28
                            radius: 9
                            color: workspaceTouch.pressed ? "#91baff"
                                 : active ? "#74a7ff" : "#273349"
                            border.width: 1
                            border.color: active ? "#dce8ff" : "#46556e"

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: active ? "#0d1522" : "#e6ecf7"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: workspaceTouch
                                anchors.fill: parent
                                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + modelData + " })")
                            }
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: Math.min(noticeText.implicitWidth + 20, 230)
                    height: 26
                    radius: 9
                    color: "#263248"
                    border.width: 1
                    border.color: "#45536a"

                    Text {
                        id: noticeText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, 210)
                        text: root.notice
                        color: "#c9d5e8"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.quickSettingsOpen = !root.quickSettingsOpen
                    }
                }

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: "#68d391"
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        onClicked: root.quickSettingsOpen = !root.quickSettingsOpen
                    }
                }
            }
        }
    }

    PanelWindow {
        id: dockPanel

        anchors {
            bottom: true
        }

        implicitWidth: 390
        implicitHeight: 88
        margins.bottom: 14
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "archpad-dock"

        Rectangle {
            anchors.fill: parent
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
                    onActivated: Hyprland.dispatch("hl.dsp.exec_cmd('uwsm app -- foot')")
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
