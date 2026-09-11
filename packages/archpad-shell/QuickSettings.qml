import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

PanelWindow {
    id: panel

    required property bool expanded
    readonly property int batteryPercent: Number(batteryCapacity.text().trim()) || 0
    readonly property bool wifiEnabled: wifiState.text().trim() === "1"
    readonly property bool bluetoothEnabled: Bluetooth.defaultAdapter !== null
                                               && Bluetooth.defaultAdapter.enabled
    readonly property var audioSink: Pipewire.defaultAudioSink
    signal dismissed()
    signal settingsRequested()
    signal unavailableRequested(string feature)
    signal lockRequested()
    signal powerMenuRequested()

    visible: expanded
    focusable: true
    implicitWidth: 430
    implicitHeight: 650
    margins.top: 50
    margins.right: 12
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archpad-quick-settings"

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    FileView {
        id: batteryCapacity
        path: "/sys/class/power_supply/qcom-battery/capacity"
        blockLoading: true
    }

    FileView {
        id: batteryStatus
        path: "/sys/class/power_supply/qcom-battery/status"
        blockLoading: true
    }

    FileView {
        id: brightnessValue
        path: "/sys/class/backlight/ktz8866-backlight/brightness"
        blockLoading: true
    }

    FileView {
        id: brightnessMaximum
        path: "/sys/class/backlight/ktz8866-backlight/max_brightness"
        blockLoading: true
    }

    FileView {
        id: wifiState
        path: "/sys/class/rfkill/rfkill1/state"
        blockLoading: true
    }

    Process {
        id: brightnessSet
    }

    Process {
        id: wifiSet
        onExited: stateRefresh.restart()
    }

    Timer {
        id: brightnessCommit
        interval: 90
        onTriggered: brightnessSet.exec([
            "brightnessctl", "-q", "-d", "ktz8866-backlight", "set",
            Math.round(brightnessSlider.value * 100) + "%"
        ])
    }

    Timer {
        id: stateRefresh
        interval: 500
        onTriggered: {
            batteryCapacity.reload()
            batteryStatus.reload()
            brightnessValue.reload()
            brightnessMaximum.reload()
            wifiState.reload()
        }
    }

    Timer {
        interval: 3000
        running: panel.visible
        repeat: true
        onTriggered: stateRefresh.restart()
    }

    component QuickTile: Rectangle {
        id: tile

        required property string title
        required property string subtitle
        property bool active: false
        property bool available: true
        signal activated()

        width: 185
        height: 86
        radius: 22
        color: !available ? "#182132"
             : tileTouch.pressed ? "#425c88"
             : active ? "#74a7ff" : "#263248"
        border.width: 1
        border.color: active && available ? "#dce8ff" : "#45536a"
        opacity: available ? 1 : 0.58

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Text {
                text: tile.title
                color: tile.active && tile.available ? "#0d1522" : "#f4f7ff"
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Text {
                text: tile.subtitle
                color: tile.active && tile.available ? "#20324d" : "#aebbd0"
                font.pixelSize: 12
            }
        }

        MouseArea {
            id: tileTouch
            anchors.fill: parent
            onClicked: tile.activated()
        }
    }

    component PanelAction: Rectangle {
        id: action

        required property string label
        property bool available: true
        signal activated()

        width: 118
        height: 58
        radius: 18
        color: actionTouch.pressed && available ? "#425c88" : "#263248"
        border.width: 1
        border.color: "#45536a"
        opacity: available ? 1 : 0.5

        Text {
            anchors.centerIn: parent
            text: action.label
            color: "#eef3fc"
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: actionTouch
            anchors.fill: parent
            onClicked: action.activated()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 30
        color: "#f2172132"
        border.width: 1
        border.color: "#53627b"

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 18

            Row {
                width: parent.width
                height: 62

                Column {
                    width: parent.width - closeButton.width
                    spacing: 4

                    Text {
                        text: "Quick settings"
                        color: "#f7f9ff"
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
                              + "  •  " + panel.batteryPercent + "%  "
                              + batteryStatus.text().trim()
                        color: "#aebbd0"
                        font.pixelSize: 13
                    }
                }

                Rectangle {
                    id: closeButton
                    width: 52
                    height: 52
                    radius: 18
                    color: closeTouch.pressed ? "#425c88" : "#263248"

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: "#f4f7ff"
                        font.pixelSize: 26
                    }

                    MouseArea {
                        id: closeTouch
                        anchors.fill: parent
                        onClicked: panel.dismissed()
                    }
                }
            }

            Grid {
                columns: 2
                spacing: 14

                QuickTile {
                    title: "Wi‑Fi"
                    subtitle: panel.wifiEnabled ? "On" : "Off"
                    active: panel.wifiEnabled
                    onActivated: wifiSet.exec([
                        "iwctl", "device", "wlan0", "set-property", "Powered",
                        panel.wifiEnabled ? "off" : "on"
                    ])
                }

                QuickTile {
                    title: "Bluetooth"
                    subtitle: panel.bluetoothEnabled ? "On" : "Off"
                    active: panel.bluetoothEnabled
                    available: Bluetooth.defaultAdapter !== null
                    onActivated: {
                        if (Bluetooth.defaultAdapter !== null)
                            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                    }
                }

                QuickTile {
                    title: "Auto rotate"
                    subtitle: "Active • lock next"
                    active: true
                    available: false
                    onActivated: panel.unavailableRequested("Rotation lock")
                }

                QuickTile {
                    title: panel.audioSink !== null && panel.audioSink.audio.muted
                           ? "Sound muted" : "Sound"
                    subtitle: panel.audioSink !== null
                              ? Math.round(panel.audioSink.audio.volume * 100) + "%"
                              : "Unavailable"
                    active: panel.audioSink !== null && !panel.audioSink.audio.muted
                    available: panel.audioSink !== null
                    onActivated: {
                        if (panel.audioSink !== null)
                            panel.audioSink.audio.muted = !panel.audioSink.audio.muted
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8

                Row {
                    width: parent.width

                    Text {
                        width: parent.width - brightnessLabel.width
                        text: "Brightness"
                        color: "#eef3fc"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Text {
                        id: brightnessLabel
                        text: Math.round(brightnessSlider.value * 100) + "%"
                        color: "#aebbd0"
                        font.pixelSize: 14
                    }
                }

                Slider {
                    id: brightnessSlider
                    width: parent.width
                    height: 42
                    from: 0.05
                    to: 1.0
                    value: {
                        const maximum = Number(brightnessMaximum.text().trim()) || 2047
                        return (Number(brightnessValue.text().trim()) || 1) / maximum
                    }
                    onMoved: brightnessCommit.restart()
                }
            }

            Column {
                width: parent.width
                spacing: 8

                Row {
                    width: parent.width

                    Text {
                        width: parent.width - volumeLabel.width
                        text: "Volume"
                        color: "#eef3fc"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Text {
                        id: volumeLabel
                        text: panel.audioSink !== null
                              ? Math.round(volumeSlider.value * 100) + "%" : "—"
                        color: "#aebbd0"
                        font.pixelSize: 14
                    }
                }

                Slider {
                    id: volumeSlider
                    width: parent.width
                    height: 42
                    from: 0
                    to: 1
                    value: panel.audioSink !== null ? panel.audioSink.audio.volume : 0
                    enabled: panel.audioSink !== null
                    onMoved: {
                        if (panel.audioSink !== null)
                            panel.audioSink.audio.volume = value
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#45536a"
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                PanelAction {
                    label: "Settings"
                    onActivated: panel.settingsRequested()
                }

                PanelAction {
                    label: "Lock"
                    available: true
                    onActivated: panel.lockRequested()
                }

                PanelAction {
                    label: "Power"
                    available: true
                    onActivated: panel.powerMenuRequested()
                }
            }
        }
    }
}
