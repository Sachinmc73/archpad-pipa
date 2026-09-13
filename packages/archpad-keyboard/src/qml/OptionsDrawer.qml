import QtQuick
import QtQuick.Layouts
import "components"

Rectangle {
    id: root
    color: theme.surfaceColor
    border.color: theme.borderColor
    border.width: 1
    radius: theme.cardRadius

    readonly property bool isLandscape: Screen.width > Screen.height
    signal close()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Drawer Header
        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                spacing: 6
                VectorIcon {
                    name: "settings"
                    width: 18
                    height: 18
                    color: theme.textColor
                }
                Text {
                    text: "Keyboard Features & Settings"
                    font.family: theme.fontFamily
                    font.pixelSize: theme.fontSizeHeader
                    font.weight: Font.DemiBold
                    color: theme.textColor
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Tap 📌 to pin any setting to the topbar"
                font.family: theme.fontFamily
                font.pixelSize: 11
                color: theme.textSecondaryColor
            }

            Item { width: 8 }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: closeArea.pressed ? theme.keyPressedColor : "transparent"

                VectorIcon {
                    name: "close"
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    color: theme.textSecondaryColor
                    strokeWidth: 2.0
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    onClicked: root.close()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.dividerColor
        }

        // 5 Feature Cards Grid
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.width > 500 ? 3 : 2
            rowSpacing: 8
            columnSpacing: 8

            // 1. Pop-up / Floating Mode (Always Pinned)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: theme.keyRadius
                color: km.isFloating ? Qt.darker(theme.keyActiveColor, 2.0) : (cardFloatArea.pressed ? theme.keyPressedColor : theme.keyColor)
                border.color: km.isFloating ? theme.keyActiveColor : theme.borderColor
                border.width: 1

                MouseArea {
                    id: cardFloatArea
                    anchors.fill: parent
                    onClicked: {
                        km.isFloating = !km.isFloating
                        root.close()
                    }
                }

                // Permanent Pin Badge
                RowLayout {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 7
                    spacing: 3
                    VectorIcon {
                        name: "pin"
                        width: 10
                        height: 10
                        color: theme.textDimColor
                        strokeWidth: 1.5
                    }
                    Text {
                        text: "Always Pinned"
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        color: theme.textDimColor
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    VectorIcon {
                        name: "floating"
                        Layout.alignment: Qt.AlignHCenter
                        width: 22
                        height: 22
                        color: km.isFloating ? theme.keyActiveColor : theme.textColor
                        strokeWidth: 1.8
                    }
                    Text {
                        text: "Floating Mode"
                        font.family: theme.fontFamily
                        font.pixelSize: theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: theme.textColor
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: km.isFloating ? "Active (Drag corner to resize)" : "Detach mini thumb pad"
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        color: km.isFloating ? theme.keyActiveColor : theme.textSecondaryColor
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // 2. Split Mode (Pinnable, Landscape Only)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: theme.keyRadius
                opacity: root.isLandscape ? 1.0 : 0.5
                color: (km.splitMode && root.isLandscape) ? Qt.darker(theme.keyActiveColor, 2.0) : (cardSplitArea.pressed ? theme.keyPressedColor : theme.keyColor)
                border.color: (km.splitMode && root.isLandscape) ? theme.keyActiveColor : theme.borderColor
                border.width: 1

                MouseArea {
                    id: cardSplitArea
                    anchors.fill: parent
                    onClicked: {
                        if (root.isLandscape) {
                            km.splitMode = !km.splitMode
                        }
                    }
                }

                // Pin / Unpin Button (Stacked above card MouseArea with z: 10)
                Rectangle {
                    z: 10
                    width: km.splitPinned ? 62 : 32
                    height: 24
                    radius: 4
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    color: km.splitPinned ? theme.keyActiveColor : (pinSplitArea.pressed ? theme.keyPressedColor : theme.keySpecialColor)
                    border.color: km.splitPinned ? theme.keyActiveColor : theme.borderColor
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        VectorIcon {
                            name: "pin"
                            width: 12
                            height: 12
                            color: km.splitPinned ? "#FFFFFF" : theme.textSecondaryColor
                            strokeWidth: 1.8
                        }
                        Text {
                            visible: km.splitPinned
                            text: "Pinned"
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: "#FFFFFF"
                        }
                    }

                    MouseArea {
                        id: pinSplitArea
                        anchors.fill: parent
                        onClicked: km.togglePinSplit()
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    VectorIcon {
                        name: "split"
                        Layout.alignment: Qt.AlignHCenter
                        width: 22
                        height: 22
                        color: (km.splitMode && root.isLandscape) ? theme.keyActiveColor : theme.textColor
                        strokeWidth: 1.8
                    }
                    Text {
                        text: "Split Thumb Mode"
                        font.family: theme.fontFamily
                        font.pixelSize: theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: theme.textColor
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: !root.isLandscape ? "Landscape only" : (km.splitMode ? "Active (Thumb dual blocks)" : "Standard 5-row laptop")
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        color: (km.splitMode && root.isLandscape) ? theme.keyActiveColor : theme.textSecondaryColor
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // 3. Theme Mode (Pinnable, 3-Way: Follow System, Light, Dark)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: theme.keyRadius
                color: theme.keyColor
                border.color: theme.borderColor
                border.width: 1

                // Pin / Unpin Button (Stacked with z: 10)
                Rectangle {
                    z: 10
                    width: km.themePinned ? 62 : 32
                    height: 24
                    radius: 4
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    color: km.themePinned ? theme.keyActiveColor : (pinThemeArea.pressed ? theme.keyPressedColor : theme.keySpecialColor)
                    border.color: km.themePinned ? theme.keyActiveColor : theme.borderColor
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        VectorIcon {
                            name: "pin"
                            width: 12
                            height: 12
                            color: km.themePinned ? "#FFFFFF" : theme.textSecondaryColor
                            strokeWidth: 1.8
                        }
                        Text {
                            visible: km.themePinned
                            text: "Pinned"
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: "#FFFFFF"
                        }
                    }

                    MouseArea {
                        id: pinThemeArea
                        anchors.fill: parent
                        onClicked: km.togglePinTheme()
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    VectorIcon {
                        name: km.themeMode === 0 ? "theme-system" : (km.themeMode === 1 ? "sun" : "moon")
                        Layout.alignment: Qt.AlignHCenter
                        width: 22
                        height: 22
                        color: theme.textColor
                        strokeWidth: 1.8
                    }
                    Text {
                        text: "Theme: " + (km.themeMode === 0 ? "Follow System" : (km.themeMode === 1 ? "Light Mode" : "Dark Mode"))
                        font.family: theme.fontFamily
                        font.pixelSize: theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: theme.textColor
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // 3 Selector Pills: [ System ] [ Light ] [ Dark ]
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Repeater {
                            model: [
                                { label: "Auto", mode: 0 },
                                { label: "Light", mode: 1 },
                                { label: "Dark", mode: 2 }
                            ]
                            Rectangle {
                                width: 44
                                height: 20
                                radius: 3
                                color: km.themeMode === modelData.mode ? theme.keyActiveColor : theme.keySpecialColor
                                Text {
                                    text: modelData.label
                                    anchors.centerIn: parent
                                    font.family: theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: km.themeMode === modelData.mode ? Font.DemiBold : Font.Normal
                                    color: km.themeMode === modelData.mode ? "#FFFFFF" : theme.textSecondaryColor
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: km.themeMode = modelData.mode
                                }
                            }
                        }
                    }
                }
            }

            // 4. Sound Feedback (Pinnable)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: theme.keyRadius
                color: cardSoundArea.pressed ? theme.keyPressedColor : theme.keyColor
                border.color: theme.borderColor
                border.width: 1

                MouseArea {
                    id: cardSoundArea
                    anchors.fill: parent
                    onClicked: km.soundEnabled = !km.soundEnabled
                }

                // Pin / Unpin Button (Stacked with z: 10)
                Rectangle {
                    z: 10
                    width: km.soundPinned ? 62 : 32
                    height: 24
                    radius: 4
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    color: km.soundPinned ? theme.keyActiveColor : (pinSoundArea.pressed ? theme.keyPressedColor : theme.keySpecialColor)
                    border.color: km.soundPinned ? theme.keyActiveColor : theme.borderColor
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        VectorIcon {
                            name: "pin"
                            width: 12
                            height: 12
                            color: km.soundPinned ? "#FFFFFF" : theme.textSecondaryColor
                            strokeWidth: 1.8
                        }
                        Text {
                            visible: km.soundPinned
                            text: "Pinned"
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: "#FFFFFF"
                        }
                    }

                    MouseArea {
                        id: pinSoundArea
                        anchors.fill: parent
                        onClicked: km.togglePinSound()
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    VectorIcon {
                        name: km.soundEnabled ? "volume-on" : "volume-off"
                        Layout.alignment: Qt.AlignHCenter
                        width: 22
                        height: 22
                        color: km.soundEnabled ? "#3FB950" : theme.textColor
                        strokeWidth: 1.8
                    }
                    Text {
                        text: "Audio Click Feedback"
                        font.family: theme.fontFamily
                        font.pixelSize: theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: theme.textColor
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: km.soundEnabled ? "Enabled" : "Muted"
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        color: km.soundEnabled ? "#3FB950" : theme.textSecondaryColor
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // 5. Keyboard Height Customization (Docked)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: theme.keyRadius
                color: theme.keyColor
                border.color: theme.borderColor
                border.width: 1

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    VectorIcon {
                        name: "height"
                        Layout.alignment: Qt.AlignHCenter
                        width: 22
                        height: 22
                        color: theme.textColor
                        strokeWidth: 1.8
                    }
                    Text {
                        text: "Docked Height"
                        font.family: theme.fontFamily
                        font.pixelSize: theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: theme.textColor
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // 4 Height Presets: [ 85% ] [ 100% ] [ 115% ] [ 125% ]
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 3

                        Repeater {
                            model: [
                                { label: "85%", scale: 0.85 },
                                { label: "100%", scale: 1.0 },
                                { label: "115%", scale: 1.15 },
                                { label: "125%", scale: 1.25 }
                            ]
                            Rectangle {
                                width: 34
                                height: 20
                                radius: 3
                                color: Math.abs(km.heightScale - modelData.scale) < 0.05 ? theme.keyActiveColor : theme.keySpecialColor
                                Text {
                                    text: modelData.label
                                    anchors.centerIn: parent
                                    font.family: theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Math.abs(km.heightScale - modelData.scale) < 0.05 ? Font.DemiBold : Font.Normal
                                    color: Math.abs(km.heightScale - modelData.scale) < 0.05 ? "#FFFFFF" : theme.textSecondaryColor
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: km.heightScale = modelData.scale
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
