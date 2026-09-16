import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int configRevision: 0

    Connections {
        target: km
        function onQuickPadConfigChanged() { root.configRevision++ }
        function onQuickPadKeyCountChanged() { root.configRevision++ }
    }

    component QuickPadButton: Item {
        id: qBtn
        property int slotIndex: 0
        property string labelText: {
            let _ = root.configRevision
            return km.quickPadLabel(slotIndex)
        }

        Layout.fillWidth: true
        Layout.fillHeight: true

        Rectangle {
            id: bg
            anchors.fill: parent
            anchors.margins: theme.keyMargin
            radius: theme.keyRadius
            color: touchArea.pressed ? theme.keyPressedColor : theme.keyColor
            border.color: theme.borderColor
            border.width: 1

            scale: touchArea.pressed ? 0.95 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 12
                text: qBtn.labelText
                font.family: theme.fontFamily
                font.pixelSize: {
                    let base = Math.min(22, Math.round(parent.height * 0.32))
                    if (text.length > 5) base = Math.max(11, Math.round(base * 0.8))
                    return Math.max(12, base)
                }
                font.weight: Font.DemiBold
                color: theme.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }

            MouseArea {
                id: touchArea
                anchors.fill: parent
                preventStealing: true
                onClicked: {
                    km.tapQuickPadKey(qBtn.slotIndex)
                }
            }
        }
    }

    // 1 Key: Single full-size key
    ColumnLayout {
        anchors.fill: parent
        spacing: 2
        visible: km.quickPadKeyCount === 1

        QuickPadButton { slotIndex: 0 }
    }

    // 2 Keys: Two equal horizontal rows (stacked top and bottom)
    ColumnLayout {
        anchors.fill: parent
        spacing: 2
        visible: km.quickPadKeyCount === 2

        QuickPadButton { slotIndex: 0 }
        QuickPadButton { slotIndex: 1 }
    }

    // 3 Keys: Three equal horizontal rows (stacked top, middle, bottom)
    ColumnLayout {
        anchors.fill: parent
        spacing: 2
        visible: km.quickPadKeyCount === 3

        QuickPadButton { slotIndex: 0 }
        QuickPadButton { slotIndex: 1 }
        QuickPadButton { slotIndex: 2 }
    }

    // 4 Keys: 2x2 grid (4 equal quadrants)
    ColumnLayout {
        anchors.fill: parent
        spacing: 2
        visible: km.quickPadKeyCount === 4

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            QuickPadButton { slotIndex: 0 }
            QuickPadButton { slotIndex: 1 }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            QuickPadButton { slotIndex: 2 }
            QuickPadButton { slotIndex: 3 }
        }
    }
}
