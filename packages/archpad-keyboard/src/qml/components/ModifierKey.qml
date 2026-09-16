import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string text: ""
    property bool active: false
    property bool isLocked: false
    property real weight: 1.0
    property bool allowFlickSteal: false
    property int customFontSize: 0

    readonly property int autoFontSize: Math.max(11, Math.min(theme.fontSizeNormal, Math.round(parent.height * 0.36)))
    readonly property int finalFontSize: customFontSize > 0 ? customFontSize : autoFontSize

    signal clicked()

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredWidth: weight * 100

    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.margins: theme.keyMargin
        radius: theme.keyRadius
        color: root.active ? theme.keyActiveColor : (touchArea.pressed ? theme.keyPressedColor : theme.keySpecialColor)
        border.color: root.active ? Qt.lighter(theme.keyActiveColor, 1.2) : theme.borderColor
        border.width: root.active ? 1.5 : 1

        scale: touchArea.pressed ? 0.94 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
        }

        // Active indicator dot for locked state (like CapsLock)
        Rectangle {
            visible: root.isLocked
            width: 6
            height: 6
            radius: 3
            color: "#00FF66"
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6
        }

        Text {
            text: root.text
            anchors.centerIn: parent
            font.family: theme.fontFamily
            font.pixelSize: root.finalFontSize
            font.weight: root.active ? Font.DemiBold : Font.Normal
            color: root.active ? theme.textActiveColor : theme.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: touchArea
            anchors.fill: parent
            preventStealing: !root.allowFlickSteal
            onClicked: {
                km.playClick()
                root.clicked()
            }
        }
    }
}
