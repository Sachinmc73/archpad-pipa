import QtQuick
import QtQuick.Layouts
import "components"

Rectangle {
    id: root
    height: theme.headerHeight
    color: theme.headerColor
    border.color: theme.borderColor
    border.width: 1
    radius: theme.keyRadius

    signal toggleOptions()
    signal dockBack()
    signal dragMoved(real deltaX, real deltaY)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 6

        // Centered Drag Handle Grip (Zero text, perfectly centered)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.centerIn: parent
                width: 48
                height: 4
                radius: 2
                color: theme.textSecondaryColor
                opacity: dragArea.pressed ? 0.9 : 0.45
                Behavior on opacity {
                    NumberAnimation { duration: 80 }
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                preventStealing: true

                property real lastX: 0
                property real lastY: 0

                onPressed: (mouse) => {
                    lastX = mouse.x
                    lastY = mouse.y
                }

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        let dx = mouse.x - lastX
                        let dy = mouse.y - lastY
                        root.dragMoved(dx, dy)
                    }
                }
            }
        }

        // Dock Back to Bottom Button (Native Dock-Bottom Vector Icon)
        Rectangle {
            width: 32
            height: 26
            radius: theme.keyRadius
            color: dockArea.pressed ? theme.keyPressedColor : "transparent"
            border.color: theme.borderColor
            border.width: 1

            VectorIcon {
                name: "dock-bottom"
                anchors.centerIn: parent
                width: 15
                height: 15
                color: theme.keyActiveColor
                strokeWidth: 2.0
            }

            MouseArea {
                id: dockArea
                anchors.fill: parent
                onClicked: root.dockBack()
            }
        }

        // Audio Click Toggle (Native Volume Vector Icon)
        Rectangle {
            width: 32
            height: 26
            radius: theme.keyRadius
            color: soundArea.pressed ? theme.keyPressedColor : "transparent"
            border.color: theme.borderColor
            border.width: 1

            VectorIcon {
                name: km.soundEnabled ? "volume-on" : "volume-off"
                anchors.centerIn: parent
                width: 15
                height: 15
                color: km.soundEnabled ? theme.textColor : theme.textSecondaryColor
                strokeWidth: 1.8
            }

            MouseArea {
                id: soundArea
                anchors.fill: parent
                onClicked: km.soundEnabled = !km.soundEnabled
            }
        }

        // Hide Keyboard Button (Native Chevron-Down Vector Icon)
        Rectangle {
            width: 32
            height: 26
            radius: theme.keyRadius
            color: hideArea.pressed ? theme.keyPressedColor : "transparent"
            border.color: theme.borderColor
            border.width: 1

            VectorIcon {
                name: "hide"
                anchors.centerIn: parent
                width: 15
                height: 15
                color: theme.textSecondaryColor
                strokeWidth: 2.0
            }

            MouseArea {
                id: hideArea
                anchors.fill: parent
                onClicked: km.isVisible = false
            }
        }
    }
}
