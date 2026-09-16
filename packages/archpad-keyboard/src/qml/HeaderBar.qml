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

    property string modeTitle: "ArchPad Keyboard"
    readonly property bool isLandscape: Screen.width > Screen.height

    signal hideKeyboard()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 6

        // Mode / Brand indicator
        RowLayout {
            spacing: 6
            Rectangle {
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: theme.keyActiveColor
            }
            Text {
                text: root.modeTitle
                font.family: theme.fontFamily
                font.pixelSize: theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: theme.textSecondaryColor
            }
        }

        Item { Layout.fillWidth: true }

        // Action Toolbar: Fixed 34x26 native icon buttons

        // 1. Pop-up / Floating Mode (Always Pinned)
        Rectangle {
            id: floatBtn
            implicitWidth: 34
            implicitHeight: 26
            radius: theme.keyRadius
            color: floatArea.pressed ? theme.keyPressedColor : "transparent"
            border.color: theme.borderColor
            border.width: 1

            VectorIcon {
                name: "floating"
                anchors.centerIn: parent
                width: 16
                height: 16
                color: theme.textColor
                strokeWidth: 1.8
            }

            MouseArea {
                id: floatArea
                anchors.fill: parent
                onClicked: km.isFloating = true
            }
        }

        // QuickPad Launcher (Visible when pinned)
        Rectangle {
            id: quickPadBtn
            visible: km.quickPadPinned
            implicitWidth: 34
            implicitHeight: 26
            radius: theme.keyRadius
            color: quickPadArea.pressed ? theme.keyPressedColor : "transparent"
            border.color: theme.borderColor
            border.width: 1

            VectorIcon {
                name: "quickpad"
                anchors.centerIn: parent
                width: 16
                height: 16
                color: theme.textColor
                strokeWidth: 1.8
            }

            MouseArea {
                id: quickPadArea
                anchors.fill: parent
                onClicked: km.isQuickPad = true
            }
        }

        // 2. Split Mode Toggle (Only visible if pinned AND in Landscape mode)
        Rectangle {
            id: splitBtn
            visible: km.splitPinned && root.isLandscape
            implicitWidth: 34
            implicitHeight: 26
            radius: theme.keyRadius
            color: km.splitMode ? theme.keyActiveColor : (splitArea.pressed ? theme.keyPressedColor : "transparent")
            border.color: km.splitMode ? theme.keyActiveColor : theme.borderColor
            border.width: 1

            VectorIcon {
                name: "split"
                anchors.centerIn: parent
                width: 16
                height: 16
                color: km.splitMode ? "#FFFFFF" : theme.textSecondaryColor
                strokeWidth: 1.8
            }

            MouseArea {
                id: splitArea
                anchors.fill: parent
                onClicked: km.splitMode = !km.splitMode
            }
        }

        // 3. Theme Mode Switcher (Only visible if pinned)
        Rectangle {
            id: themeBtn
            visible: km.themePinned
            implicitWidth: 34
            implicitHeight: 26
            radius: theme.keyRadius
            color: themeArea.pressed ? theme.keyPressedColor : "transparent"
            border.color: theme.borderColor
            border.width: 1

            VectorIcon {
                name: km.themeMode === 0 ? "theme-system" : (km.themeMode === 1 ? "sun" : "moon")
                anchors.centerIn: parent
                width: 16
                height: 16
                color: theme.textColor
                strokeWidth: 1.8
            }

            MouseArea {
                id: themeArea
                anchors.fill: parent
                onClicked: km.cycleThemeMode()
            }
        }

        // 4. Audio Click Feedback (Only visible if pinned)
        Rectangle {
            id: soundBtn
            visible: km.soundPinned
            implicitWidth: 34
            implicitHeight: 26
            radius: theme.keyRadius
            color: soundArea.pressed ? theme.keyPressedColor : "transparent"
            border.color: theme.borderColor
            border.width: 1

            VectorIcon {
                name: km.soundEnabled ? "volume-on" : "volume-off"
                anchors.centerIn: parent
                width: 16
                height: 16
                color: km.soundEnabled ? theme.textColor : theme.textSecondaryColor
                strokeWidth: 1.8
            }

            MouseArea {
                id: soundArea
                anchors.fill: parent
                onClicked: km.soundEnabled = !km.soundEnabled
            }
        }

        // 5. Settings Gear Icon (Always Pinned)
        Rectangle {
            id: gearBtn
            implicitWidth: 34
            implicitHeight: 26
            radius: theme.keyRadius
            color: gearArea.pressed ? theme.keyPressedColor : "transparent"
            border.color: theme.borderColor
            border.width: 1

            VectorIcon {
                name: "settings"
                anchors.centerIn: parent
                width: 16
                height: 16
                color: theme.textColor
                strokeWidth: 1.8
            }

            MouseArea {
                id: gearArea
                anchors.fill: parent
                onClicked: km.openSettingsApp()
            }
        }

        // 6. Hide Keyboard Button (Always Pinned)
        Rectangle {
            id: hideBtn
            implicitWidth: 34
            implicitHeight: 26
            radius: theme.keyRadius
            color: hideArea.pressed ? theme.keyPressedColor : "transparent"
            border.color: theme.borderColor
            border.width: 1

            VectorIcon {
                name: "hide"
                anchors.centerIn: parent
                width: 16
                height: 16
                color: theme.textSecondaryColor
                strokeWidth: 2.0
            }

            MouseArea {
                id: hideArea
                anchors.fill: parent
                onClicked: root.hideKeyboard()
            }
        }
    }
}
