import QtQuick
import QtQuick.Layouts
import "../components"

ColumnLayout {
    id: root
    spacing: 1
    anchors.fill: parent
    anchors.margins: 2

    readonly property bool isShifted: km.shiftActive || km.capsLockActive
    property bool symbolMode: false

    function l(letter) {
        return isShifted ? letter.toUpperCase() : letter.toLowerCase()
    }

    // Row 1: Numbers
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        KeyButton { text: "1"; weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol("1") }
        KeyButton { text: "2"; weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol("2") }
        KeyButton { text: "3"; weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol("3") }
        KeyButton { text: "4"; weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol("4") }
        KeyButton { text: "5"; weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol("5") }
        KeyButton { text: "6"; weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol("6") }
        KeyButton { text: "7"; weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol("7") }
        KeyButton { text: "8"; weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol("8") }
        KeyButton { text: "9"; weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol("9") }
        KeyButton { text: "0"; weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol("0") }
    }

    // Row 2: Q W E R T Y U I O P
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        KeyButton { text: root.symbolMode ? "+" : l("q"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "+" : l("q")) }
        KeyButton { text: root.symbolMode ? "×" : l("w"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "*" : l("w")) }
        KeyButton { text: root.symbolMode ? "÷" : l("e"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "/" : l("e")) }
        KeyButton { text: root.symbolMode ? "=" : l("r"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "=" : l("r")) }
        KeyButton { text: root.symbolMode ? "/" : l("t"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "/" : l("t")) }
        KeyButton { text: root.symbolMode ? "_" : l("y"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "_" : l("y")) }
        KeyButton { text: root.symbolMode ? "<" : l("u"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "<" : l("u")) }
        KeyButton { text: root.symbolMode ? ">" : l("i"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? ">" : l("i")) }
        KeyButton { text: root.symbolMode ? "[" : l("o"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "[" : l("o")) }
        KeyButton { text: root.symbolMode ? "]" : l("p"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "]" : l("p")) }
    }

    // Row 3: A S D F G H J K L
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        Item { Layout.fillWidth: true; Layout.preferredWidth: 10 }
        KeyButton { text: root.symbolMode ? "!" : l("a"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "!" : l("a")) }
        KeyButton { text: root.symbolMode ? "@" : l("s"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "@" : l("s")) }
        KeyButton { text: root.symbolMode ? "#" : l("d"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "#" : l("d")) }
        KeyButton { text: root.symbolMode ? "$" : l("f"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "$" : l("f")) }
        KeyButton { text: root.symbolMode ? "%" : l("g"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "%" : l("g")) }
        KeyButton { text: root.symbolMode ? "^" : l("h"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "^" : l("h")) }
        KeyButton { text: root.symbolMode ? "&" : l("j"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "&" : l("j")) }
        KeyButton { text: root.symbolMode ? "*" : l("k"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "*" : l("k")) }
        KeyButton { text: root.symbolMode ? "(" : l("l"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "(" : l("l")) }
        Item { Layout.fillWidth: true; Layout.preferredWidth: 10 }
    }

    // Row 4: Shift, Z X C V B N M, Backspace
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        ModifierKey {
            text: "⇧"
            weight: 1.4
            active: km.shiftActive
            isLocked: km.capsLockActive
            customFontSize: theme.fontSizeNormal
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
        KeyButton { text: root.symbolMode ? "`" : l("z"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "`" : l("z")) }
        KeyButton { text: root.symbolMode ? "~" : l("x"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "~" : l("x")) }
        KeyButton { text: root.symbolMode ? "{" : l("c"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "{" : l("c")) }
        KeyButton { text: root.symbolMode ? "}" : l("v"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "}" : l("v")) }
        KeyButton { text: root.symbolMode ? ":" : l("b"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? ":" : l("b")) }
        KeyButton { text: root.symbolMode ? ";" : l("n"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? ";" : l("n")) }
        KeyButton { text: root.symbolMode ? "'" : l("m"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(root.symbolMode ? "'" : l("m")) }
        KeyButton {
            text: "⌫"
            weight: 1.4
            autoRepeat: true
            customKeyColor: theme.keyDeleteColor
            customFontSize: theme.fontSizeNormal
            onClicked: km.tapNavKey("Backspace")
        }
    }

    // Row 5: ?123, Spacebar, Enter
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        KeyButton {
            text: root.symbolMode ? "ABC" : "?123"
            weight: 1.3
            customKeyColor: theme.keySpecialColor
            customFontSize: theme.fontSizeSmall
            onClicked: root.symbolMode = !root.symbolMode
        }
        KeyButton {
            text: ","
            weight: 0.9
            customFontSize: theme.fontSizeSmall
            onClicked: km.tapSymbol(",")
        }
        KeyButton {
            text: "Space"
            weight: 4.5
            autoRepeat: true
            customKeyColor: theme.keyColor
            customFontSize: theme.fontSizeSmall
            customTextColor: theme.textSecondaryColor
            onClicked: km.tapNavKey("Space")
        }
        KeyButton {
            text: "."
            weight: 0.9
            customFontSize: theme.fontSizeSmall
            onClicked: km.tapSymbol(".")
        }
        KeyButton {
            text: "↵"
            weight: 1.5
            isAccent: true
            customFontSize: theme.fontSizeNormal
            onClicked: km.tapNavKey("Enter")
        }
    }
}
