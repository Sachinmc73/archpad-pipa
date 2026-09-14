import QtQuick
import QtQuick.Layouts
import QtCore
import org.kde.kirigami as Kirigami

Item {
    id: root

    required property Item screenRoot
    required property var mainStack
    required property Item mainBlock
    required property var passwordField

    readonly property bool keyboardActive: state === "visible"
    readonly property int status: 1 // Loader.Ready = 1

    property bool shiftActive: false
    property bool capsLockActive: false
    property bool symbolMode: false

    readonly property bool isShifted: shiftActive || capsLockActive

    function showHide() {
        state = (state === "hidden") ? "visible" : "hidden";
    }

    function l(char) {
        return isShifted ? char.toUpperCase() : char.toLowerCase();
    }

    function sendChar(c) {
        if (!passwordField) return;
        var pos = passwordField.cursorPosition;
        passwordField.insert(pos, c);
        if (shiftActive && !capsLockActive) {
            shiftActive = false;
        }
        passwordField.forceActiveFocus();
    }

    function sendBackspace() {
        if (!passwordField) return;
        var pos = passwordField.cursorPosition;
        if (pos > 0) {
            passwordField.remove(pos - 1, pos);
        }
        passwordField.forceActiveFocus();
    }

    function sendEnter() {
        if (!passwordField) return;
        passwordField.accepted();
    }

    // Theme resolution synchronized with ~/.config/archpad/keyboard.conf & system theme
    Settings {
        id: archpadSettings
        category: "General"
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/archpad/keyboard.conf"
        property bool resolvedDark: false
    }

    readonly property bool isDark: archpadSettings.resolvedDark

    QtObject {
        id: lockTheme
        readonly property bool isDark: root.isDark

        // Surface & Window Colors
        readonly property color backgroundColor: isDark ? "#14171A" : "#FFFFFF"
        readonly property color surfaceColor: isDark ? "#1C1F24" : "#FFFFFF"
        readonly property color headerColor: isDark ? "#181B20" : "#F4F5F7"
        readonly property color borderColor: isDark ? "#282D34" : "#D1D5DB"
        readonly property color dividerColor: isDark ? "#22262C" : "#E5E7EB"

        // Key Colors
        readonly property color keyColor: isDark ? "#242830" : "#E5E7EB"
        readonly property color keySpecialColor: isDark ? "#1C2026" : "#D1D5DB"
        readonly property color keyPressedColor: isDark ? "#363C47" : "#9CA3AF"
        readonly property color keyActiveColor: isDark ? "#2F81F7" : "#1A73E8"
        readonly property color keyAccentColor: isDark ? "#238636" : "#1E8E3E"
        readonly property color keyDeleteColor: isDark ? "#30363D" : "#D1D5DB"

        // Typography
        readonly property color textColor: isDark ? "#F0F6FC" : "#111827"
        readonly property color textSecondaryColor: isDark ? "#8B949E" : "#4B5563"
        readonly property color textDimColor: isDark ? "#586069" : "#6B7280"
        readonly property color textActiveColor: "#FFFFFF"

        readonly property string fontFamily: "Inter, Noto Sans, Cantarell, sans-serif"
        readonly property int fontSizeNormal: 16
        readonly property int fontSizeSmall: 11
        readonly property int fontSizeHeader: 13
        readonly property int fontSizeLarge: 18

        readonly property real keyRadius: 6
        readonly property real keyMargin: 2
        readonly property real headerHeight: 28
    }

    anchors {
        left: parent.left
        right: parent.right
    }

    height: (screenRoot.width > screenRoot.height) ? 290 : 340
    state: (screenRoot && screenRoot.uiVisible) ? "visible" : "hidden"

    // Synchronize visibility with screen lock UI
    Connections {
        target: screenRoot
        function onUiVisibleChanged() {
            if (screenRoot.uiVisible) {
                root.state = "visible";
            } else {
                root.state = "hidden";
            }
        }
    }

    // Auto-show when password field is clicked / focused
    Connections {
        target: passwordField
        function onActiveFocusChanged() {
            if (passwordField && passwordField.activeFocus && screenRoot && screenRoot.uiVisible && root.state === "hidden") {
                root.state = "visible";
            }
        }
    }

    states: [
        State {
            name: "visible"
            PropertyChanges {
                target: mainStack
                y: Math.min(0, screenRoot.height - root.height - (mainBlock.visibleBoundary || 110))
            }
            PropertyChanges {
                target: root
                y: screenRoot.height - root.height
                opacity: 1
                visible: true
            }
        },
        State {
            name: "hidden"
            PropertyChanges {
                target: mainStack
                y: 0
            }
            PropertyChanges {
                target: root
                y: screenRoot.height
                opacity: 0
                visible: false
            }
        }
    ]

    transitions: [
        Transition {
            from: "hidden"
            to: "visible"
            ParallelAnimation {
                NumberAnimation {
                    target: mainStack
                    property: "y"
                    duration: 220
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: root
                    properties: "y,opacity"
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
        },
        Transition {
            from: "visible"
            to: "hidden"
            ParallelAnimation {
                NumberAnimation {
                    target: mainStack
                    property: "y"
                    duration: 180
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: root
                    properties: "y,opacity"
                    duration: 180
                    easing.type: Easing.InCubic
                }
            }
        }
    ]

    // Modular Key Component
    component LockKeyButton: Item {
        id: keyItem
        property string text: ""
        property string secondaryText: ""
        property var customKeyColor: null
        property var customTextColor: null
        property real weight: 1.0
        property bool isAccent: false
        property bool autoRepeat: false
        property int customFontSize: 0

        readonly property color finalKeyColor: customKeyColor !== null ? customKeyColor : (keyItem.isAccent ? lockTheme.keyAccentColor : lockTheme.keyColor)
        readonly property color finalTextColor: customTextColor !== null ? customTextColor : (keyItem.isAccent ? "#FFFFFF" : lockTheme.textColor)
        readonly property int finalFontSize: customFontSize > 0 ? customFontSize : lockTheme.fontSizeNormal

        signal clicked()
        signal held()

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: weight * 100

        Rectangle {
            id: kbg
            anchors.fill: parent
            anchors.margins: lockTheme.keyMargin
            radius: lockTheme.keyRadius
            color: ktouch.pressed ? lockTheme.keyPressedColor : keyItem.finalKeyColor
            border.color: lockTheme.borderColor
            border.width: 1

            scale: ktouch.pressed ? 0.94 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
            }

            Text {
                visible: keyItem.secondaryText !== ""
                text: keyItem.secondaryText
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 3
                font.family: lockTheme.fontFamily
                font.pixelSize: lockTheme.fontSizeSmall
                font.weight: Font.DemiBold
                color: lockTheme.textSecondaryColor
            }

            Text {
                text: keyItem.text
                anchors.centerIn: parent
                font.family: lockTheme.fontFamily
                font.pixelSize: keyItem.finalFontSize
                font.weight: keyItem.isAccent ? Font.DemiBold : Font.Normal
                color: keyItem.finalTextColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                id: ktouch
                anchors.fill: parent
                preventStealing: true
                pressAndHoldInterval: 380
                property bool longPressed: false

                Timer {
                    id: kRepeat
                    interval: 380
                    repeat: true
                    running: keyItem.autoRepeat && ktouch.pressed
                    onTriggered: {
                        interval = 50;
                        keyItem.clicked();
                    }
                }

                onPressAndHold: {
                    if (keyItem.secondaryText !== "") {
                        ktouch.longPressed = true;
                        keyItem.held();
                    }
                }

                onClicked: {
                    if (!ktouch.longPressed) {
                        keyItem.clicked();
                    }
                    ktouch.longPressed = false;
                }
            }
        }
    }

    // Modifier Key Component (Shift / CapsLock)
    component LockModifierKey: Item {
        id: modItem
        property string text: ""
        property bool active: false
        property bool isLocked: false
        property real weight: 1.0
        property int customFontSize: 0

        readonly property int finalFontSize: customFontSize > 0 ? customFontSize : lockTheme.fontSizeNormal

        signal clicked()

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: weight * 100

        Rectangle {
            id: mbg
            anchors.fill: parent
            anchors.margins: lockTheme.keyMargin
            radius: lockTheme.keyRadius
            color: modItem.active ? lockTheme.keyActiveColor : (mtouch.pressed ? lockTheme.keyPressedColor : lockTheme.keySpecialColor)
            border.color: modItem.active ? Qt.lighter(lockTheme.keyActiveColor, 1.2) : lockTheme.borderColor
            border.width: modItem.active ? 1.5 : 1

            scale: mtouch.pressed ? 0.94 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
            }

            Rectangle {
                visible: modItem.isLocked
                width: 6
                height: 6
                radius: 3
                color: "#00FF66"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 4
            }

            Text {
                text: modItem.text
                anchors.centerIn: parent
                font.family: lockTheme.fontFamily
                font.pixelSize: modItem.finalFontSize
                font.weight: modItem.active ? Font.DemiBold : Font.Normal
                color: modItem.active ? lockTheme.textActiveColor : lockTheme.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                id: mtouch
                anchors.fill: parent
                preventStealing: true
                onClicked: modItem.clicked()
            }
        }
    }

    // Keyboard Main Card
    Rectangle {
        anchors.fill: parent
        color: lockTheme.backgroundColor
        border.color: lockTheme.borderColor
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 2

            // Minimal Header Bar
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: lockTheme.headerHeight
                Layout.maximumHeight: lockTheme.headerHeight
                Layout.leftMargin: 10
                Layout.rightMargin: 6
                spacing: 6

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: lockTheme.keyActiveColor
                }

                Text {
                    text: "ArchPad"
                    font.family: lockTheme.fontFamily
                    font.pixelSize: lockTheme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: lockTheme.textSecondaryColor
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 32
                    height: 22
                    radius: lockTheme.keyRadius
                    color: hideMouse.pressed ? lockTheme.keyPressedColor : "transparent"
                    border.color: lockTheme.borderColor
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "▾"
                        font.pixelSize: 14
                        color: lockTheme.textSecondaryColor
                    }

                    MouseArea {
                        id: hideMouse
                        anchors.fill: parent
                        onClicked: root.state = "hidden"
                    }
                }
            }

            // Keyboard Layout: 5 Rows matching Portrait Mode
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2

                // Row 1: Numbers Bar at Top
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 1

                    LockKeyButton { text: "1"; secondaryText: "!"; weight: 1.0; onClicked: root.sendChar(root.isShifted ? "!" : "1"); onHeld: root.sendChar("!") }
                    LockKeyButton { text: "2"; secondaryText: "@"; weight: 1.0; onClicked: root.sendChar(root.isShifted ? "@" : "2"); onHeld: root.sendChar("@") }
                    LockKeyButton { text: "3"; secondaryText: "#"; weight: 1.0; onClicked: root.sendChar(root.isShifted ? "#" : "3"); onHeld: root.sendChar("#") }
                    LockKeyButton { text: "4"; secondaryText: "$"; weight: 1.0; onClicked: root.sendChar(root.isShifted ? "$" : "4"); onHeld: root.sendChar("$") }
                    LockKeyButton { text: "5"; secondaryText: "%"; weight: 1.0; onClicked: root.sendChar(root.isShifted ? "%" : "5"); onHeld: root.sendChar("%") }
                    LockKeyButton { text: "6"; secondaryText: "^"; weight: 1.0; onClicked: root.sendChar(root.isShifted ? "^" : "6"); onHeld: root.sendChar("^") }
                    LockKeyButton { text: "7"; secondaryText: "&"; weight: 1.0; onClicked: root.sendChar(root.isShifted ? "&" : "7"); onHeld: root.sendChar("&") }
                    LockKeyButton { text: "8"; secondaryText: "*"; weight: 1.0; onClicked: root.sendChar(root.isShifted ? "*" : "8"); onHeld: root.sendChar("*") }
                    LockKeyButton { text: "9"; secondaryText: "("; weight: 1.0; onClicked: root.sendChar(root.isShifted ? "(" : "9"); onHeld: root.sendChar("(") }
                    LockKeyButton { text: "0"; secondaryText: ")"; weight: 1.0; onClicked: root.sendChar(root.isShifted ? ")" : "0"); onHeld: root.sendChar(")") }
                }

                // Row 2: Q W E R T Y U I O P
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 1

                    LockKeyButton { text: root.symbolMode ? "+" : root.l("q"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "+" : root.l("q")) }
                    LockKeyButton { text: root.symbolMode ? "×" : root.l("w"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "*" : root.l("w")) }
                    LockKeyButton { text: root.symbolMode ? "÷" : root.l("e"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "/" : root.l("e")) }
                    LockKeyButton { text: root.symbolMode ? "=" : root.l("r"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "=" : root.l("r")) }
                    LockKeyButton { text: root.symbolMode ? "/" : root.l("t"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "/" : root.l("t")) }
                    LockKeyButton { text: root.symbolMode ? "_" : root.l("y"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "_" : root.l("y")) }
                    LockKeyButton { text: root.symbolMode ? "<" : root.l("u"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "<" : root.l("u")) }
                    LockKeyButton { text: root.symbolMode ? ">" : root.l("i"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? ">" : root.l("i")) }
                    LockKeyButton { text: root.symbolMode ? "[" : root.l("o"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "[" : root.l("o")) }
                    LockKeyButton { text: root.symbolMode ? "]" : root.l("p"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "]" : root.l("p")) }
                }

                // Row 3: A S D F G H J K L
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 1

                    Item { Layout.preferredWidth: 16; Layout.fillHeight: true }
                    LockKeyButton { text: root.symbolMode ? "!" : root.l("a"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "!" : root.l("a")) }
                    LockKeyButton { text: root.symbolMode ? "@" : root.l("s"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "@" : root.l("s")) }
                    LockKeyButton { text: root.symbolMode ? "#" : root.l("d"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "#" : root.l("d")) }
                    LockKeyButton { text: root.symbolMode ? "$" : root.l("f"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "$" : root.l("f")) }
                    LockKeyButton { text: root.symbolMode ? "%" : root.l("g"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "%" : root.l("g")) }
                    LockKeyButton { text: root.symbolMode ? "^" : root.l("h"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "^" : root.l("h")) }
                    LockKeyButton { text: root.symbolMode ? "&" : root.l("j"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "&" : root.l("j")) }
                    LockKeyButton { text: root.symbolMode ? "*" : root.l("k"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "*" : root.l("k")) }
                    LockKeyButton { text: root.symbolMode ? "(" : root.l("l"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "(" : root.l("l")) }
                    Item { Layout.preferredWidth: 16; Layout.fillHeight: true }
                }

                // Row 4: Shift, Z X C V B N M, Backspace
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 1

                    LockModifierKey {
                        text: "⇧"
                        weight: 1.4
                        active: root.shiftActive
                        isLocked: root.capsLockActive
                        customFontSize: lockTheme.fontSizeLarge
                        onClicked: {
                            if (root.capsLockActive) {
                                root.capsLockActive = false;
                                root.shiftActive = false;
                            } else if (root.shiftActive) {
                                root.capsLockActive = true;
                            } else {
                                root.shiftActive = true;
                            }
                        }
                    }

                    LockKeyButton { text: root.symbolMode ? "`" : root.l("z"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "`" : root.l("z")) }
                    LockKeyButton { text: root.symbolMode ? "~" : root.l("x"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "~" : root.l("x")) }
                    LockKeyButton { text: root.symbolMode ? "{" : root.l("c"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "{" : root.l("c")) }
                    LockKeyButton { text: root.symbolMode ? "}" : root.l("v"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "}" : root.l("v")) }
                    LockKeyButton { text: root.symbolMode ? ":" : root.l("b"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? ":" : root.l("b")) }
                    LockKeyButton { text: root.symbolMode ? ";" : root.l("n"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? ";" : root.l("n")) }
                    LockKeyButton { text: root.symbolMode ? "'" : root.l("m"); weight: 1.0; onClicked: root.sendChar(root.symbolMode ? "'" : root.l("m")) }

                    LockKeyButton {
                        text: "⌫"
                        weight: 1.4
                        autoRepeat: true
                        customKeyColor: lockTheme.keyDeleteColor
                        customFontSize: lockTheme.fontSizeLarge
                        onClicked: root.sendBackspace()
                    }
                }

                // Row 5: ?123, Comma, Space, Period, Enter/Unlock
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 1

                    LockKeyButton {
                        text: root.symbolMode ? "ABC" : "?123"
                        weight: 1.4
                        customKeyColor: lockTheme.keySpecialColor
                        customFontSize: lockTheme.fontSizeSmall
                        onClicked: root.symbolMode = !root.symbolMode
                    }

                    LockKeyButton {
                        text: ","
                        weight: 1.0
                        customFontSize: lockTheme.fontSizeLarge
                        onClicked: root.sendChar(",")
                    }

                    LockKeyButton {
                        text: "Space"
                        weight: 4.8
                        autoRepeat: true
                        customKeyColor: lockTheme.keyColor
                        customFontSize: lockTheme.fontSizeSmall
                        customTextColor: lockTheme.textSecondaryColor
                        onClicked: root.sendChar(" ")
                    }

                    LockKeyButton {
                        text: "."
                        weight: 1.0
                        customFontSize: lockTheme.fontSizeLarge
                        onClicked: root.sendChar(".")
                    }

                    LockKeyButton {
                        text: "↵"
                        weight: 1.8
                        isAccent: true
                        customFontSize: lockTheme.fontSizeLarge
                        onClicked: root.sendEnter()
                    }
                }
            }
        }
    }
}
