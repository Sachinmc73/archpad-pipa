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

    signal dockBack()
    signal dragMoved(real deltaX, real deltaY)
    signal resizeMoved(real deltaX, real startWidth)

    // 1. Top-Left: Resize Handle
    Rectangle {
        id: resizeBtn
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 26
        radius: theme.keyRadius
        color: resizeArea.pressed ? theme.keyPressedColor : "transparent"
        border.color: theme.borderColor
        border.width: 1

        VectorIcon {
            name: "resize-corner"
            anchors.centerIn: parent
            width: 14
            height: 14
            color: resizeArea.pressed ? theme.keyActiveColor : theme.textSecondaryColor
            strokeWidth: 1.8
        }

        MouseArea {
            id: resizeArea
            anchors.fill: parent
            preventStealing: true

            property real startX: 0
            property real startWidth: 400

            onPressed: (mouse) => {
                startX = mouse.x
                startWidth = km.floatingWidth
            }

            onPositionChanged: (mouse) => {
                if (pressed) {
                    let dx = mouse.x - startX
                    root.resizeMoved(dx, startWidth)
                }
            }
        }
    }

    // 2. Exactly in the middle: Centered Drag Handle Grip
    Item {
        anchors.centerIn: parent
        width: 120
        height: parent.height

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

    // 3. Right: Pop Back Icon (180° rotated popup trigger icon) + Minimise Icon
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Pop Back Button (180 degree rotated floating icon)
        Rectangle {
            id: dockBtn
            width: 32
            height: 26
            radius: theme.keyRadius
            color: dockArea.pressed ? theme.keyPressedColor : "transparent"
            border.color: theme.borderColor
            border.width: 1

            VectorIcon {
                name: "floating"
                rotation: 180
                anchors.centerIn: parent
                width: 15
                height: 15
                color: theme.keyActiveColor
                strokeWidth: 1.8
            }

            MouseArea {
                id: dockArea
                anchors.fill: parent
                onClicked: root.dockBack()
            }
        }

        // Minimise Icon (Rightmost)
        Rectangle {
            id: hideBtn
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
