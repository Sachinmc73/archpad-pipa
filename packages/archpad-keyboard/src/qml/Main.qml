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

    // Pure Overlay LayerShell configuration: Always LayerOverlay, zero struts, zero window/dock alteration
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.scope: "archpad-keyboard"
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    // Anchors switch between full-width docked bottom and floating bottom-left offset
    LayerShell.Window.anchors: km.isFloating ?
        (LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft) :
        (LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight)

    // Pure overlay: no exclusion zone (struts) under any circumstance
    LayerShell.Window.exclusionZone: -1

    LayerShell.Window.margins.left: km.isFloating ? Math.max(0, Math.min(Screen.width - root.width, floatingX)) : 0
    LayerShell.Window.margins.bottom: km.isFloating ? Math.max(0, Math.min(Screen.height - root.height, floatingY)) : 0

    // Width and height: Docked modes scale with km.heightScale; Popup mode uses locked 10:7 aspect ratio
    width: km.isFloating ? km.floatingWidth : Screen.width
    height: km.isFloating ? Math.round(km.floatingWidth * 0.76) :
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
                    onDockBack: km.isFloating = false
                    onDragMoved: (dx, dy) => {
                        root.floatingX += dx
                        root.floatingY -= dy
                    }
                    onResizeMoved: (dx, startWidth) => {
                        let newW = Math.max(280, Math.min(560, startWidth - dx))
                        let deltaW = newW - km.floatingWidth
                        if (Math.abs(deltaW) >= 1) {
                            km.floatingWidth = newW
                            root.floatingX -= deltaW
                        }
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
