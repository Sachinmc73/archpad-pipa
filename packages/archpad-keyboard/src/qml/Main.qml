import QtQuick
import QtQuick.Window as QtWindow
import QtQuick.Layouts
import org.kde.layershell as LayerShell
import "layouts"

QtWindow.Window {
    id: root
    visible: km.isVisible
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"

    readonly property bool isLandscape: Screen.width > Screen.height

    property real floatingX: Math.max(20, Screen.width - km.floatingWidth - 30)
    property real floatingY: 40
    property real quickPadX: Math.max(20, Screen.width - km.quickPadSize - 40)
    property real quickPadY: 60

    // Pure Overlay LayerShell configuration: Always LayerOverlay, zero struts, zero window/dock alteration
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.scope: "archpad-keyboard"
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    // Anchors switch between full-width docked bottom and floating/quickpad bottom-left offset
    LayerShell.Window.anchors: (km.isFloating || km.isQuickPad) ?
        (LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft) :
        (LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight)

    // Pure overlay: no exclusion zone (struts) under any circumstance
    LayerShell.Window.exclusionZone: -1

    LayerShell.Window.margins.left: km.isQuickPad ? Math.max(0, Math.min(Screen.width - root.width, quickPadX)) :
        (km.isFloating ? Math.max(0, Math.min(Screen.width - root.width, floatingX)) : 0)
    LayerShell.Window.margins.bottom: km.isQuickPad ? Math.max(0, Math.min(Screen.height - root.height, quickPadY)) :
        (km.isFloating ? Math.max(0, Math.min(Screen.height - root.height, floatingY)) : 0)

    // Width and height: QuickPad is square (km.quickPadSize); Floating is 10:7.6; Docked modes scale with heightScale
    width: km.isQuickPad ? km.quickPadSize : (km.isFloating ? km.floatingWidth : Screen.width)
    height: km.isQuickPad ? km.quickPadSize : (km.isFloating ? Math.round(km.floatingWidth * 0.76) :
            Math.round((isLandscape ? (km.splitMode ? 360 : 310) : 420) * km.heightScale))

    // Keyboard Main Surface Container
    Rectangle {
        id: surface
        anchors.fill: parent
        color: theme.backgroundColor
        border.color: theme.borderColor
        border.width: 1
        radius: (km.isFloating || km.isQuickPad) ? theme.cardRadius : 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: (km.isFloating || km.isQuickPad) ? 4 : 4
            spacing: 2

            // Top Header: Switch between Docked HeaderBar, Floating DragBar, and QuickPad DragBar
            Loader {
                Layout.fillWidth: true
                sourceComponent: km.isQuickPad ? quickPadBarComp : (km.isFloating ? floatingBarComp : dockedBarComp)
            }

            Component {
                id: dockedBarComp
                HeaderBar {
                    modeTitle: {
                        if (!root.isLandscape) return "ArchPad · Portrait Mode"
                        if (km.splitMode) return "ArchPad · Split Thumb Mode"
                        return "ArchPad · Laptop Mode"
                    }
                    onHideKeyboard: km.Hide()
                }
            }

            Component {
                id: floatingBarComp
                FloatingDragBar {
                    windowX: root.floatingX
                    windowY: root.floatingY
                    windowWidth: root.width
                    windowHeight: root.height
                    onDockBack: km.isFloating = false
                    onRequestMove: (newX, newY) => {
                        root.floatingX = newX
                        root.floatingY = newY
                    }
                    onRequestResize: (newWidth, newX) => {
                        km.floatingWidth = newWidth
                        root.floatingX = newX
                    }
                }
            }

            Component {
                id: quickPadBarComp
                QuickPadDragBar {
                    windowX: root.quickPadX
                    windowY: root.quickPadY
                    windowWidth: root.width
                    windowHeight: root.height
                    onDockBack: {
                        km.isQuickPad = false
                        km.isFloating = false
                    }
                    onRequestMove: (newX, newY) => {
                        root.quickPadX = newX
                        root.quickPadY = newY
                    }
                    onRequestResize: (newSize, newX) => {
                        km.quickPadSize = newSize
                        root.quickPadX = newX
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
                        if (km.isQuickPad) {
                            return quickPadLayoutComp
                        } else if (km.isFloating) {
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
                Component { id: quickPadLayoutComp; QuickPadLayout {} }
            }
        }
    }
}
