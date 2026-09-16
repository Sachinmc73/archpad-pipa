import QtQuick
import QtQuick.Layouts
import "../components"

ColumnLayout {
    id: root
    spacing: 3
    anchors.fill: parent
    anchors.margins: 4
    anchors.leftMargin: 8
    anchors.rightMargin: 8

    readonly property bool isShifted: km.shiftActive
    readonly property bool isLetterUpper: km.shiftActive ? !km.capsLockActive : km.capsLockActive
    property bool symbolMode: false

    function l(letter) {
        return isLetterUpper ? letter.toUpperCase() : letter.toLowerCase()
    }

    readonly property real clusterWidth: Math.min(365, (root.width - 120) / 2)

    // Row 0: Linux / Terminal Special Key Strip (6 Left | 6 Right)
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        Layout.maximumHeight: 32
        Layout.fillHeight: false
        spacing: 0

        // Left Cluster
        RowLayout {
            Layout.preferredWidth: root.clusterWidth
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2

            KeyButton { text: "Esc"; weight: 1.0; customKeyColor: theme.keySpecialColor; customFontSize: theme.fontSizeSmall; onClicked: km.tapNavKey("Esc") }
            KeyButton { text: "Tab"; weight: 1.0; customKeyColor: theme.keySpecialColor; customFontSize: theme.fontSizeSmall; onClicked: km.tapNavKey("Tab") }
            ModifierKey { text: "Ctrl"; weight: 1.0; active: km.ctrlActive; customFontSize: theme.fontSizeSmall; onClicked: km.ctrlActive = !km.ctrlActive }
            ModifierKey { text: "Alt"; weight: 1.0; active: km.altActive; customFontSize: theme.fontSizeSmall; onClicked: km.altActive = !km.altActive }
            KeyButton { text: "|"; weight: 1.0; customKeyColor: theme.keySpecialColor; onClicked: km.tapSymbol("|") }
            KeyButton { text: "~"; weight: 1.0; customKeyColor: theme.keySpecialColor; onClicked: km.tapSymbol("~") }
        }

        // Center Ergonomic Thumb Gap
        Item { Layout.fillWidth: true }

        // Right Cluster
        RowLayout {
            Layout.preferredWidth: root.clusterWidth
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2

            KeyButton { text: "\\"; weight: 1.0; customKeyColor: theme.keySpecialColor; onClicked: km.tapSymbol("\\") }
            KeyButton { text: "/"; weight: 1.0; customKeyColor: theme.keySpecialColor; onClicked: km.tapSymbol("/") }
            KeyButton { iconName: "arrow-left"; weight: 1.0; autoRepeat: true; customKeyColor: theme.keySpecialColor; onClicked: km.tapNavKey("Left") }
            KeyButton { iconName: "arrow-up"; weight: 1.0; autoRepeat: true; customKeyColor: theme.keySpecialColor; onClicked: km.tapNavKey("Up") }
            KeyButton { iconName: "arrow-down"; weight: 1.0; autoRepeat: true; customKeyColor: theme.keySpecialColor; onClicked: km.tapNavKey("Down") }
            KeyButton { iconName: "arrow-right"; weight: 1.0; autoRepeat: true; customKeyColor: theme.keySpecialColor; onClicked: km.tapNavKey("Right") }
        }
    }

    // Row 1: Numbers Strip (5 Left | 5 Right)
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        Layout.maximumHeight: 38
        Layout.fillHeight: false
        spacing: 0

        // Left Numbers 1-5
        RowLayout {
            Layout.preferredWidth: root.clusterWidth
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2

            KeyButton { text: "1"; secondaryText: "!"; weight: 1.0; onClicked: km.tapSymbol("1"); onHeld: km.tapSymbol("!") }
            KeyButton { text: "2"; secondaryText: "@"; weight: 1.0; onClicked: km.tapSymbol("2"); onHeld: km.tapSymbol("@") }
            KeyButton { text: "3"; secondaryText: "#"; weight: 1.0; onClicked: km.tapSymbol("3"); onHeld: km.tapSymbol("#") }
            KeyButton { text: "4"; secondaryText: "$"; weight: 1.0; onClicked: km.tapSymbol("4"); onHeld: km.tapSymbol("$") }
            KeyButton { text: "5"; secondaryText: "%"; weight: 1.0; onClicked: km.tapSymbol("5"); onHeld: km.tapSymbol("%") }
        }

        // Center Ergonomic Thumb Gap
        Item { Layout.fillWidth: true }

        // Right Numbers 6-0
        RowLayout {
            Layout.preferredWidth: root.clusterWidth
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2

            KeyButton { text: "6"; secondaryText: "^"; weight: 1.0; onClicked: km.tapSymbol("6"); onHeld: km.tapSymbol("^") }
            KeyButton { text: "7"; secondaryText: "&"; weight: 1.0; onClicked: km.tapSymbol("7"); onHeld: km.tapSymbol("&") }
            KeyButton { text: "8"; secondaryText: "*"; weight: 1.0; onClicked: km.tapSymbol("8"); onHeld: km.tapSymbol("*") }
            KeyButton { text: "9"; secondaryText: "("; weight: 1.0; onClicked: km.tapSymbol("9"); onHeld: km.tapSymbol("(") }
            KeyButton { text: "0"; secondaryText: ")"; weight: 1.0; onClicked: km.tapSymbol("0"); onHeld: km.tapSymbol(")") }
        }
    }

    // Row 2: Q W E R T | Y U I O P
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        RowLayout {
            Layout.preferredWidth: root.clusterWidth
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2

            KeyButton { text: root.symbolMode ? "+" : root.l("q"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "+" : root.l("q")) }
            KeyButton { text: root.symbolMode ? "×" : root.l("w"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "*" : root.l("w")) }
            KeyButton { text: root.symbolMode ? "÷" : root.l("e"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "/" : root.l("e")) }
            KeyButton { text: root.symbolMode ? "=" : root.l("r"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "=" : root.l("r")) }
            KeyButton { text: root.symbolMode ? "/" : root.l("t"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "/" : root.l("t")) }
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            Layout.preferredWidth: root.clusterWidth
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2

            KeyButton { text: root.symbolMode ? "_" : root.l("y"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "_" : root.l("y")) }
            KeyButton { text: root.symbolMode ? "<" : root.l("u"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "<" : root.l("u")) }
            KeyButton { text: root.symbolMode ? ">" : root.l("i"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? ">" : root.l("i")) }
            KeyButton { text: root.symbolMode ? "[" : root.l("o"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "[" : root.l("o")) }
            KeyButton { text: root.symbolMode ? "]" : root.l("p"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "]" : root.l("p")) }
        }
    }

    // Row 3: A S D F G | G H J K L (Duplicated 'G')
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        RowLayout {
            Layout.preferredWidth: root.clusterWidth
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2

            KeyButton { text: root.symbolMode ? "!" : root.l("a"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "!" : root.l("a")) }
            KeyButton { text: root.symbolMode ? "@" : root.l("s"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "@" : root.l("s")) }
            KeyButton { text: root.symbolMode ? "#" : root.l("d"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "#" : root.l("d")) }
            KeyButton { text: root.symbolMode ? "$" : root.l("f"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "$" : root.l("f")) }
            KeyButton { text: root.symbolMode ? "%" : root.l("g"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "%" : root.l("g")) }
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            Layout.preferredWidth: root.clusterWidth
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2

            KeyButton { text: root.symbolMode ? "%" : root.l("g"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "%" : root.l("g")) }
            KeyButton { text: root.symbolMode ? "^" : root.l("h"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "^" : root.l("h")) }
            KeyButton { text: root.symbolMode ? "&" : root.l("j"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "&" : root.l("j")) }
            KeyButton { text: root.symbolMode ? "*" : root.l("k"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "*" : root.l("k")) }
            KeyButton { text: root.symbolMode ? "(" : root.l("l"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "(" : root.l("l")) }
        }
    }

    // Row 4: ⇧ Z X C V | V B N M ⌫ (Duplicated 'V')
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        RowLayout {
            Layout.preferredWidth: root.clusterWidth
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2

            ModifierKey {
                text: "⇧"
                weight: 1.25
                active: km.shiftActive
                isLocked: km.capsLockActive
                customFontSize: theme.fontSizeLarge
                onClicked: {
                    if (km.capsLockActive) {
                        km.capsLockActive = false
                        km.shiftActive = false
                    } else if (km.shiftActive) {
                        km.capsLockActive = true
                    } else {
                        km.shiftActive = true
                    }
                }
            }
            KeyButton { text: root.symbolMode ? "`" : root.l("z"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "`" : root.l("z")) }
            KeyButton { text: root.symbolMode ? "~" : root.l("x"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "~" : root.l("x")) }
            KeyButton { text: root.symbolMode ? "{" : root.l("c"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "{" : root.l("c")) }
            KeyButton { text: root.symbolMode ? "}" : root.l("v"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "}" : root.l("v")) }
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            Layout.preferredWidth: root.clusterWidth
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2

            KeyButton { text: root.symbolMode ? "}" : root.l("v"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "}" : root.l("v")) }
            KeyButton { text: root.symbolMode ? ":" : root.l("b"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? ":" : root.l("b")) }
            KeyButton { text: root.symbolMode ? ";" : root.l("n"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? ";" : root.l("n")) }
            KeyButton { text: root.symbolMode ? "'" : root.l("m"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "'" : root.l("m")) }
            KeyButton {
                text: "⌫"
                weight: 1.25
                autoRepeat: true
                customKeyColor: theme.keyDeleteColor
                customFontSize: theme.fontSizeLarge
                onClicked: km.tapNavKey("Backspace")
            }
        }
    }

    // Row 5: ?123, Comma, Left Space | Right Space, Period, Enter
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        RowLayout {
            Layout.preferredWidth: root.clusterWidth
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2

            KeyButton {
                text: root.symbolMode ? "ABC" : "?123"
                weight: 1.25
                customKeyColor: theme.keySpecialColor
                customFontSize: theme.fontSizeSmall
                onClicked: {
                    km.playClick()
                    root.symbolMode = !root.symbolMode
                }
            }
            KeyButton {
                text: ","
                weight: 1.0
                customFontSize: theme.fontSizeLarge
                onClicked: km.tapSymbol(",")
            }
            KeyButton {
                text: "Space"
                weight: 2.75
                autoRepeat: true
                customKeyColor: theme.keyColor
                customFontSize: theme.fontSizeSmall
                customTextColor: theme.textSecondaryColor
                onClicked: km.tapNavKey("Space")
            }
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            Layout.preferredWidth: root.clusterWidth
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2

            KeyButton {
                text: "Space"
                weight: 2.75
                autoRepeat: true
                customKeyColor: theme.keyColor
                customFontSize: theme.fontSizeSmall
                customTextColor: theme.textSecondaryColor
                onClicked: km.tapNavKey("Space")
            }
            KeyButton {
                text: "."
                weight: 1.0
                customFontSize: theme.fontSizeLarge
                onClicked: km.tapSymbol(".")
            }
            KeyButton {
                text: "↵ Enter"
                weight: 1.5
                isAccent: true
                customFontSize: theme.fontSizeSmall
                onClicked: km.tapNavKey("Enter")
            }
        }
    }
}
