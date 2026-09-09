import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    visibility: Window.FullScreen
    color: "#10141c"
    title: "ArchPad Touch Test"

    property int taps: 0
    property int activeTouches: 0
    property real pinchScale: 1.0

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#172033" }
            GradientStop { position: 1.0; color: "#0b0e14" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 20

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    text: "ArchPad touch test"
                    color: "white"
                    font.pixelSize: 34
                    font.bold: true
                }
                Label {
                    text: "Tap, drag, scroll, and pinch using the areas below"
                    color: "#b9c3d5"
                    font.pixelSize: 19
                }
            }

            Button {
                text: "Close test"
                font.pixelSize: 20
                padding: 18
                onClicked: Qt.quit()
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 16

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                text: "Tap me\n" + root.taps + " taps"
                font.pixelSize: 22
                onClicked: root.taps++
            }
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                text: "Active touches\n" + root.activeTouches
                font.pixelSize: 22
                enabled: false
            }
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                text: "Reset"
                font.pixelSize: 22
                onClicked: {
                    root.taps = 0
                    root.pinchScale = 1.0
                    dragTarget.x = 30
                    dragTarget.y = 30
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 18

            Frame {
                Layout.fillWidth: true
                Layout.fillHeight: true
                background: Rectangle { color: "#202838"; radius: 24; border.color: "#44516a" }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Label { text: "1. Drag"; color: "white"; font.pixelSize: 25; font.bold: true }
                    Label { text: "Move the blue square continuously"; color: "#b9c3d5"; font.pixelSize: 17 }
                    Item {
                        id: dragArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Rectangle {
                            id: dragTarget
                            x: 30; y: 30
                            width: 130; height: 130
                            radius: 28
                            color: drag.active ? "#72d6ff" : "#2997d6"
                            border.width: 3
                            border.color: "white"
                            Label { anchors.centerIn: parent; text: "DRAG"; color: "white"; font.pixelSize: 20; font.bold: true }
                            DragHandler {
                                id: drag
                                xAxis.minimum: 0
                                yAxis.minimum: 0
                                xAxis.maximum: dragArea.width - dragTarget.width
                                yAxis.maximum: dragArea.height - dragTarget.height
                            }
                        }
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.fillHeight: true
                background: Rectangle { color: "#202838"; radius: 24; border.color: "#44516a" }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Label { text: "2. Scroll"; color: "white"; font.pixelSize: 25; font.bold: true }
                    Label { text: "Swipe this list up and down"; color: "#b9c3d5"; font.pixelSize: 17 }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 9
                        model: 20
                        delegate: Rectangle {
                            required property int index
                            width: ListView.view.width
                            height: 62
                            radius: 16
                            color: index % 2 ? "#36435a" : "#2c6a72"
                            Label { anchors.centerIn: parent; text: "Scroll item " + (index + 1); color: "white"; font.pixelSize: 19 }
                        }
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.fillHeight: true
                background: Rectangle { color: "#202838"; radius: 24; border.color: "#44516a" }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Label { text: "3. Multitouch"; color: "white"; font.pixelSize: 25; font.bold: true }
                    Label { text: "Pinch the circle with two fingers"; color: "#b9c3d5"; font.pixelSize: 17 }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            id: pinchTarget
                            anchors.centerIn: parent
                            width: 170 * root.pinchScale
                            height: width
                            radius: width / 2
                            color: pinch.active ? "#ef8f52" : "#d96060"
                            border.width: 4
                            border.color: "white"
                            Label {
                                anchors.centerIn: parent
                                text: Math.round(root.pinchScale * 100) + "%"
                                color: "white"
                                font.pixelSize: 25
                                font.bold: true
                            }
                            PinchHandler {
                                id: pinch
                                minimumScale: 0.6
                                maximumScale: 1.8
                                onActiveScaleChanged: root.pinchScale = Math.max(0.6, Math.min(1.8, root.pinchScale * activeScale))
                                onActiveChanged: if (!active) scale = 1.0
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 74
            radius: 22
            color: "#283147"
            border.color: root.activeTouches > 0 ? "#71e3ad" : "#44516a"
            Label {
                anchors.centerIn: parent
                text: root.activeTouches > 0 ? "Touch detected — " + root.activeTouches + " contact(s)" : "4. Place several fingers here"
                color: "white"
                font.pixelSize: 21
                font.bold: true
            }
            MultiPointTouchArea {
                id: touchArea
                anchors.fill: parent
                minimumTouchPoints: 1
                maximumTouchPoints: 10
                onPressed: root.activeTouches = touchPoints.length
                onUpdated: root.activeTouches = touchPoints.length
                onReleased: root.activeTouches = touchPoints.length
                onCanceled: root.activeTouches = 0
            }
        }
    }
}
