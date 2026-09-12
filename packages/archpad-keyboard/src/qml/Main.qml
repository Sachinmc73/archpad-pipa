import QtQuick
import QtQuick.Window as QtWindow
import QtQuick.Layouts
import org.kde.layershell as LayerShell
import "layouts"
import "components"

QtWindow.Window {
    id: root
    visible: km.isVisible
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"

    readonly property bool isLandscape: Screen.width > Screen.height

    property real floatingX: Math.max(20, Screen.width - km.floatingWidth - 30)
    property real floatingY: 40

    // Dynamic LayerShell configuration
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.scope: "archpad-keyboard"
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    // Anchors switch between full-width docked bottom and floating bottom-left offset
    LayerShell.Window.anchors: km.isFloating ?
        (LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft) :
        (LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight)

    // Window pushing: only on-demand when km.pushWindows is enabled (default: -1 = cover dock completely at screen bottom)
    LayerShell.Window.exclusionZone: (km.pushWindows && !km.isFloating) ? root.height : -1

    LayerShell.Window.margins.left: km.isFloating ? Math.max(0, Math.min(Screen.width - root.width, floatingX)) : 0
    LayerShell.Window.margins.bottom: km.isFloating ? Math.max(0, Math.min(Screen.height - root.height, floatingY)) : 0

    // Width and height: Docked modes scale with km.heightScale; Popup mode uses locked 10:7 aspect ratio
    width: km.isFloating ? km.floatingWidth : Screen.width
    height: km.isFloating ? Math.round(km.floatingWidth / 1.42857) :
            Math.round((isLandscape ? (km.splitMode ? 360 : 310) : 420) * km.heightScale)

    // Keyboard Main Surface Container
    Rectangle {
        id: surface
        anchors.fill: parent
        color: theme.backgroundColor
        border.color: theme.borderColor
        border.width: 1
        radius: km.isFloating ? theme.cardRadius : 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: km.isFloating ? 4 : 4
            spacing: 2

            // Top Header: Switch between Docked HeaderBar and Floating DragBar
            Loader {
                Layout.fillWidth: true
                sourceComponent: km.isFloating ? floatingBarComp : dockedBarComp
            }

            Component {
                id: dockedBarComp
                HeaderBar {
                    modeTitle: {
                        if (!root.isLandscape) return "ArchPad · Portrait Mode"
                        if (km.splitMode) return "ArchPad · Split Thumb Mode"
                        return "ArchPad · Laptop Mode"
                    }
                    onToggleOptions: km.optionsVisible = !km.optionsVisible
                    onHideKeyboard: km.isVisible = false
                }
            }

            Component {
                id: floatingBarComp
                FloatingDragBar {
                    onToggleOptions: km.optionsVisible = !km.optionsVisible
                    onDockBack: km.isFloating = false
                    onDragMoved: (dx, dy) => {
                        root.floatingX += dx
                        root.floatingY -= dy
                    }
                }
            }

            // Keyboard Layout Area
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Loader {
                    id: layoutLoader
                    anchors.fill: parent
                    sourceComponent: {
                        if (km.isFloating) {
                            return floatingLayoutComp
                        } else if (root.isLandscape && km.splitMode) {
                            return splitLayoutComp
                        } else if (root.isLandscape) {
                            return landscapeLayoutComp
                        } else {
                            return portraitLayoutComp
                        }
                    }
                }

                Component { id: landscapeLayoutComp; LandscapeLaptop {} }
                Component { id: portraitLayoutComp; PortraitDualBar {} }
                Component { id: splitLayoutComp; LandscapeSplit {} }
                Component { id: floatingLayoutComp; FloatingMobile {} }
            }
        }

        // Interactive Top-Left Corner Resize Handle in Pop-up Mode (Locked Aspect Ratio)
        Rectangle {
            id: resizeHandle
            visible: km.isFloating
            width: 24
            height: 24
            anchors.top: parent.top
            anchors.left: parent.left
            color: "transparent"
            z: 100

            VectorIcon {
                name: "resize-corner"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 4
                width: 14
                height: 14
                color: resizeArea.pressed ? theme.keyActiveColor : theme.textDimColor
                strokeWidth: 2.0
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
                        let newW = Math.max(280, Math.min(560, startWidth - dx))
                        let deltaW = newW - km.floatingWidth
                        if (Math.abs(deltaW) >= 1) {
                            km.floatingWidth = newW
                            root.floatingX -= deltaW
                        }
                    }
                }
            }
        }

        // Modular Options Drawer Overlay
        OptionsDrawer {
            id: optionsDrawer
            anchors.fill: parent
            anchors.margins: 8
            visible: opacity > 0
            opacity: km.optionsVisible ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            onClose: km.optionsVisible = false
        }
    }
}
