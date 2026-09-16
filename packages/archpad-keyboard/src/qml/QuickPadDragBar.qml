import QtQuick
import QtQuick.Layouts
import "components"

Rectangle {
    id: root
    height: Math.min(30, theme.headerHeight)
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
    signal requestResize(real newSize, real newX)

    // 1. Top-Left: Resize Handle (Locked 1:1 Aspect Ratio)
    Rectangle {
        id: resizeBtn
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 22
        radius: theme.keyRadius
        color: resizeArea.pressed ? theme.keyPressedColor : "transparent"
        border.color: theme.borderColor
        border.width: 1

        VectorIcon {
            name: "resize-corner"
            anchors.centerIn: parent
            width: 12
            height: 12
            color: resizeArea.pressed ? theme.keyActiveColor : theme.textSecondaryColor
            strokeWidth: 1.6
        }

        MouseArea {
            id: resizeArea
            anchors.fill: parent
            preventStealing: true

            property real pinnedRight: 0
            property real grabOffsetX: 0
            property double lastTime: 0

            onPressed: (mouse) => {
                let p = mapToItem(null, mouse.x, mouse.y)
                pinnedRight = root.windowX + root.windowWidth
                grabOffsetX = p.x
                lastTime = Date.now()
            }

            onPositionChanged: (mouse) => {
                if (pressed) {
                    let now = Date.now()
                    let dt = Math.min(0.050, Math.max(0.001, (now - lastTime) / 1000.0))
                    lastTime = now

                    let p = mapToItem(null, mouse.x, mouse.y)
                    let errX = p.x - grabOffsetX

                    // Deadband filter: suppress sub-pixel capacitive sensor noise
                    if (Math.abs(errX) < 0.5) {
                        errX = 0
                    }

                    // Continuous time-delta exponential damping:
                    // alpha(dt) = 1.0 - exp(-lambda * dt) with lambda = 80 s^-1
                    const lambda = 80.0
                    const alpha = 1.0 - Math.exp(-lambda * dt)
                    let targetSize = root.windowWidth - (errX * alpha)

                    const minSize = 160.0
                    const maxSize = Math.min(380.0, Screen.width - 20, Screen.height - root.windowY - 10)
                    let clampedSize = Math.max(minSize, Math.min(maxSize, targetSize))
                    let clampedX = pinnedRight - clampedSize

                    if (clampedX < 10) {
                        clampedX = 10
                        clampedSize = Math.max(minSize, Math.min(maxSize, pinnedRight - 10))
                    }
                    root.requestResize(clampedSize, clampedX)
                }
            }
        }
    }

    // 2. Center: Drag Handle Grip
    Item {
        anchors.centerIn: parent
        width: 70
        height: parent.height

        Rectangle {
            anchors.centerIn: parent
            width: 32
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
            property double lastTime: 0

            onPressed: (mouse) => {
                let p = mapToItem(null, mouse.x, mouse.y)
                grabOffsetX = p.x
                grabOffsetY = root.windowHeight - p.y
                lastTime = Date.now()
            }

            onPositionChanged: (mouse) => {
                if (pressed) {
                    let now = Date.now()
                    let dt = Math.min(0.050, Math.max(0.001, (now - lastTime) / 1000.0))
                    lastTime = now

                    let p = mapToItem(null, mouse.x, mouse.y)
                    let errX = p.x - grabOffsetX
                    let errY = (root.windowHeight - p.y) - grabOffsetY

                    if (Math.abs(errX) < 0.5) errX = 0
                    if (Math.abs(errY) < 0.5) errY = 0

                    const lambda = 96.0
                    const alpha = 1.0 - Math.exp(-lambda * dt)

                    let targetX = root.windowX + (errX * alpha)
                    let targetBottom = root.windowY + (errY * alpha)

                    let clampedX = Math.max(10, Math.min(Screen.width - root.windowWidth - 10, targetX))
                    let clampedY = Math.max(10, Math.min(Screen.height - root.windowHeight - 10, targetBottom))

                    root.requestMove(clampedX, clampedY)
                }
            }
        }
    }

    // 3. Right: Dock Back & Close Buttons
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        // Expand / Dock back to full keyboard
        Rectangle {
            id: dockBtn
            implicitWidth: 28
            implicitHeight: 22
            radius: theme.keyRadius
            color: dockArea.pressed ? theme.keyPressedColor : "transparent"
            border.color: theme.borderColor
            border.width: 1

            VectorIcon {
                name: "floating"
                rotation: 180
                anchors.centerIn: parent
                width: 13
                height: 13
                color: theme.keyActiveColor
                strokeWidth: 1.6
            }

            MouseArea {
                id: dockArea
                anchors.fill: parent
                onClicked: root.dockBack()
            }
        }

        // Close / Dismiss
        Rectangle {
            id: hideBtn
            implicitWidth: 28
            implicitHeight: 22
            radius: theme.keyRadius
            color: hideArea.pressed ? theme.keyPressedColor : "transparent"
            border.color: theme.borderColor
            border.width: 1

            VectorIcon {
                name: "close"
                anchors.centerIn: parent
                width: 13
                height: 13
                color: theme.textSecondaryColor
                strokeWidth: 1.8
            }

            MouseArea {
                id: hideArea
                anchors.fill: parent
                onClicked: km.Hide()
            }
        }
    }
}
