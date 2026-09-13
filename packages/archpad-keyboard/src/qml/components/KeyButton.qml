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
    property int customFontSize: 0
    property string iconName: ""

    readonly property color finalKeyColor: customKeyColor !== null ? customKeyColor : theme.keyColor
    readonly property color finalTextColor: customTextColor !== null ? customTextColor : (root.isAccent ? "#FFFFFF" : theme.textColor)
    readonly property int autoFontSize: Math.max(11, Math.min(theme.fontSizeNormal, Math.round(parent.height * 0.38)))
    readonly property int finalFontSize: customFontSize > 0 ? customFontSize : autoFontSize

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
        color: touchArea.pressed ? theme.keyPressedColor : (root.isAccent ? theme.keyAccentColor : root.finalKeyColor)
        border.color: theme.borderColor
        border.width: 1

        scale: touchArea.pressed ? 0.94 : 1.0
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
            preventStealing: true
            pressAndHoldInterval: 400

            property bool longPressed: false

            // Lightweight auto-repeat timer for Backspace / Space
            Timer {
                id: repeatTimer
                interval: 380
                repeat: true
                running: root.autoRepeat && touchArea.pressed
                onTriggered: {
                    interval = 50
                    root.clicked()
                }
            }

            onPressAndHold: {
                if (root.secondaryText !== "") {
                    touchArea.longPressed = true
                    root.held()
                }
            }

            onPressed: {
                touchArea.longPressed = false
                if (root.autoRepeat) {
                    repeatTimer.interval = 380
                    root.clicked()
                } else if (root.secondaryText === "") {
                    root.clicked()
                }
            }

            onClicked: {
                if (root.secondaryText !== "" && !touchArea.longPressed && !root.autoRepeat) {
                    root.clicked()
                }
                touchArea.longPressed = false
            }

            onReleased: {
                if (root.autoRepeat) {
                    repeatTimer.stop()
                    repeatTimer.interval = 380
                }
            }

            onCanceled: {
                if (root.autoRepeat) {
                    repeatTimer.stop()
                    repeatTimer.interval = 380
                }
                touchArea.longPressed = false
            }
        }
    }
}
