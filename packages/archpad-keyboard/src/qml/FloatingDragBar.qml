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

    property real windowX: 0
    property real windowY: 0
    property real windowWidth: 0
    property real windowHeight: 0

    signal dockBack()
    signal requestMove(real newX, real newY)
    signal requestResize(real newWidth, real newX)

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

            property real pinnedRight: 0
            property real grabOffsetX: 0

            onPressed: (mouse) => {
                let p = mapToItem(null, mouse.x, mouse.y)
                pinnedRight = root.windowX + root.windowWidth
                grabOffsetX = p.x
            }

            onPositionChanged: (mouse) => {
                if (pressed) {
                    let p = mapToItem(null, mouse.x, mouse.y)
                    let errX = p.x - grabOffsetX

                    // Damped proportional tracking (alpha = 0.50):
                    // Prevents buffer allocation thrashing and limit-cycle oscillation
                    const alpha = 0.50
                    let targetW = root.windowWidth - (errX * alpha)

                    const minW = 340.0
                    const maxW = Math.min(580.0, Screen.width - 20)
                    let clampedW = Math.max(minW, Math.min(maxW, targetW))
                    let clampedX = pinnedRight - clampedW

                    if (clampedX < 10) {
                        clampedX = 10
                        clampedW = Math.max(minW, Math.min(maxW, pinnedRight - 10))
                    }
                    root.requestResize(clampedW, clampedX)
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

            property real grabOffsetX: 0
            property real grabOffsetY: 0

            onPressed: (mouse) => {
                let p = mapToItem(null, mouse.x, mouse.y)
                grabOffsetX = p.x
                grabOffsetY = root.windowHeight - p.y
            }

            onPositionChanged: (mouse) => {
                if (pressed) {
                    let p = mapToItem(null, mouse.x, mouse.y)
                    let errX = p.x - grabOffsetX
                    let errY = (root.windowHeight - p.y) - grabOffsetY

                    // Critically damped proportional tracking (alpha = 0.55):
                    // Places the discrete closed-loop pole at z = 1 - alpha = +0.45.
                    // Strictly positive real pole guarantees zero oscillation and smooth glide.
                    const alpha = 0.55
                    let targetX = root.windowX + (errX * alpha)
                    let targetBottom = root.windowY + (errY * alpha)

                    let clampedX = Math.max(10, Math.min(Screen.width - root.windowWidth - 10, targetX))
                    let clampedY = Math.max(10, Math.min(Screen.height - root.windowHeight - 10, targetBottom))

                    root.requestMove(clampedX, clampedY)
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
