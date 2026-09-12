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

        KeyButton { text: l("q"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("q")) }
        KeyButton { text: l("w"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("w")) }
        KeyButton { text: l("e"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("e")) }
        KeyButton { text: l("r"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("r")) }
        KeyButton { text: l("t"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("t")) }
        KeyButton { text: l("y"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("y")) }
        KeyButton { text: l("u"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("u")) }
        KeyButton { text: l("i"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("i")) }
        KeyButton { text: l("o"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("o")) }
        KeyButton { text: l("p"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("p")) }
    }

    // Row 3: A S D F G H J K L
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        Item { Layout.fillWidth: true; Layout.preferredWidth: 10 }
        KeyButton { text: l("a"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("a")) }
        KeyButton { text: l("s"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("s")) }
        KeyButton { text: l("d"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("d")) }
        KeyButton { text: l("f"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("f")) }
        KeyButton { text: l("g"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("g")) }
        KeyButton { text: l("h"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("h")) }
        KeyButton { text: l("j"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("j")) }
        KeyButton { text: l("k"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("k")) }
        KeyButton { text: l("l"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("l")) }
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
        KeyButton { text: l("z"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("z")) }
        KeyButton { text: l("x"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("x")) }
        KeyButton { text: l("c"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("c")) }
        KeyButton { text: l("v"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("v")) }
        KeyButton { text: l("b"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("b")) }
        KeyButton { text: l("n"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("n")) }
        KeyButton { text: l("m"); weight: 1.0; customFontSize: theme.fontSizeSmall; onClicked: km.tapSymbol(l("m")) }
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
            text: "?123"
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
