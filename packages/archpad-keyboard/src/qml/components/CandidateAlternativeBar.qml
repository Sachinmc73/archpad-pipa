import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitHeight: 32

    RowLayout {
        anchors.fill: parent
        anchors.margins: 1
        spacing: 6

        // Alternatives Pills
        Repeater {
            model: km.swipeAlternatives

            Rectangle {
                id: pill
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: theme.keyRadius
                color: pillArea.pressed ? theme.keyPressedColor : theme.keyColor
                border.color: theme.borderColor
                border.width: 1

                scale: pillArea.pressed ? 0.95 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: Math.max(12, Math.min(theme.fontSizeNormal, Math.round(parent.height * 0.44)))
                    font.weight: Font.DemiBold
                    color: theme.textColor
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: pillArea
                    anchors.fill: parent
                    onClicked: km.selectSwipeAlternative(index)
                }
            }
        }

        // Dismiss Button ("✕")
        Rectangle {
            id: dismissBtn
            implicitWidth: 32
            Layout.fillHeight: true
            radius: theme.keyRadius
            color: dismissArea.pressed ? theme.keyPressedColor : "transparent"
            border.color: theme.borderColor
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 13
                color: theme.textSecondaryColor
            }

            MouseArea {
                id: dismissArea
                anchors.fill: parent
                onClicked: km.dismissSwipeAlternatives()
            }
        }
    }
}
