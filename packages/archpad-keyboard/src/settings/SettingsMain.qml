import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

QQC2.ApplicationWindow {
    id: root
    title: "ArchPad Keyboard Settings"
    visible: true
    width: Math.min(1100, Screen.width * 0.94)
    height: Math.min(740, Screen.height * 0.9)
    minimumWidth: 720
    minimumHeight: 520
    readonly property bool narrowLayout: width < 900

    Theme {
        id: theme
    }

    color: theme.backgroundColor

    // Master-Detail 2-Column Layout
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ==========================================
        // 1. LEFT SIDEBAR NAVIGATION (280px)
        // ==========================================
        Rectangle {
            Layout.preferredWidth: root.narrowLayout ? 210 : 280
            Layout.fillHeight: true
            color: theme.surfaceColor

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Sidebar Header / Brand
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    color: theme.headerColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        VectorIcon {
                            name: "settings"
                            implicitWidth: 24
                            implicitHeight: 24
                            color: theme.keyActiveColor
                            strokeWidth: 2.0
                        }

                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: "ArchPad Keyboard"
                                font.family: theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: theme.textColor
                            }
                            Text {
                                text: "Settings & Configuration"
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                color: theme.textSecondaryColor
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: theme.dividerColor
                }

                // Category List
                ListView {
                    id: navList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 8
                    spacing: 4
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    model: [
                        { name: "Appearance & Sound", icon: "sun", desc: "Theme, height scale, audio click" },
                        { name: "Quick-Pad Macros", icon: "quickpad", desc: "Custom popup keys & macros" },
                        { name: "Typing & Layout", icon: "split", desc: "Split thumb mode, floating width" },
                        { name: "Gesture & Swipe", icon: "gesture", desc: "FUTO neural swipe typing, trail & models" },
                        { name: "Top Bar Quick Pins", icon: "pin", desc: "Header bar tools & pins" },
                        { name: "Input Timing", icon: "height", desc: "Long-press hold delay" },
                        { name: "System & Info", icon: "settings", desc: "Subsystem diagnostics & reset" }
                    ]

                    delegate: Rectangle {
                        id: navItem
                        width: navList.width
                        height: 52
                        radius: theme.keyRadius

                        readonly property bool isSelected: controller.selectedCategory === index

                        color: isSelected ? (theme.isDark ? "#24324D" : "#E8F0FE") :
                               (navMouse.pressed ? theme.keyPressedColor : (navMouse.containsMouse ? theme.keySpecialColor : "transparent"))
                        border.color: isSelected ? theme.keyActiveColor : "transparent"
                        border.width: isSelected ? 1 : 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 12
                            spacing: 10

                            // Selection Indicator Bar
                            Rectangle {
                                implicitWidth: 3
                                implicitHeight: 26
                                radius: 1.5
                                color: navItem.isSelected ? theme.keyActiveColor : "transparent"
                            }

                            VectorIcon {
                                name: modelData.icon
                                implicitWidth: 18
                                implicitHeight: 18
                                color: navItem.isSelected ? theme.keyActiveColor : theme.textColor
                                strokeWidth: 1.8
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.name
                                    font.family: theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: navItem.isSelected ? Font.Bold : Font.DemiBold
                                    color: navItem.isSelected ? theme.keyActiveColor : theme.textColor
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.desc
                                    font.family: theme.fontFamily
                                    font.pixelSize: 10
                                    color: theme.textSecondaryColor
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: controller.selectedCategory = index
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: theme.dividerColor
                }

                // Sidebar Footer: Daemon Status
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 50
                    color: theme.headerColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 8

                        Rectangle {
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: 4
                            color: controller.daemonConnected ? "#22C55E" : "#EF4444"
                        }

                        Text {
                            text: controller.daemonConnected ? "Daemon Active (D-Bus)" : "Daemon Offline"
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: controller.daemonConnected ? (theme.isDark ? "#4ADE80" : "#166534") : theme.textSecondaryColor
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        // ==========================================
        // 2. VERTICAL DIVIDER
        // ==========================================
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: theme.dividerColor
        }

        // ==========================================
        // 3. RIGHT CONTENT AREA (~70-72%)
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: theme.backgroundColor

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Top Header for Active Section
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    color: theme.headerColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 2
                            Text {
                                text: {
                                    switch (controller.selectedCategory) {
                                    case 0: return "Appearance & Sound"
                                    case 1: return "Quick-Pad Macros"
                                    case 2: return "Typing & Layout"
                                    case 3: return "Gesture & Swipe Typing"
                                    case 4: return "Top Bar Quick Pins"
                                    case 5: return "Input Timing"
                                    case 6: return "System & Diagnostics"
                                    default: return "Settings"
                                    }
                                }
                                font.family: theme.fontFamily
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: theme.textColor
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: {
                                    switch (controller.selectedCategory) {
                                     case 0: return "Customize theme styles, height scaling, and keypress audio feedback"
                                     case 1: return "Configure custom popup macro pad with up to 4 quick action keys"
                                     case 2: return "Configure ergonomic split thumb typing and floating window dimensions"
                                     case 3: return "Configure FUTO neural gesture typing, GPU trail styling, and engine memory"
                                     case 4: return "Choose which tools and toggles appear on the keyboard's header bar"
                                     case 5: return "Tune the hold delay used for secondary key actions"
                                     case 6: return "Inspect daemon D-Bus connectivity, system paths, or restore defaults"
                                     default: return ""
                                     }
                                }
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                color: theme.textSecondaryColor
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Summon/Dismiss Keyboard Action Button
                        Rectangle {
                            implicitWidth: root.narrowLayout ? 40 : 136
                            implicitHeight: 34
                            radius: theme.keyRadius
                            color: kbBtnArea.pressed ? theme.keyPressedColor : theme.keySpecialColor
                            border.color: theme.borderColor
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                VectorIcon {
                                    name: "pop-out"
                                    implicitWidth: 14
                                    implicitHeight: 14
                                    color: theme.textColor
                                }
                                Text {
                                    visible: !root.narrowLayout
                                    text: "Toggle Keyboard"
                                    font.family: theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: theme.textColor
                                }
                            }

                            MouseArea {
                                id: kbBtnArea
                                anchors.fill: parent
                                onClicked: controller.toggleKeyboard()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: theme.dividerColor
                }

                // Category Views Stack
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: controller.selectedCategory

                    // ==========================================
                    // VIEW 0: APPEARANCE & SOUND
                    // ==========================================
                    Item {
                        id: viewAppearance
                        Flickable {
                            anchors.fill: parent
                            contentHeight: appCol.height + 32
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            ColumnLayout {
                                id: appCol
                                width: parent.width - (root.narrowLayout ? 24 : 40)
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 16
                                spacing: 16

                                // Card 1: Theme Mode
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: themeCardCol.implicitHeight + 28
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1

                                    ColumnLayout {
                                        id: themeCardCol
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        Text {
                                            text: "Theme Mode"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            color: theme.textColor
                                        }

                                        Text {
                                            text: "Choose between following KDE Plasma system theme, or forcing light/dark mode:"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            color: theme.textSecondaryColor
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12

                                            Repeater {
                                                model: [
                                                    { name: "System Default", icon: "theme-system", desc: "Follow Plasma color scheme", mode: 0 },
                                                    { name: "Light Mode", icon: "sun", desc: "Clean crisp light theme", mode: 1 },
                                                    { name: "Dark Mode", icon: "moon", desc: "OLED dark grey aesthetic", mode: 2 }
                                                ]

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 72
                                                    radius: theme.keyRadius
                                                    color: controller.themeMode === modelData.mode ? (theme.isDark ? "#24324D" : "#E8F0FE") : theme.keyColor
                                                    border.color: controller.themeMode === modelData.mode ? theme.keyActiveColor : theme.borderColor
                                                    border.width: controller.themeMode === modelData.mode ? 2 : 1

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 12
                                                        spacing: 10

                                                        VectorIcon {
                                                            name: modelData.icon
                                                            implicitWidth: 22
                                                            implicitHeight: 22
                                                            color: controller.themeMode === modelData.mode ? theme.keyActiveColor : theme.textColor
                                                        }

                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 1
                                                            Text {
                                                                text: modelData.name
                                                                font.family: theme.fontFamily
                                                                font.pixelSize: 12
                                                                font.weight: Font.Bold
                                                                color: controller.themeMode === modelData.mode ? theme.keyActiveColor : theme.textColor
                                                            }
                                                            Text {
                                                                text: modelData.desc
                                                                font.family: theme.fontFamily
                                                                font.pixelSize: 10
                                                                color: theme.textSecondaryColor
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: controller.themeMode = modelData.mode
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Card 2: Keyboard Height Scale
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: heightCardCol.implicitHeight + 28
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1

                                    ColumnLayout {
                                        id: heightCardCol
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "Keyboard Height Scaling"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                color: theme.textColor
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: Math.round(controller.heightScale * 100) + "%"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: theme.keyActiveColor
                                            }
                                        }

                                        Text {
                                            text: "Adjust keyboard vertical scale for comfortable thumb reach across landscape and portrait:"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            color: theme.textSecondaryColor
                                        }

                                        QQC2.Slider {
                                            Layout.fillWidth: true
                                            from: 0.75
                                            to: 1.30
                                            stepSize: 0.05
                                            value: controller.heightScale
                                            onMoved: controller.heightScale = value
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Repeater {
                                                model: [
                                                    { label: "85% (Compact)", val: 0.85 },
                                                    { label: "100% (Standard)", val: 1.0 },
                                                    { label: "115% (Comfortable)", val: 1.15 },
                                                    { label: "125% (Large)", val: 1.25 }
                                                ]

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 30
                                                    radius: theme.keyRadius
                                                    color: Math.abs(controller.heightScale - modelData.val) < 0.02 ? theme.keyActiveColor : theme.keySpecialColor
                                                    border.color: Math.abs(controller.heightScale - modelData.val) < 0.02 ? theme.keyActiveColor : theme.borderColor
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.label
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: Math.abs(controller.heightScale - modelData.val) < 0.02 ? Font.Bold : Font.Normal
                                                        color: Math.abs(controller.heightScale - modelData.val) < 0.02 ? "#FFFFFF" : theme.textColor
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: controller.heightScale = modelData.val
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Card 3: Keypress Audio Feedback
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: audioCardCol.implicitHeight + 32
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1

                                    ColumnLayout {
                                        id: audioCardCol
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12

                                            VectorIcon {
                                                name: controller.soundEnabled ? "volume-on" : "volume-off"
                                                implicitWidth: 22
                                                implicitHeight: 22
                                                color: controller.soundEnabled ? theme.textColor : theme.textSecondaryColor
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                                spacing: 1
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: "Keypress Audio Feedback"
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.Bold
                                                    color: theme.textColor
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: "Choose a mobile tap profile and keyboard-only volume"
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: theme.textSecondaryColor
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            QQC2.Switch {
                                                checked: controller.soundEnabled
                                                onToggled: controller.soundEnabled = checked
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 1
                                            color: theme.dividerColor
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "Keyboard volume"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                color: theme.textColor
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: controller.soundVolume + "%"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: theme.keyActiveColor
                                            }
                                        }

                                        QQC2.Slider {
                                            Layout.fillWidth: true
                                            enabled: controller.soundEnabled
                                            from: 0
                                            to: 100
                                            stepSize: 5
                                            value: controller.soundVolume
                                            onMoved: controller.soundVolume = Math.round(value)
                                        }

                                        Text {
                                            text: "Tap sound"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: theme.textColor
                                        }

                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: root.narrowLayout ? 1 : 2
                                            columnSpacing: 8
                                            rowSpacing: 8

                                            Repeater {
                                                model: [
                                                    { name: "Standard", desc: "Subtle Android letter tap", mode: 0 },
                                                    { name: "Soft", desc: "Round and gentle", mode: 1 },
                                                    { name: "Crisp", desc: "Short and defined", mode: 2 },
                                                    { name: "Deep", desc: "Compact lower tap", mode: 3 }
                                                ]

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    implicitHeight: 48
                                                    radius: theme.keyRadius
                                                    color: controller.soundProfile === modelData.mode
                                                           ? (theme.isDark ? "#24324D" : "#E8F0FE")
                                                           : theme.keyColor
                                                    border.color: controller.soundProfile === modelData.mode
                                                                  ? theme.keyActiveColor : theme.borderColor
                                                    border.width: controller.soundProfile === modelData.mode ? 2 : 1

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 10
                                                        spacing: 10

                                                        Rectangle {
                                                            implicitWidth: 14
                                                            implicitHeight: 14
                                                            radius: 7
                                                            color: controller.soundProfile === modelData.mode
                                                                   ? theme.keyActiveColor : "transparent"
                                                            border.color: controller.soundProfile === modelData.mode
                                                                          ? theme.keyActiveColor : theme.textSecondaryColor
                                                            border.width: 2
                                                        }

                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            Layout.minimumWidth: 0
                                                            spacing: 0
                                                            Text {
                                                                Layout.fillWidth: true
                                                                text: modelData.name
                                                                font.family: theme.fontFamily
                                                                font.pixelSize: 11
                                                                font.weight: Font.Bold
                                                                color: theme.textColor
                                                            }
                                                            Text {
                                                                Layout.fillWidth: true
                                                                text: modelData.desc
                                                                font.family: theme.fontFamily
                                                                font.pixelSize: 10
                                                                color: theme.textSecondaryColor
                                                                elide: Text.ElideRight
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: controller.selectSoundProfile(modelData.mode)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ==========================================
                    // VIEW 1: QUICK-PAD MACROS
                    // ==========================================
                    Item {
                        id: viewQuickPad

                        GridLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            columns: root.narrowLayout ? 1 : 2
                            rowSpacing: 16
                            columnSpacing: 16

                            // LEFT SIDE: Interactive Live 1:1 Preview (Width: 300)
                            Rectangle {
                                Layout.preferredWidth: root.narrowLayout ? -1 : 300
                                Layout.fillWidth: root.narrowLayout
                                Layout.preferredHeight: root.narrowLayout ? 340 : -1
                                Layout.fillHeight: !root.narrowLayout
                                radius: theme.cardRadius
                                color: theme.surfaceColor
                                border.color: theme.borderColor
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Live Preview"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            color: theme.textColor
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: "Tap key to select"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 10
                                            color: theme.textSecondaryColor
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: theme.dividerColor }

                                    // Preview Frame
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 180

                                        Rectangle {
                                            id: previewSquare
                                            width: 160
                                            height: 160
                                            radius: theme.keyRadius
                                            anchors.centerIn: parent
                                            color: theme.backgroundColor
                                            border.color: theme.borderColor
                                            border.width: 1

                                            // Dynamic Key Preview Subdivisions
                                            Loader {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                sourceComponent: {
                                                    switch (controller.quickPadKeyCount) {
                                                    case 1: return preview1KeyComp;
                                                    case 2: return preview2KeysComp;
                                                    case 3: return preview3KeysComp;
                                                    default: return preview4KeysComp;
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Preview Components
                                    Component {
                                        id: preview1KeyComp
                                        Item {
                                            anchors.fill: parent
                                            PreviewKeyItem { anchors.fill: parent; slotIndex: 0 }
                                        }
                                    }

                                    Component {
                                        id: preview2KeysComp
                                        ColumnLayout {
                                            anchors.fill: parent
                                            spacing: 4
                                            PreviewKeyItem { Layout.fillWidth: true; Layout.fillHeight: true; slotIndex: 0 }
                                            PreviewKeyItem { Layout.fillWidth: true; Layout.fillHeight: true; slotIndex: 1 }
                                        }
                                    }

                                    Component {
                                        id: preview3KeysComp
                                        ColumnLayout {
                                            anchors.fill: parent
                                            spacing: 3
                                            PreviewKeyItem { Layout.fillWidth: true; Layout.fillHeight: true; slotIndex: 0 }
                                            PreviewKeyItem { Layout.fillWidth: true; Layout.fillHeight: true; slotIndex: 1 }
                                            PreviewKeyItem { Layout.fillWidth: true; Layout.fillHeight: true; slotIndex: 2 }
                                        }
                                    }

                                    Component {
                                        id: preview4KeysComp
                                        GridLayout {
                                            anchors.fill: parent
                                            columns: 2
                                            rowSpacing: 4
                                            columnSpacing: 4
                                            PreviewKeyItem { Layout.fillWidth: true; Layout.fillHeight: true; slotIndex: 0 }
                                            PreviewKeyItem { Layout.fillWidth: true; Layout.fillHeight: true; slotIndex: 1 }
                                            PreviewKeyItem { Layout.fillWidth: true; Layout.fillHeight: true; slotIndex: 2 }
                                            PreviewKeyItem { Layout.fillWidth: true; Layout.fillHeight: true; slotIndex: 3 }
                                        }
                                    }

                                    component PreviewKeyItem: Rectangle {
                                        id: pki
                                        property int slotIndex: 0
                                        readonly property bool isSelected: controller.selectedSlot === slotIndex

                                        radius: 4
                                        color: isSelected ? (theme.isDark ? "#1E3A8A" : "#DBEAFE") : theme.keyColor
                                        border.color: isSelected ? theme.keyActiveColor : theme.borderColor
                                        border.width: isSelected ? 2 : 1

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 2

                                            Rectangle {
                                                Layout.alignment: Qt.AlignHCenter
                                                implicitWidth: 14
                                                implicitHeight: 14
                                                radius: 7
                                                color: pki.isSelected ? theme.keyActiveColor : theme.keySpecialColor
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: (pki.slotIndex + 1)
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 9
                                                    font.weight: Font.Bold
                                                    color: pki.isSelected ? "#FFFFFF" : theme.textColor
                                                }
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: {
                                                    let _ = controller.configRevision
                                                    return controller.quickPadLabel(pki.slotIndex)
                                                }
                                                font.family: theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: pki.isSelected ? theme.keyActiveColor : theme.textColor
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: controller.selectedSlot = pki.slotIndex
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: theme.dividerColor }

                                    // Size Slider
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Pad Size:"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: theme.textColor
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: Math.round(controller.quickPadSize) + " px"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: theme.keyActiveColor
                                        }
                                    }

                                    QQC2.Slider {
                                        Layout.fillWidth: true
                                        from: 160
                                        to: 380
                                        stepSize: 10
                                        value: controller.quickPadSize
                                        onMoved: controller.quickPadSize = value
                                    }

                                    // Size Presets
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                { label: "180px", val: 180 },
                                                { label: "220px", val: 220 },
                                                { label: "280px", val: 280 },
                                                { label: "340px", val: 340 }
                                            ]

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 22
                                                radius: 3
                                                color: Math.round(controller.quickPadSize) === modelData.val ? theme.keyActiveColor : theme.keySpecialColor
                                                border.color: theme.borderColor
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 9
                                                    font.weight: Math.round(controller.quickPadSize) === modelData.val ? Font.Bold : Font.Normal
                                                    color: Math.round(controller.quickPadSize) === modelData.val ? "#FFFFFF" : theme.textColor
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: controller.quickPadSize = modelData.val
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }

                                    // Test & Launch Pad Buttons
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 34
                                            radius: theme.keyRadius
                                            color: testArea.pressed ? theme.keyPressedColor : theme.keySpecialColor
                                            border.color: theme.borderColor
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: {
                                                    let _ = controller.configRevision
                                                    return "Test Slot " + (controller.selectedSlot + 1) + " (" + controller.quickPadLabel(controller.selectedSlot) + ")"
                                                }
                                                font.family: theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: theme.textColor
                                            }

                                            MouseArea {
                                                id: testArea
                                                anchors.fill: parent
                                                onClicked: controller.testKey(controller.selectedSlot)
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            implicitHeight: 34
                                            radius: theme.keyRadius
                                            color: launchArea.pressed ? theme.keyPressedColor : theme.keyActiveColor

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Launch Pad"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: "#FFFFFF"
                                            }

                                            MouseArea {
                                                id: launchArea
                                                anchors.fill: parent
                                                onClicked: controller.launchQuickPad()
                                            }
                                        }
                                    }
                                }
                            }

                            // RIGHT SIDE: Macro Configurator (Flickable)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: root.narrowLayout ? 600 : -1
                                radius: theme.cardRadius
                                color: theme.surfaceColor
                                border.color: theme.borderColor
                                border.width: 1

                                Flickable {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    contentHeight: cfgCol.height + 20
                                    boundsBehavior: Flickable.StopAtBounds
                                    clip: true

                                    ColumnLayout {
                                        id: cfgCol
                                        width: parent.width
                                        spacing: 12

                                        // Key Subdivision Selector
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: "Key Subdivision:"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: theme.textColor
                                            }

                                            Repeater {
                                                model: [1, 2, 3, 4]
                                                Rectangle {
                                                    width: 68
                                                    height: 28
                                                    radius: theme.keyRadius
                                                    color: controller.quickPadKeyCount === modelData ? theme.keyActiveColor : theme.keySpecialColor
                                                    border.color: controller.quickPadKeyCount === modelData ? theme.keyActiveColor : theme.borderColor
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData === 1 ? "1 Key" : (modelData + " Keys")
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: controller.quickPadKeyCount === modelData ? Font.Bold : Font.Normal
                                                        color: controller.quickPadKeyCount === modelData ? "#FFFFFF" : theme.textColor
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: controller.quickPadKeyCount = modelData
                                                    }
                                                }
                                            }
                                        }

                                        // Slot Selection Tabs
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: "Select Slot:"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: theme.textColor
                                            }

                                            Repeater {
                                                model: controller.quickPadKeyCount
                                                Rectangle {
                                                    width: 86
                                                    height: 28
                                                    radius: theme.keyRadius
                                                    color: controller.selectedSlot === modelData ? theme.keyActiveColor : theme.keySpecialColor
                                                    border.color: controller.selectedSlot === modelData ? theme.keyActiveColor : theme.borderColor
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: {
                                                            let _ = controller.configRevision
                                                            return "Slot " + (modelData + 1) + ": " + controller.quickPadLabel(modelData)
                                                        }
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: controller.selectedSlot === modelData ? Font.Bold : Font.Normal
                                                        color: controller.selectedSlot === modelData ? "#FFFFFF" : theme.textColor
                                                        elide: Text.ElideRight
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: controller.selectedSlot = modelData
                                                    }
                                                }
                                            }
                                        }

                                        // Slot Label Input Field (Tapping summons virtual keyboard!)
                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 52
                                            radius: theme.keyRadius
                                            color: theme.keyColor
                                            border.color: theme.borderColor
                                            border.width: 1

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 12

                                                Text {
                                                    text: "Slot " + (controller.selectedSlot + 1) + " Label:"
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    color: theme.textColor
                                                }

                                                QQC2.TextField {
                                                    id: labelInput
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 34
                                                    text: controller.quickPadLabel(controller.selectedSlot)
                                                    placeholderText: "Type key label (e.g. Esc, Git, Save, Tab, Compile)..."
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 13
                                                    color: theme.textColor
                                                    background: Rectangle {
                                                        radius: 4
                                                        color: theme.surfaceColor
                                                        border.color: labelInput.activeFocus ? theme.keyActiveColor : theme.borderColor
                                                        border.width: labelInput.activeFocus ? 2 : 1
                                                    }
                                                    onTextEdited: controller.setQuickPadLabel(controller.selectedSlot, text)

                                                    Connections {
                                                        target: controller
                                                        function onQuickPadConfigChanged() {
                                                            if (!labelInput.activeFocus) {
                                                                labelInput.text = controller.quickPadLabel(controller.selectedSlot)
                                                            }
                                                        }
                                                        function onSelectedSlotChanged() {
                                                            labelInput.text = controller.quickPadLabel(controller.selectedSlot)
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Assigned Linux Keycode Status Banner
                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 30
                                            radius: 4
                                            color: theme.surfaceColor
                                            border.color: theme.borderColor
                                            border.width: 1

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                spacing: 8

                                                Text {
                                                    text: "Assigned Linux Keycode:"
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: theme.textSecondaryColor
                                                }

                                                Rectangle {
                                                    implicitHeight: 20
                                                    implicitWidth: codeText.implicitWidth + 12
                                                    radius: 3
                                                    color: theme.keySpecialColor
                                                    border.color: theme.borderColor
                                                    border.width: 1

                                                    Text {
                                                        id: codeText
                                                        anchors.centerIn: parent
                                                        text: {
                                                            let _ = controller.configRevision
                                                            return "KEY (" + controller.quickPadKeycode(controller.selectedSlot) + ")"
                                                        }
                                                        font.family: "monospace"
                                                        font.pixelSize: 10
                                                        font.weight: Font.Bold
                                                        color: theme.textColor
                                                    }
                                                }

                                                Item { Layout.fillWidth: true }

                                                Text {
                                                    text: "Select a preset or key below to change keycode"
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 10
                                                    color: theme.textSecondaryColor
                                                }
                                            }
                                        }

                                        // Active Modifiers
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: "Active Modifiers:"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                color: theme.textColor
                                            }

                                            Repeater {
                                                model: [
                                                    { name: "Ctrl", id: 0 },
                                                    { name: "Alt", id: 1 },
                                                    { name: "Shift", id: 2 },
                                                    { name: "Super", id: 3 }
                                                ]

                                                Rectangle {
                                                    id: modRect
                                                    width: 60
                                                    height: 26
                                                    radius: 4

                                                    readonly property bool isActive: {
                                                        let _ = controller.configRevision
                                                        let slot = controller.selectedSlot
                                                        switch (modelData.id) {
                                                        case 0: return controller.quickPadCtrl(slot)
                                                        case 1: return controller.quickPadAlt(slot)
                                                        case 2: return controller.quickPadShift(slot)
                                                        case 3: return controller.quickPadMeta(slot)
                                                        default: return false
                                                        }
                                                    }

                                                    color: isActive ? theme.keyActiveColor : theme.keySpecialColor
                                                    border.color: isActive ? theme.keyActiveColor : theme.borderColor
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.name
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: modRect.isActive ? Font.Bold : Font.Normal
                                                        color: modRect.isActive ? "#FFFFFF" : theme.textColor
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: {
                                                            let slot = controller.selectedSlot
                                                            switch (modelData.id) {
                                                            case 0: controller.setQuickPadCtrl(slot, !controller.quickPadCtrl(slot)); break
                                                            case 1: controller.setQuickPadAlt(slot, !controller.quickPadAlt(slot)); break
                                                            case 2: controller.setQuickPadShift(slot, !controller.quickPadShift(slot)); break
                                                            case 3: controller.setQuickPadMeta(slot, !controller.quickPadMeta(slot)); break
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Popular Presets
                                        Text {
                                            text: "Quick Presets (Tap to apply):"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: theme.textSecondaryColor
                                        }

                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Repeater {
                                                model: [
                                                    { label: "Esc", code: 1, ctrl: false, alt: false, shift: false, meta: false },
                                                    { label: "Tab", code: 15, ctrl: false, alt: false, shift: false, meta: false },
                                                    { label: "Enter", code: 28, ctrl: false, alt: false, shift: false, meta: false },
                                                    { label: "Bksp", code: 14, ctrl: false, alt: false, shift: false, meta: false },
                                                    { label: "Del", code: 111, ctrl: false, alt: false, shift: false, meta: false },
                                                    { label: "Space", code: 57, ctrl: false, alt: false, shift: false, meta: false },
                                                    { label: "Ctrl+C", code: 46, ctrl: true, alt: false, shift: false, meta: false },
                                                    { label: "Ctrl+V", code: 47, ctrl: true, alt: false, shift: false, meta: false },
                                                    { label: "Ctrl+X", code: 45, ctrl: true, alt: false, shift: false, meta: false },
                                                    { label: "Ctrl+Z", code: 44, ctrl: true, alt: false, shift: false, meta: false },
                                                    { label: "Ctrl+A", code: 30, ctrl: true, alt: false, shift: false, meta: false },
                                                    { label: "Ctrl+S", code: 31, ctrl: true, alt: false, shift: false, meta: false },
                                                    { label: "Alt+Tab", code: 15, ctrl: false, alt: true, shift: false, meta: false },
                                                    { label: "Super", code: 125, ctrl: false, alt: false, shift: false, meta: false },
                                                    { label: "F5", code: 63, ctrl: false, alt: false, shift: false, meta: false },
                                                    { label: "F11", code: 87, ctrl: false, alt: false, shift: false, meta: false }
                                                ]

                                                Rectangle {
                                                    width: Math.max(52, pText.contentWidth + 14)
                                                    height: 25
                                                    radius: 4
                                                    color: theme.keySpecialColor
                                                    border.color: theme.borderColor
                                                    border.width: 1

                                                    Text {
                                                        id: pText
                                                        anchors.centerIn: parent
                                                        text: modelData.label
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: Font.DemiBold
                                                        color: theme.textColor
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: controller.applyPreset(controller.selectedSlot, modelData.label, modelData.code, modelData.ctrl, modelData.alt, modelData.shift, modelData.meta)
                                                    }
                                                }
                                            }
                                        }

                                        // Function Keys
                                        Text {
                                            text: "Function Keys:"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: theme.textSecondaryColor
                                        }

                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 5

                                            Repeater {
                                                model: [
                                                    { label: "F1", code: 59 }, { label: "F2", code: 60 }, { label: "F3", code: 61 }, { label: "F4", code: 62 },
                                                    { label: "F5", code: 63 }, { label: "F6", code: 64 }, { label: "F7", code: 65 }, { label: "F8", code: 66 },
                                                    { label: "F9", code: 67 }, { label: "F10", code: 68 }, { label: "F11", code: 87 }, { label: "F12", code: 88 }
                                                ]

                                                Rectangle {
                                                    width: 42
                                                    height: 25
                                                    radius: 4
                                                    color: theme.keySpecialColor
                                                    border.color: theme.borderColor
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.label
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: Font.DemiBold
                                                        color: theme.textColor
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: controller.applyFunctionKey(controller.selectedSlot, modelData.label, modelData.code)
                                                    }
                                                }
                                            }
                                        }

                                        // Navigation Keys
                                        Text {
                                            text: "Common & Navigation Keys:"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: theme.textSecondaryColor
                                        }

                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 5

                                            Repeater {
                                                model: [
                                                    { label: "Up", code: 103 }, { label: "Down", code: 108 }, { label: "Left", code: 105 }, { label: "Right", code: 106 },
                                                    { label: "Home", code: 102 }, { label: "End", code: 107 }, { label: "PgUp", code: 104 }, { label: "PgDn", code: 109 },
                                                    { label: "A", code: 30 }, { label: "B", code: 48 }, { label: "C", code: 46 }, { label: "D", code: 32 },
                                                    { label: "E", code: 18 }, { label: "F", code: 33 }, { label: "G", code: 34 }, { label: "H", code: 35 },
                                                    { label: "I", code: 23 }, { label: "J", code: 36 }, { label: "K", code: 37 }, { label: "L", code: 38 },
                                                    { label: "M", code: 50 }, { label: "N", code: 49 }, { label: "O", code: 24 }, { label: "P", code: 25 },
                                                    { label: "Q", code: 16 }, { label: "R", code: 19 }, { label: "S", code: 31 }, { label: "T", code: 20 },
                                                    { label: "U", code: 22 }, { label: "V", code: 47 }, { label: "W", code: 17 }, { label: "X", code: 45 },
                                                    { label: "Y", code: 21 }, { label: "Z", code: 44 }
                                                ]

                                                Rectangle {
                                                    width: Math.max(34, navKeyText.contentWidth + 12)
                                                    height: 25
                                                    radius: 4
                                                    color: theme.keySpecialColor
                                                    border.color: theme.borderColor
                                                    border.width: 1

                                                    Text {
                                                        id: navKeyText
                                                        anchors.centerIn: parent
                                                        text: modelData.label
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 10
                                                        font.weight: Font.DemiBold
                                                        color: theme.textColor
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: controller.applyNavKey(controller.selectedSlot, modelData.label, modelData.code)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ==========================================
                    // VIEW 2: TYPING & LAYOUT
                    // ==========================================
                    Item {
                        id: viewTyping
                        Flickable {
                            anchors.fill: parent
                            contentHeight: typeCol.height + 32
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            ColumnLayout {
                                id: typeCol
                                width: parent.width - (root.narrowLayout ? 24 : 40)
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 16
                                spacing: 16

                                // Card 1: Split Thumb Mode
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 72
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        VectorIcon {
                                            name: "split"
                                            implicitWidth: 22
                                            implicitHeight: 22
                                            color: theme.textColor
                                        }

                                        ColumnLayout {
                                            spacing: 1
                                            Text {
                                                text: "Split Thumb Mode in Landscape"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: theme.textColor
                                            }
                                            Text {
                                                text: "Splits keys to left and right edges with central navigation pad for ergonomic two-thumb typing"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 11
                                                color: theme.textSecondaryColor
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        QQC2.Switch {
                                            checked: controller.splitMode
                                            onToggled: controller.splitMode = checked
                                        }
                                    }
                                }

                                // Card 2: Floating Keyboard Default Width
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: floatCol.implicitHeight + 28
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1

                                    ColumnLayout {
                                        id: floatCol
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "Floating Keyboard Width"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                color: theme.textColor
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: Math.round(controller.floatingWidth) + " px"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: theme.keyActiveColor
                                            }
                                        }

                                        Text {
                                            text: "Initial width when keyboard is detached into floating popup window mode:"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            color: theme.textSecondaryColor
                                        }

                                        QQC2.Slider {
                                            Layout.fillWidth: true
                                            from: 340
                                            to: 580
                                            stepSize: 10
                                            value: controller.floatingWidth
                                            onMoved: controller.floatingWidth = value
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Repeater {
                                                model: [
                                                    { label: "360 px (Compact)", val: 360 },
                                                    { label: "420 px (Standard)", val: 420 },
                                                    { label: "480 px (Wide)", val: 480 },
                                                    { label: "540 px (Comfort)", val: 540 }
                                                ]

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    implicitHeight: 30
                                                    radius: theme.keyRadius
                                                    color: Math.abs(controller.floatingWidth - modelData.val) < 5 ? theme.keyActiveColor : theme.keySpecialColor
                                                    border.color: Math.abs(controller.floatingWidth - modelData.val) < 5 ? theme.keyActiveColor : theme.borderColor
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.label
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: Math.abs(controller.floatingWidth - modelData.val) < 5 ? Font.Bold : Font.Normal
                                                        color: Math.abs(controller.floatingWidth - modelData.val) < 5 ? "#FFFFFF" : theme.textColor
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: controller.floatingWidth = modelData.val
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Card 3: One-Handed Mode (Roadmap)
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 68
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        VectorIcon {
                                            name: "pop-out"
                                            implicitWidth: 20
                                            implicitHeight: 20
                                            color: theme.textSecondaryColor
                                        }

                                        ColumnLayout {
                                            spacing: 1
                                            Text {
                                                text: "One-Handed Keyboard Docking"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: theme.textColor
                                            }
                                            Text {
                                                text: "Docks keyboard to left or right screen edge for single-handed typing"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 11
                                                color: theme.textSecondaryColor
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            implicitHeight: 22
                                            implicitWidth: plannedTxt.implicitWidth + 12
                                            radius: 3
                                            color: theme.keySpecialColor
                                            border.color: theme.borderColor
                                            border.width: 1
                                            Text {
                                                id: plannedTxt
                                                anchors.centerIn: parent
                                                text: "Planned for v1.1"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: theme.keyActiveColor
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ==========================================
                    // VIEW 3: GESTURE & SWIPE TYPING
                    // ==========================================
                    Item {
                        id: viewSwipe
                        Flickable {
                            anchors.fill: parent
                            contentHeight: swipeCol.height + 32
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            ColumnLayout {
                                id: swipeCol
                                width: parent.width - (root.narrowLayout ? 24 : 40)
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 16
                                spacing: 16

                                // Card 1: Master Enable Toggle
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 72
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        VectorIcon {
                                            name: "gesture"
                                            implicitWidth: 22
                                            implicitHeight: 22
                                            color: controller.swipeEnabled ? theme.keyActiveColor : theme.textSecondaryColor
                                            strokeWidth: 2.2
                                        }

                                        ColumnLayout {
                                            spacing: 1
                                            Text {
                                                text: "Swipe Gesture Typing in Floating Layout"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: theme.textColor
                                            }
                                            Text {
                                                text: "Glide finger across letter rows continuously to spell words via FUTO neural decoding"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 11
                                                color: theme.textSecondaryColor
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        QQC2.Switch {
                                            checked: controller.swipeEnabled
                                            onToggled: controller.swipeEnabled = checked
                                        }
                                    }
                                }

                                // Card 2: Auto-Commit vs Manual Pill Tap
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 72
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1
                                    opacity: controller.swipeEnabled ? 1.0 : 0.5
                                    enabled: controller.swipeEnabled

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        VectorIcon {
                                            name: "floating"
                                            implicitWidth: 22
                                            implicitHeight: 22
                                            color: theme.textColor
                                        }

                                        ColumnLayout {
                                            spacing: 1
                                            Text {
                                                text: "Auto-Insert Top Candidate Word"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: theme.textColor
                                            }
                                            Text {
                                                text: controller.swipeAutoInsert
                                                      ? "Automatically commits top candidate + space on lift; alternative pills remain in top bar"
                                                      : "Shows candidate pills in top bar without auto-committing text until explicitly tapped"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 11
                                                color: theme.textSecondaryColor
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        QQC2.Switch {
                                            checked: controller.swipeAutoInsert
                                            onToggled: controller.swipeAutoInsert = checked
                                        }
                                    }
                                }

                                // Card 3: GPU Gesture Trail Toggle
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 72
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1
                                    opacity: controller.swipeEnabled ? 1.0 : 0.5
                                    enabled: controller.swipeEnabled

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        VectorIcon {
                                            name: "sun"
                                            implicitWidth: 22
                                            implicitHeight: 22
                                            color: theme.textColor
                                        }

                                        ColumnLayout {
                                            spacing: 1
                                            Text {
                                                text: "GPU Scene Graph Gesture Trail"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: theme.textColor
                                            }
                                            Text {
                                                text: "Renders a smooth hardware-accelerated fading touch trail following your finger at 120Hz"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 11
                                                color: theme.textSecondaryColor
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        QQC2.Switch {
                                            checked: controller.swipeTrailEnabled
                                            onToggled: controller.swipeTrailEnabled = checked
                                        }
                                    }
                                }

                                // Card 4: Trail Styling & Appearance (Sliders + Color presets)
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: trailStyleCol.implicitHeight + 28
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1
                                    opacity: (controller.swipeEnabled && controller.swipeTrailEnabled) ? 1.0 : 0.4
                                    enabled: controller.swipeEnabled && controller.swipeTrailEnabled

                                    ColumnLayout {
                                        id: trailStyleCol
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 14

                                        Text {
                                            text: "Trail Appearance & Dynamics"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                            color: theme.textColor
                                        }

                                        // Stroke Width Slider
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: "Trail Thickness"
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 12
                                                    color: theme.textColor
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: Math.round(controller.swipeStrokeWidth) + " px"
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    color: theme.keyActiveColor
                                                }
                                            }

                                            QQC2.Slider {
                                                Layout.fillWidth: true
                                                from: 4.0
                                                to: 18.0
                                                stepSize: 1.0
                                                value: controller.swipeStrokeWidth
                                                onMoved: controller.swipeStrokeWidth = value
                                            }
                                        }

                                        // Decay Duration Slider
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: "Trail Fade Decay Duration"
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 12
                                                    color: theme.textColor
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: controller.swipeDecayMs + " ms"
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    color: theme.keyActiveColor
                                                }
                                            }

                                            QQC2.Slider {
                                                Layout.fillWidth: true
                                                from: 150
                                                to: 600
                                                stepSize: 10
                                                value: controller.swipeDecayMs
                                                onMoved: controller.swipeDecayMs = value
                                            }
                                        }

                                        // Color Presets
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: "Trail Accent Color"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 12
                                                color: theme.textColor
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Repeater {
                                                    model: [
                                                        { name: "Arch Blue", hex: "#3399ff" },
                                                        { name: "Cyber Cyan", hex: "#00e5ff" },
                                                        { name: "Plasma Purple", hex: "#a855f7" },
                                                        { name: "Neon Green", hex: "#22c55e" },
                                                        { name: "Sunset Orange", hex: "#f97316" }
                                                    ]

                                                    Rectangle {
                                                        id: colorPill
                                                        implicitHeight: 32
                                                        Layout.fillWidth: true
                                                        radius: 6
                                                        color: modelData.hex
                                                        border.color: controller.swipeTrailColor.toLowerCase() === modelData.hex.toLowerCase() ? theme.textColor : "transparent"
                                                        border.width: controller.swipeTrailColor.toLowerCase() === modelData.hex.toLowerCase() ? 2 : 0

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData.name
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 11
                                                            font.weight: Font.Bold
                                                            color: "#ffffff"
                                                            style: Text.Outline
                                                            styleColor: "#40000000"
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: controller.swipeTrailColor = modelData.hex
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Card 5: Neural Engine Status & Memory Management
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: engineCol.implicitHeight + 28
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1

                                    ColumnLayout {
                                        id: engineCol
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12

                                            VectorIcon {
                                                name: "settings"
                                                implicitWidth: 20
                                                implicitHeight: 20
                                                color: theme.textColor
                                            }

                                            ColumnLayout {
                                                spacing: 1
                                                Text {
                                                    text: "FUTO Neural Engine Lifecycle & Memory"
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.Bold
                                                    color: theme.textColor
                                                }
                                                Text {
                                                    text: "Honorable Sturgeon encoder + Magic Macaw decoder + Hungry Jellyfish LM"
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 11
                                                    color: theme.textSecondaryColor
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            // Status Badge
                                            Rectangle {
                                                implicitWidth: stateText.implicitWidth + 16
                                                implicitHeight: 26
                                                radius: 13
                                                color: controller.swipeEngineState === "Ready"
                                                       ? (theme.isDark ? "#1B432C" : "#D4EDDA")
                                                       : (controller.swipeEngineState === "Loading"
                                                          ? (theme.isDark ? "#4B3D1B" : "#FFF3CD")
                                                          : (theme.isDark ? "#2D3035" : "#E2E3E5"))
                                                border.color: controller.swipeEngineState === "Ready"
                                                              ? "#28A745"
                                                              : (controller.swipeEngineState === "Loading" ? "#FFC107" : "#6C757D")
                                                border.width: 1

                                                Text {
                                                    id: stateText
                                                    anchors.centerIn: parent
                                                    text: "● " + controller.swipeEngineState
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    color: controller.swipeEngineState === "Ready"
                                                           ? "#28A745"
                                                           : (controller.swipeEngineState === "Loading" ? "#856404" : "#6C757D")
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 1
                                            color: theme.dividerColor
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12

                                            Text {
                                                text: "Resident Memory (PSS):"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 12
                                                color: theme.textColor
                                            }

                                            Text {
                                                text: (controller.swipeMemoryPssKiB > 0)
                                                      ? Math.round(controller.swipeMemoryPssKiB / 1024.0) + " MiB (" + controller.swipeMemoryPssKiB + " KiB)"
                                                      : "0 MiB (Standby)"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: theme.textColor
                                            }

                                            Item { Layout.fillWidth: true }

                                            QQC2.Button {
                                                text: "Unload Engine"
                                                enabled: controller.swipeEngineState === "Ready"
                                                onClicked: controller.unloadSwipeEngine()
                                            }

                                            QQC2.Button {
                                                text: "Reload Engine"
                                                enabled: controller.swipeEngineState !== "Ready"
                                                onClicked: controller.loadSwipeEngine()
                                            }
                                        }
                                    }
                                }

                                // Card 6: Compositor Protocol Diagnostic
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: diagCol.implicitHeight + 24
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1

                                    ColumnLayout {
                                        id: diagCol
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 8

                                        Text {
                                            text: "Compositor Protocol Diagnostic"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                            color: theme.textColor
                                        }

                                        Text {
                                            text: "• Wayland Protocol: zwp_input_method_v1 (Active on KWin Wayland)\n" +
                                                  "• Text Commit: UTF-8 commit_string & delete_surrounding_text\n" +
                                                  "• LayerShell Surface: KeyboardInteractivityNone (zero focus stealing)\n" +
                                                  "• Security & Privacy: Automatic suppression in password/PIN/terminal fields"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            color: theme.textSecondaryColor
                                            lineHeight: 1.4
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ==========================================
                    // VIEW 4: TOP BAR QUICK PINS
                    // ==========================================
                    Item {
                        id: viewPins
                        Flickable {
                            anchors.fill: parent
                            contentHeight: pinCol.height + 32
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            ColumnLayout {
                                id: pinCol
                                width: parent.width - (root.narrowLayout ? 24 : 40)
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 16
                                spacing: 16

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: pinCardCol.implicitHeight + 28
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1

                                    ColumnLayout {
                                        id: pinCardCol
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        Text {
                                            text: "Keyboard Top Header Bar Quick Pins"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            color: theme.textColor
                                        }

                                        Text {
                                            text: "Choose which tools and toggles appear directly on the virtual keyboard's top header bar:"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            color: theme.textSecondaryColor
                                        }

                                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: theme.dividerColor }

                                        // Pin Quick-Pad
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12
                                            VectorIcon { name: "quickpad"; implicitWidth: 20; implicitHeight: 20; color: theme.textColor }
                                            ColumnLayout {
                                                spacing: 1
                                                Text { text: "Quick-Pad Launcher (⚡)"; font.family: theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: theme.textColor }
                                                Text { text: "Shows 4-quadrant icon in top bar to launch popup macro pad"; font.family: theme.fontFamily; font.pixelSize: 10; color: theme.textSecondaryColor }
                                            }
                                            Item { Layout.fillWidth: true }
                                            QQC2.Switch {
                                                checked: controller.quickPadPinned
                                                onToggled: controller.quickPadPinned = checked
                                            }
                                        }

                                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: theme.dividerColor }

                                        // Pin Split Mode
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12
                                            VectorIcon { name: "split"; implicitWidth: 20; implicitHeight: 20; color: theme.textColor }
                                            ColumnLayout {
                                                spacing: 1
                                                Text { text: "Split Thumb Mode Switcher"; font.family: theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: theme.textColor }
                                                Text { text: "Shows split toggle button in landscape mode"; font.family: theme.fontFamily; font.pixelSize: 10; color: theme.textSecondaryColor }
                                            }
                                            Item { Layout.fillWidth: true }
                                            QQC2.Switch {
                                                checked: controller.splitPinned
                                                onToggled: controller.splitPinned = checked
                                            }
                                        }

                                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: theme.dividerColor }

                                        // Pin Theme Mode
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12
                                            VectorIcon { name: "theme-system"; implicitWidth: 20; implicitHeight: 20; color: theme.textColor }
                                            ColumnLayout {
                                                spacing: 1
                                                Text { text: "Theme Mode Switcher"; font.family: theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: theme.textColor }
                                                Text { text: "Shows Auto / Sun / Moon theme cycle button"; font.family: theme.fontFamily; font.pixelSize: 10; color: theme.textSecondaryColor }
                                            }
                                            Item { Layout.fillWidth: true }
                                            QQC2.Switch {
                                                checked: controller.themePinned
                                                onToggled: controller.themePinned = checked
                                            }
                                        }

                                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: theme.dividerColor }

                                        // Pin Audio Feedback
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12
                                            VectorIcon { name: "volume-on"; implicitWidth: 20; implicitHeight: 20; color: theme.textColor }
                                            ColumnLayout {
                                                spacing: 1
                                                Text { text: "Keypress Audio Feedback Toggle"; font.family: theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: theme.textColor }
                                                Text { text: "Shows speaker button to mute or unmute click audio directly"; font.family: theme.fontFamily; font.pixelSize: 10; color: theme.textSecondaryColor }
                                            }
                                            Item { Layout.fillWidth: true }
                                            QQC2.Switch {
                                                checked: controller.soundPinned
                                                onToggled: controller.soundPinned = checked
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ==========================================
                    // VIEW 5: INPUT TIMING
                    // ==========================================
                    Item {
                        id: viewInputTiming
                        Flickable {
                            anchors.fill: parent
                            contentHeight: timingCol.height + 32
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            ColumnLayout {
                                id: timingCol
                                width: parent.width - (root.narrowLayout ? 24 : 40)
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 16
                                spacing: 16

                                // Card 1: Long Press Hold Delay
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: holdCardCol.implicitHeight + 28
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1

                                    ColumnLayout {
                                        id: holdCardCol
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "Long-Press Hold Delay"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                color: theme.textColor
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: controller.longPressDelay + " ms"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                color: theme.keyActiveColor
                                            }
                                        }

                                        Text {
                                            text: "Duration to hold a key before triggering its secondary symbol or alternate action:"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            color: theme.textSecondaryColor
                                        }

                                        QQC2.Slider {
                                            Layout.fillWidth: true
                                            from: 150
                                            to: 1000
                                            stepSize: 25
                                            value: controller.longPressDelay
                                            onMoved: controller.longPressDelay = value
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Repeater {
                                                model: [
                                                    { label: "250 ms (Fast)", val: 250 },
                                                    { label: "350 ms (Standard)", val: 350 },
                                                    { label: "450 ms (Relaxed)", val: 450 }
                                                ]

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    implicitHeight: 30
                                                    radius: theme.keyRadius
                                                    color: controller.longPressDelay === modelData.val ? theme.keyActiveColor : theme.keySpecialColor
                                                    border.color: controller.longPressDelay === modelData.val ? theme.keyActiveColor : theme.borderColor
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.label
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 11
                                                        font.weight: controller.longPressDelay === modelData.val ? Font.Bold : Font.Normal
                                                        color: controller.longPressDelay === modelData.val ? "#FFFFFF" : theme.textColor
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: controller.longPressDelay = modelData.val
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                            }
                        }
                    }

                    // ==========================================
                    // VIEW 6: SYSTEM & DIAGNOSTICS
                    // ==========================================
                    Item {
                        id: viewSystem
                        Flickable {
                            anchors.fill: parent
                            contentHeight: sysCol.height + 32
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            ColumnLayout {
                                id: sysCol
                                width: parent.width - (root.narrowLayout ? 24 : 40)
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 16
                                spacing: 16

                                // Card 1: Subsystem Diagnostics
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: diagCardCol.implicitHeight + 28
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1

                                    ColumnLayout {
                                        id: diagCardCol
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 10

                                        Text {
                                            text: "System & Architecture Diagnostics"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            color: theme.textColor
                                        }

                                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: theme.dividerColor }

                                        component DiagRow: RowLayout {
                                            property string label: ""
                                            property string value: ""
                                            property bool isStatus: false
                                            Layout.fillWidth: true
                                            Text { text: label; font.family: theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: theme.textSecondaryColor; Layout.preferredWidth: 200 }
                                            Text { text: value; font.family: "monospace"; font.pixelSize: 11; font.weight: Font.Bold; color: isStatus ? (controller.daemonConnected ? "#22C55E" : "#EF4444") : theme.textColor }
                                        }

                                        DiagRow { label: "Component:"; value: "archpad-keyboard" }
                                        DiagRow { label: "Session Integration:"; value: "KWin VirtualKeyboard D-Bus (current backend)" }
                                        DiagRow { label: "Surface Protocol:"; value: "LayerShellQt (zwlr_layer_surface_v1)" }
                                        DiagRow { label: "Focus Interactivity:"; value: "KeyboardInteractivityNone" }
                                        DiagRow { label: "Linux Hardware Injection:"; value: "/dev/uinput (Linux Event Subsystem)" }
                                        DiagRow { label: "D-Bus Service:"; value: "org.archpad.Keyboard"; isStatus: true }
                                        DiagRow { label: "Configuration File:"; value: "~/.config/archpad/keyboard.conf" }
                                    }
                                }

                                // Card 2: Restore Factory Defaults
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: resetCol.implicitHeight + 28
                                    radius: theme.cardRadius
                                    color: theme.surfaceColor
                                    border.color: theme.borderColor
                                    border.width: 1

                                    ColumnLayout {
                                        id: resetCol
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        Text {
                                            text: "Restore Factory Defaults"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            color: theme.textColor
                                        }

                                        Text {
                                            text: "Reset all keyboard preferences, theme modes, scaling, Quick-Pad macros, and toolbar pins back to default settings."
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            color: theme.textSecondaryColor
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Item { Layout.fillWidth: true }

                                            Rectangle {
                                                implicitWidth: 180
                                                implicitHeight: 36
                                                radius: theme.keyRadius
                                                color: resetArea.pressed ? theme.keyPressedColor : (theme.isDark ? "#7F1D1D" : "#FEE2E2")
                                                border.color: theme.isDark ? "#B91C1C" : "#FCA5A5"
                                                border.width: 1

                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 6
                                                    VectorIcon { name: "close"; implicitWidth: 14; implicitHeight: 14; color: theme.isDark ? "#F87171" : "#B91C1C" }
                                                    Text {
                                                        text: "Restore Defaults"
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 12
                                                        font.weight: Font.Bold
                                                        color: theme.isDark ? "#F87171" : "#B91C1C"
                                                    }
                                                }

                                                MouseArea {
                                                    id: resetArea
                                                    anchors.fill: parent
                                                    onClicked: controller.resetToDefaults()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
