import QtQuick
import QtQuick.Layouts
import "../components"

ColumnLayout {
    id: root
    spacing: 1
    anchors.fill: parent
    anchors.margins: 4

    readonly property bool isShifted: km.shiftActive || km.capsLockActive

    function l(letter) {
        return isShifted ? letter.toUpperCase() : letter.toLowerCase()
    }

    // Row 1: Esc, ` ~, 1-0, - _, = +, Backspace
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        KeyButton {
            text: "Esc"
            weight: 1.1
            customKeyColor: theme.keySpecialColor
            customFontSize: theme.fontSizeSmall
            onClicked: km.tapNavKey("Esc")
        }
        KeyButton {
            text: isShifted ? "~" : "`"
            secondaryText: isShifted ? "`" : "~"
            weight: 1.0
            onClicked: km.tapSymbol(isShifted ? "~" : "`")
            onHeld: km.tapSymbol(isShifted ? "`" : "~")
        }
        KeyButton { text: "1"; secondaryText: "!"; weight: 1.0; onClicked: km.tapSymbol(isShifted ? "!" : "1"); onHeld: km.tapSymbol("!") }
        KeyButton { text: "2"; secondaryText: "@"; weight: 1.0; onClicked: km.tapSymbol(isShifted ? "@" : "2"); onHeld: km.tapSymbol("@") }
        KeyButton { text: "3"; secondaryText: "#"; weight: 1.0; onClicked: km.tapSymbol(isShifted ? "#" : "3"); onHeld: km.tapSymbol("#") }
        KeyButton { text: "4"; secondaryText: "$"; weight: 1.0; onClicked: km.tapSymbol(isShifted ? "$" : "4"); onHeld: km.tapSymbol("$") }
        KeyButton { text: "5"; secondaryText: "%"; weight: 1.0; onClicked: km.tapSymbol(isShifted ? "%" : "5"); onHeld: km.tapSymbol("%") }
        KeyButton { text: "6"; secondaryText: "^"; weight: 1.0; onClicked: km.tapSymbol(isShifted ? "^" : "6"); onHeld: km.tapSymbol("^") }
        KeyButton { text: "7"; secondaryText: "&"; weight: 1.0; onClicked: km.tapSymbol(isShifted ? "&" : "7"); onHeld: km.tapSymbol("&") }
        KeyButton { text: "8"; secondaryText: "*"; weight: 1.0; onClicked: km.tapSymbol(isShifted ? "*" : "8"); onHeld: km.tapSymbol("*") }
        KeyButton { text: "9"; secondaryText: "("; weight: 1.0; onClicked: km.tapSymbol(isShifted ? "(" : "9"); onHeld: km.tapSymbol("(") }
        KeyButton { text: "0"; secondaryText: ")"; weight: 1.0; onClicked: km.tapSymbol(isShifted ? ")" : "0"); onHeld: km.tapSymbol(")") }
        KeyButton {
            text: isShifted ? "_" : "-"
            secondaryText: isShifted ? "-" : "_"
            weight: 1.0
            onClicked: km.tapSymbol(isShifted ? "_" : "-")
            onHeld: km.tapSymbol(isShifted ? "-" : "_")
        }
        KeyButton {
            text: isShifted ? "+" : "="
            secondaryText: isShifted ? "=" : "+"
            weight: 1.0
            onClicked: km.tapSymbol(isShifted ? "+" : "=")
            onHeld: km.tapSymbol(isShifted ? "=" : "+")
        }
        KeyButton {
            text: "⌫"
            weight: 1.6
            autoRepeat: true
            customKeyColor: theme.keyDeleteColor
            customFontSize: theme.fontSizeLarge
            onClicked: km.tapNavKey("Backspace")
        }
    }

    // Row 2: Tab, Q W E R T Y U I O P, [ {, ] }, \ |
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        KeyButton {
            text: "Tab"
            weight: 1.4
            customKeyColor: theme.keySpecialColor
            customFontSize: theme.fontSizeSmall
            onClicked: km.tapNavKey("Tab")
        }
        KeyButton { text: l("q"); weight: 1.0; onClicked: km.tapSymbol(l("q")) }
        KeyButton { text: l("w"); weight: 1.0; onClicked: km.tapSymbol(l("w")) }
        KeyButton { text: l("e"); weight: 1.0; onClicked: km.tapSymbol(l("e")) }
        KeyButton { text: l("r"); weight: 1.0; onClicked: km.tapSymbol(l("r")) }
        KeyButton { text: l("t"); weight: 1.0; onClicked: km.tapSymbol(l("t")) }
        KeyButton { text: l("y"); weight: 1.0; onClicked: km.tapSymbol(l("y")) }
        KeyButton { text: l("u"); weight: 1.0; onClicked: km.tapSymbol(l("u")) }
        KeyButton { text: l("i"); weight: 1.0; onClicked: km.tapSymbol(l("i")) }
        KeyButton { text: l("o"); weight: 1.0; onClicked: km.tapSymbol(l("o")) }
        KeyButton { text: l("p"); weight: 1.0; onClicked: km.tapSymbol(l("p")) }
        KeyButton {
            text: isShifted ? "{" : "["
            secondaryText: isShifted ? "[" : "{"
            weight: 1.0
            onClicked: km.tapSymbol(isShifted ? "{" : "[")
            onHeld: km.tapSymbol(isShifted ? "[" : "{")
        }
        KeyButton {
            text: isShifted ? "}" : "]"
            secondaryText: isShifted ? "]" : "}"
            weight: 1.0
            onClicked: km.tapSymbol(isShifted ? "}" : "]")
            onHeld: km.tapSymbol(isShifted ? "]" : "}")
        }
        KeyButton {
            text: isShifted ? "|" : "\\"
            secondaryText: isShifted ? "\\" : "|"
            weight: 1.3
            onClicked: km.tapSymbol(isShifted ? "|" : "\\")
            onHeld: km.tapSymbol(isShifted ? "\\" : "|")
        }
    }

    // Row 3: CapsLock, A S D F G H J K L, ; :, ' ", Enter
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        ModifierKey {
            text: "Caps"
            weight: 1.7
            active: km.capsLockActive
            isLocked: km.capsLockActive
            customFontSize: theme.fontSizeSmall
            onClicked: km.capsLockActive = !km.capsLockActive
        }
        KeyButton { text: l("a"); weight: 1.0; onClicked: km.tapSymbol(l("a")) }
        KeyButton { text: l("s"); weight: 1.0; onClicked: km.tapSymbol(l("s")) }
        KeyButton { text: l("d"); weight: 1.0; onClicked: km.tapSymbol(l("d")) }
        KeyButton { text: l("f"); weight: 1.0; onClicked: km.tapSymbol(l("f")) }
        KeyButton { text: l("g"); weight: 1.0; onClicked: km.tapSymbol(l("g")) }
        KeyButton { text: l("h"); weight: 1.0; onClicked: km.tapSymbol(l("h")) }
        KeyButton { text: l("j"); weight: 1.0; onClicked: km.tapSymbol(l("j")) }
        KeyButton { text: l("k"); weight: 1.0; onClicked: km.tapSymbol(l("k")) }
        KeyButton { text: l("l"); weight: 1.0; onClicked: km.tapSymbol(l("l")) }
        KeyButton {
            text: isShifted ? ":" : ";"
            secondaryText: isShifted ? ";" : ":"
            weight: 1.0
            onClicked: km.tapSymbol(isShifted ? ":" : ";")
            onHeld: km.tapSymbol(isShifted ? ";" : ":")
        }
        KeyButton {
            text: isShifted ? "\"" : "'"
            secondaryText: isShifted ? "'" : "\""
            weight: 1.0
            onClicked: km.tapSymbol(isShifted ? "\"" : "'")
            onHeld: km.tapSymbol(isShifted ? "'" : "\"")
        }
        KeyButton {
            text: "↵ Enter"
            weight: 2.1
            isAccent: true
            customFontSize: theme.fontSizeNormal
            onClicked: km.tapNavKey("Enter")
        }
    }

    // Row 4: Shift, Z X C V B N M, , <, . >, / ?, Shift
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        ModifierKey {
            text: "⇧ Shift"
            weight: 2.2
            active: km.shiftActive
            customFontSize: theme.fontSizeSmall
            onClicked: km.shiftActive = !km.shiftActive
        }
        KeyButton { text: l("z"); weight: 1.0; onClicked: km.tapSymbol(l("z")) }
        KeyButton { text: l("x"); weight: 1.0; onClicked: km.tapSymbol(l("x")) }
        KeyButton { text: l("c"); weight: 1.0; onClicked: km.tapSymbol(l("c")) }
        KeyButton { text: l("v"); weight: 1.0; onClicked: km.tapSymbol(l("v")) }
        KeyButton { text: l("b"); weight: 1.0; onClicked: km.tapSymbol(l("b")) }
        KeyButton { text: l("n"); weight: 1.0; onClicked: km.tapSymbol(l("n")) }
        KeyButton { text: l("m"); weight: 1.0; onClicked: km.tapSymbol(l("m")) }
        KeyButton {
            text: isShifted ? "<" : ","
            secondaryText: isShifted ? "," : "<"
            weight: 1.0
            onClicked: km.tapSymbol(isShifted ? "<" : ",")
            onHeld: km.tapSymbol(isShifted ? "," : "<")
        }
        KeyButton {
            text: isShifted ? ">" : "."
            secondaryText: isShifted ? "." : ">"
            weight: 1.0
            onClicked: km.tapSymbol(isShifted ? ">" : ".")
            onHeld: km.tapSymbol(isShifted ? "." : ">")
        }
        KeyButton {
            text: isShifted ? "?" : "/"
            secondaryText: isShifted ? "/" : "?"
            weight: 1.0
            onClicked: km.tapSymbol(isShifted ? "?" : "/")
            onHeld: km.tapSymbol(isShifted ? "/" : "?")
        }
        ModifierKey {
            text: "⇧ Shift"
            weight: 2.5
            active: km.shiftActive
            customFontSize: theme.fontSizeSmall
            onClicked: km.shiftActive = !km.shiftActive
        }
    }

    // Row 5: Ctrl, Super, Alt, Space, Alt, Ctrl, Arrows (◄, ▲, ▼, ►)
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        ModifierKey {
            text: "Ctrl"
            weight: 1.3
            active: km.ctrlActive
            customFontSize: theme.fontSizeSmall
            onClicked: km.ctrlActive = !km.ctrlActive
        }
        ModifierKey {
            text: "⊞"
            weight: 1.1
            active: km.metaActive
            customFontSize: theme.fontSizeNormal
            onClicked: km.metaActive = !km.metaActive
        }
        ModifierKey {
            text: "Alt"
            weight: 1.2
            active: km.altActive
            customFontSize: theme.fontSizeSmall
            onClicked: km.altActive = !km.altActive
        }
        KeyButton {
            text: "Space"
            weight: 6.5
            autoRepeat: true
            customKeyColor: theme.keyColor
            customFontSize: theme.fontSizeSmall
            customTextColor: theme.textSecondaryColor
            onClicked: km.tapNavKey("Space")
        }
        ModifierKey {
            text: "Alt"
            weight: 1.2
            active: km.altActive
            customFontSize: theme.fontSizeSmall
            onClicked: km.altActive = !km.altActive
        }
        ModifierKey {
            text: "Ctrl"
            weight: 1.2
            active: km.ctrlActive
            customFontSize: theme.fontSizeSmall
            onClicked: km.ctrlActive = !km.ctrlActive
        }
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
}
