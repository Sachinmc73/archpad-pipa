import QtQuick
import QtQuick.Layouts
import "../components"

ColumnLayout {
    id: root
    spacing: 2
    anchors.fill: parent
    anchors.margins: 4

    readonly property bool isShifted: km.shiftActive || km.capsLockActive
    property bool symbolMode: false

    function l(letter) {
        return isShifted ? letter.toUpperCase() : letter.toLowerCase()
    }

    // Bar 1 (Upper Special Bar): Linux Special Keys
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        Layout.maximumHeight: 38
        Layout.fillHeight: false
        spacing: 1

        KeyButton {
            text: "Esc"
            weight: 1.0
            customKeyColor: theme.keySpecialColor
            customFontSize: theme.fontSizeSmall
            onClicked: km.tapNavKey("Esc")
        }
        KeyButton {
            text: "Tab"
            weight: 1.0
            customKeyColor: theme.keySpecialColor
            customFontSize: theme.fontSizeSmall
            onClicked: km.tapNavKey("Tab")
        }
        ModifierKey {
            text: "Ctrl"
            weight: 1.0
            active: km.ctrlActive
            customFontSize: theme.fontSizeSmall
            onClicked: km.ctrlActive = !km.ctrlActive
        }
        ModifierKey {
            text: "Alt"
            weight: 1.0
            active: km.altActive
            customFontSize: theme.fontSizeSmall
            onClicked: km.altActive = !km.altActive
        }
        KeyButton { text: "~"; weight: 1.0; customKeyColor: theme.keySpecialColor; onClicked: km.tapSymbol("~") }
        KeyButton { text: "|"; weight: 1.0; customKeyColor: theme.keySpecialColor; onClicked: km.tapSymbol("|") }
        KeyButton { text: "\\"; weight: 1.0; customKeyColor: theme.keySpecialColor; onClicked: km.tapSymbol("\\") }
        KeyButton { text: "/"; weight: 1.0; customKeyColor: theme.keySpecialColor; onClicked: km.tapSymbol("/") }
        KeyButton {
            iconName: "arrow-left"
            weight: 1.0
            autoRepeat: true
            customKeyColor: theme.keySpecialColor
            onClicked: km.tapNavKey("Left")
        }
        KeyButton {
            iconName: "arrow-up"
            weight: 1.0
            autoRepeat: true
            customKeyColor: theme.keySpecialColor
            onClicked: km.tapNavKey("Up")
        }
        KeyButton {
            iconName: "arrow-down"
            weight: 1.0
            autoRepeat: true
            customKeyColor: theme.keySpecialColor
            onClicked: km.tapNavKey("Down")
        }
        KeyButton {
            iconName: "arrow-right"
            weight: 1.0
            autoRepeat: true
            customKeyColor: theme.keySpecialColor
            onClicked: km.tapNavKey("Right")
        }
    }

    // Bar 2 (Middle Number Bar): Numbers 1 - 0
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        Layout.maximumHeight: 40
        Layout.fillHeight: false
        spacing: 1

        KeyButton { text: "1"; secondaryText: "!"; weight: 1.0; onClicked: km.tapSymbol("1"); onHeld: km.tapSymbol("!") }
        KeyButton { text: "2"; secondaryText: "@"; weight: 1.0; onClicked: km.tapSymbol("2"); onHeld: km.tapSymbol("@") }
        KeyButton { text: "3"; secondaryText: "#"; weight: 1.0; onClicked: km.tapSymbol("3"); onHeld: km.tapSymbol("#") }
        KeyButton { text: "4"; secondaryText: "$"; weight: 1.0; onClicked: km.tapSymbol("4"); onHeld: km.tapSymbol("$") }
        KeyButton { text: "5"; secondaryText: "%"; weight: 1.0; onClicked: km.tapSymbol("5"); onHeld: km.tapSymbol("%") }
        KeyButton { text: "6"; secondaryText: "^"; weight: 1.0; onClicked: km.tapSymbol("6"); onHeld: km.tapSymbol("^") }
        KeyButton { text: "7"; secondaryText: "&"; weight: 1.0; onClicked: km.tapSymbol("7"); onHeld: km.tapSymbol("&") }
        KeyButton { text: "8"; secondaryText: "*"; weight: 1.0; onClicked: km.tapSymbol("8"); onHeld: km.tapSymbol("*") }
        KeyButton { text: "9"; secondaryText: "("; weight: 1.0; onClicked: km.tapSymbol("9"); onHeld: km.tapSymbol("(") }
        KeyButton { text: "0"; secondaryText: ")"; weight: 1.0; onClicked: km.tapSymbol("0"); onHeld: km.tapSymbol(")") }
    }

    // Row 3: Q W E R T Y U I O P
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        KeyButton { text: root.symbolMode ? "+" : l("q"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "+" : l("q")) }
        KeyButton { text: root.symbolMode ? "×" : l("w"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "*" : l("w")) }
        KeyButton { text: root.symbolMode ? "÷" : l("e"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "/" : l("e")) }
        KeyButton { text: root.symbolMode ? "=" : l("r"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "=" : l("r")) }
        KeyButton { text: root.symbolMode ? "/" : l("t"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "/" : l("t")) }
        KeyButton { text: root.symbolMode ? "_" : l("y"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "_" : l("y")) }
        KeyButton { text: root.symbolMode ? "<" : l("u"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "<" : l("u")) }
        KeyButton { text: root.symbolMode ? ">" : l("i"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? ">" : l("i")) }
        KeyButton { text: root.symbolMode ? "[" : l("o"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "[" : l("o")) }
        KeyButton { text: root.symbolMode ? "]" : l("p"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "]" : l("p")) }
    }

    // Row 4: A S D F G H J K L
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        Item { Layout.fillWidth: true; Layout.preferredWidth: 20 }
        KeyButton { text: root.symbolMode ? "!" : l("a"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "!" : l("a")) }
        KeyButton { text: root.symbolMode ? "@" : l("s"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "@" : l("s")) }
        KeyButton { text: root.symbolMode ? "#" : l("d"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "#" : l("d")) }
        KeyButton { text: root.symbolMode ? "$" : l("f"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "$" : l("f")) }
        KeyButton { text: root.symbolMode ? "%" : l("g"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "%" : l("g")) }
        KeyButton { text: root.symbolMode ? "^" : l("h"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "^" : l("h")) }
        KeyButton { text: root.symbolMode ? "&" : l("j"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "&" : l("j")) }
        KeyButton { text: root.symbolMode ? "*" : l("k"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "*" : l("k")) }
        KeyButton { text: root.symbolMode ? "(" : l("l"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "(" : l("l")) }
        Item { Layout.fillWidth: true; Layout.preferredWidth: 20 }
    }

    // Row 5: Shift, Z X C V B N M, Backspace
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        ModifierKey {
            text: "⇧"
            weight: 1.5
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
        KeyButton { text: root.symbolMode ? "`" : l("z"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "`" : l("z")) }
        KeyButton { text: root.symbolMode ? "~" : l("x"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "~" : l("x")) }
        KeyButton { text: root.symbolMode ? "{" : l("c"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "{" : l("c")) }
        KeyButton { text: root.symbolMode ? "}" : l("v"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "}" : l("v")) }
        KeyButton { text: root.symbolMode ? ":" : l("b"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? ":" : l("b")) }
        KeyButton { text: root.symbolMode ? ";" : l("n"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? ";" : l("n")) }
        KeyButton { text: root.symbolMode ? "'" : l("m"); weight: 1.0; onClicked: km.tapSymbol(root.symbolMode ? "'" : l("m")) }
        KeyButton {
            text: "⌫"
            weight: 1.5
            autoRepeat: true
            customKeyColor: theme.keyDeleteColor
            customFontSize: theme.fontSizeLarge
            onClicked: km.tapNavKey("Backspace")
        }
    }

    // Row 6: ?123, Comma, Spacebar, Period, Enter
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        KeyButton {
            text: root.symbolMode ? "ABC" : "?123"
            weight: 1.4
            customKeyColor: theme.keySpecialColor
            customFontSize: theme.fontSizeSmall
            onClicked: root.symbolMode = !root.symbolMode
        }
        KeyButton {
            text: ","
            weight: 1.0
            customFontSize: theme.fontSizeLarge
            onClicked: km.tapSymbol(",")
        }
        KeyButton {
            text: "Space"
            weight: 4.8
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
            weight: 1.8
            isAccent: true
            customFontSize: theme.fontSizeSmall
            onClicked: km.tapNavKey("Enter")
        }
    }
}
