import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string text: ""
    property string secondaryText: ""
    property var customKeyColor: null
    property var customTextColor: null
    property real weight: 1.0
    property bool isAccent: false
    property bool autoRepeat: false
    property bool allowFlickSteal: false
    property bool triggerOnPress: true
    property int customFontSize: 0
    property string iconName: ""
    property bool swipeEnabled: false
    property var gestureTracker: null

    readonly property color finalKeyColor: customKeyColor !== null ? customKeyColor : theme.keyColor
    readonly property color finalTextColor: customTextColor !== null ? customTextColor : (root.isAccent ? "#FFFFFF" : theme.textColor)
    readonly property int autoFontSize: Math.max(11, Math.min(theme.fontSizeNormal, Math.round(parent.height * 0.38)))
    readonly property int finalFontSize: customFontSize > 0 ? customFontSize : autoFontSize
    readonly property bool effectiveTriggerOnPress: root.triggerOnPress && !root.swipeEnabled

    signal clicked()
    signal held()

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredWidth: weight * 100

    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.margins: theme.keyMargin
        radius: theme.keyRadius
        color: (touchArea.pressed && !touchArea.swipeTriggered) ? theme.keyPressedColor : (root.isAccent ? theme.keyAccentColor : root.finalKeyColor)
        border.color: theme.borderColor
        border.width: 1

        scale: (touchArea.pressed && !touchArea.swipeTriggered) ? 0.94 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
        }

        // Secondary / Superscript Symbol
        Text {
            visible: root.secondaryText !== ""
            text: root.secondaryText
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Math.max(2, Math.round(parent.height * 0.05))
            anchors.rightMargin: Math.max(3, Math.round(parent.width * 0.08))
            font.family: theme.fontFamily
            font.pixelSize: Math.max(8, Math.min(11, Math.round(parent.height * 0.22)))
            font.weight: Font.DemiBold
            color: theme.textSecondaryColor
        }

        // Main Key Label
        Text {
            visible: root.iconName === ""
            text: root.text
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.secondaryText !== "" ? Math.max(2, Math.round(parent.height * 0.08)) : 0
            anchors.horizontalCenterOffset: root.secondaryText !== "" ? -Math.max(1, Math.round(parent.width * 0.04)) : 0
            font.family: theme.fontFamily
            font.pixelSize: root.finalFontSize
            font.weight: Font.Normal
            color: root.finalTextColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // Vector Icon (for pixel-perfect symbol sizing)
        VectorIcon {
            visible: root.iconName !== ""
            name: root.iconName
            anchors.centerIn: parent
            width: Math.max(14, Math.min(18, Math.round(parent.height * 0.38)))
            height: width
            color: root.finalTextColor
        }

        MouseArea {
            id: touchArea
            anchors.fill: parent
            preventStealing: !root.allowFlickSteal
            pressAndHoldInterval: km.longPressDelay

            property bool longPressed: false
            property bool autoRepeatTriggered: false
            property bool swipeTriggered: false
            property real startGlobalX: 0
            property real startGlobalY: 0

            // Lightweight auto-repeat timer for Backspace / Space
            Timer {
                id: repeatTimer
                interval: 380
                repeat: true
                running: root.autoRepeat && touchArea.pressed
                onTriggered: {
                    interval = 50
                    touchArea.autoRepeatTriggered = true
                    root.clicked()
                }
            }

            onPressAndHold: {
                if (touchArea.swipeTriggered) return
                if (root.secondaryText !== "") {
                    touchArea.longPressed = true
                    root.held()
                }
            }

            onPressed: function(mouse) {
                touchArea.longPressed = false
                touchArea.autoRepeatTriggered = false
                touchArea.swipeTriggered = false

                if (root.swipeEnabled && root.gestureTracker) {
                    var gPt = root.gestureTracker.mapPoint(root, mouse.x, mouse.y)
                    touchArea.startGlobalX = gPt.x
                    touchArea.startGlobalY = gPt.y
                }

                if (root.autoRepeat) {
                    repeatTimer.interval = 380
                    if (root.effectiveTriggerOnPress) {
                        root.clicked()
                    }
                } else if (root.secondaryText === "" && root.effectiveTriggerOnPress) {
                    root.clicked()
                }
            }

            onPositionChanged: function(mouse) {
                if (!root.swipeEnabled || !root.gestureTracker) return

                var gPt = root.gestureTracker.mapPoint(root, mouse.x, mouse.y)
                var dx = gPt.x - touchArea.startGlobalX
                var dy = gPt.y - touchArea.startGlobalY
                var distSq = dx * dx + dy * dy

                if (!touchArea.swipeTriggered) {
                    // 14px touch slop threshold (14*14 = 196)
                    if (distSq >= 196) {
                        touchArea.swipeTriggered = true
                        touchArea.longPressed = false
                        root.gestureTracker.startSwipe(touchArea.startGlobalX, touchArea.startGlobalY)
                        root.gestureTracker.addPoint(gPt.x, gPt.y)
                    }
                } else {
                    root.gestureTracker.addPoint(gPt.x, gPt.y)
                }
            }

            onClicked: {
                if (touchArea.swipeTriggered) {
                    touchArea.swipeTriggered = false
                    touchArea.longPressed = false
                    return
                }
                if (root.secondaryText !== "" && !touchArea.longPressed && !root.autoRepeat) {
                    root.clicked()
                } else if (!root.effectiveTriggerOnPress && !touchArea.longPressed && !touchArea.autoRepeatTriggered) {
                    root.clicked()
                }
                touchArea.longPressed = false
            }

            onReleased: {
                if (touchArea.swipeTriggered) {
                    root.gestureTracker.finishSwipe()
                }
                if (root.autoRepeat) {
                    repeatTimer.stop()
                    repeatTimer.interval = 380
                }
            }

            onCanceled: {
                if (touchArea.swipeTriggered) {
                    root.gestureTracker.cancelSwipe()
                    touchArea.swipeTriggered = false
                }
                if (root.autoRepeat) {
                    repeatTimer.stop()
                    repeatTimer.interval = 380
                }
                touchArea.longPressed = false
            }
        }
    }
}
