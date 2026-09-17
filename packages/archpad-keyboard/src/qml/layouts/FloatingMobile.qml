import QtQuick
import QtQuick.Layouts
import "../components"
import org.archpad.keyboard 1.0

ColumnLayout {
    id: root
    spacing: 2
    anchors.fill: parent
    anchors.margins: 3

    readonly property bool isShifted: km.shiftActive
    readonly property bool isLetterUpper: km.shiftActive ? !km.capsLockActive : km.capsLockActive
    property bool symbolMode: false

    function l(letter) {
        return isLetterUpper ? letter.toUpperCase() : letter.toLowerCase()
    }

    // 1. Compact Horizontally Scrollable Special Key Bar
    Flickable {
        id: specialBarFlick
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        Layout.maximumHeight: 28
        contentWidth: specialBarRow.width
        contentHeight: 28
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        RowLayout {
            id: specialBarRow
            height: 28
            spacing: 2

            KeyButton { text: "Esc"; Layout.preferredWidth: 36; allowFlickSteal: true; triggerOnPress: false; customKeyColor: theme.keySpecialColor; customFontSize: theme.fontSizeSmall; onClicked: km.tapNavKey("Esc") }
            KeyButton { text: "Tab"; Layout.preferredWidth: 36; allowFlickSteal: true; triggerOnPress: false; customKeyColor: theme.keySpecialColor; customFontSize: theme.fontSizeSmall; onClicked: km.tapNavKey("Tab") }
            ModifierKey { text: "Ctrl"; Layout.preferredWidth: 36; allowFlickSteal: true; active: km.ctrlActive; customFontSize: theme.fontSizeSmall; onClicked: km.ctrlActive = !km.ctrlActive }
            ModifierKey { text: "Alt"; Layout.preferredWidth: 36; allowFlickSteal: true; active: km.altActive; customFontSize: theme.fontSizeSmall; onClicked: km.altActive = !km.altActive }
            KeyButton { text: "~"; Layout.preferredWidth: 32; allowFlickSteal: true; triggerOnPress: false; customKeyColor: theme.keySpecialColor; onClicked: km.tapSymbol("~") }
            KeyButton { text: "|"; Layout.preferredWidth: 32; allowFlickSteal: true; triggerOnPress: false; customKeyColor: theme.keySpecialColor; onClicked: km.tapSymbol("|") }
            KeyButton { text: "\\"; Layout.preferredWidth: 32; allowFlickSteal: true; triggerOnPress: false; customKeyColor: theme.keySpecialColor; onClicked: km.tapSymbol("\\") }
            KeyButton { text: "/"; Layout.preferredWidth: 32; allowFlickSteal: true; triggerOnPress: false; customKeyColor: theme.keySpecialColor; onClicked: km.tapSymbol("/") }
            KeyButton { iconName: "arrow-left"; Layout.preferredWidth: 34; allowFlickSteal: true; triggerOnPress: false; autoRepeat: true; customKeyColor: theme.keySpecialColor; onClicked: km.tapNavKey("Left") }
            KeyButton { iconName: "arrow-up"; Layout.preferredWidth: 34; allowFlickSteal: true; triggerOnPress: false; autoRepeat: true; customKeyColor: theme.keySpecialColor; onClicked: km.tapNavKey("Up") }
            KeyButton { iconName: "arrow-down"; Layout.preferredWidth: 34; allowFlickSteal: true; triggerOnPress: false; autoRepeat: true; customKeyColor: theme.keySpecialColor; onClicked: km.tapNavKey("Down") }
            KeyButton { iconName: "arrow-right"; Layout.preferredWidth: 34; allowFlickSteal: true; triggerOnPress: false; autoRepeat: true; customKeyColor: theme.keySpecialColor; onClicked: km.tapNavKey("Right") }
        }
    }

    // 2. Row 1: Numbers with Secondary Symbols
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 100
        Layout.fillHeight: true
        spacing: 1

        KeyButton { text: "1"; secondaryText: "!"; weight: 1.0; onClicked: km.tapSymbol("1"); onHeld: km.tapSymbol("!") }
        KeyButton { text: "2"; secondaryText: "@"; weight: 1.0; onClicked: km.tapSymbol("2"); onHeld: km.tapSymbol("@") }
        KeyButton { text: "3"; secondaryText: "#"; weight: 1.0; onClicked: km.tapSymbol("3"); onHeld: km.tapSymbol("#") }
        KeyButton { text: "4"; secondaryText: "₹"; weight: 1.0; onClicked: km.tapSymbol("4"); onHeld: km.tapSymbol("₹") }
        KeyButton { text: "5"; secondaryText: "%"; weight: 1.0; onClicked: km.tapSymbol("5"); onHeld: km.tapSymbol("%") }
        KeyButton { text: "6"; secondaryText: "^"; weight: 1.0; onClicked: km.tapSymbol("6"); onHeld: km.tapSymbol("^") }
        KeyButton { text: "7"; secondaryText: "&"; weight: 1.0; onClicked: km.tapSymbol("7"); onHeld: km.tapSymbol("&") }
        KeyButton { text: "8"; secondaryText: "*"; weight: 1.0; onClicked: km.tapSymbol("8"); onHeld: km.tapSymbol("*") }
        KeyButton { text: "9"; secondaryText: "("; weight: 1.0; onClicked: km.tapSymbol("9"); onHeld: km.tapSymbol("(") }
        KeyButton { text: "0"; secondaryText: ")"; weight: 1.0; onClicked: km.tapSymbol("0"); onHeld: km.tapSymbol(")") }
    }

    // Letter Key Surface (Rows 2, 3, 4 - Normalized [0.0, 1.0] domain for swipe typing)
    Item {
        id: letterSurface
        Layout.fillWidth: true
        Layout.preferredHeight: 300
        Layout.fillHeight: true

        GestureTrail {
            id: gestureTrail
            anchors.fill: parent
            z: 20
            trailColor: theme.keyAccentColor
            strokeWidth: 8.0
            decayDurationMs: 280
        }

        Item {
            id: gestureCoordinator
            property var rawPoints: []
            property var startTime: 0
            property int swipeReqCounter: 0

            function mapPoint(item, localX, localY) {
                return item.mapToItem(letterSurface, localX, localY)
            }

            function startSwipe(startX, startY) {
                rawPoints = []
                startTime = Date.now()
                rawPoints.push({
                    x: startX,
                    y: startY,
                    t: 0
                })
                gestureTrail.clear()
                gestureTrail.addPoint(startX, startY)
                km.swipeActive = true
            }

            function addPoint(x, y) {
                var elapsedMs = Date.now() - startTime
                rawPoints.push({
                    x: x,
                    y: y,
                    t: elapsedMs
                })
                gestureTrail.addPoint(x, y)
            }

            function finishSwipe() {
                gestureTrail.endStroke()
                km.swipeActive = false

                if (rawPoints.length < 3) {
                    rawPoints = []
                    return
                }

                var w = letterSurface.width
                var h = letterSurface.height
                if (w <= 0 || h <= 0) {
                    rawPoints = []
                    return
                }

                var normPoints = []
                for (var i = 0; i < rawPoints.length; ++i) {
                    var p = rawPoints[i]
                    var nx = Math.max(0.0, Math.min(1.0, p.x / w))
                    var ny = Math.max(0.0, Math.min(1.0, p.y / h))
                    normPoints.push({
                        x: nx,
                        y: ny,
                        t: p.t
                    })
                }

                swipeReqCounter++
                var reqId = swipeReqCounter
                console.log("Swipe gesture dispatched: " + normPoints.length + " points, elapsed: " + (Date.now() - startTime) + "ms, reqId: " + reqId)
                km.requestSwipeDecode(reqId, normPoints, [])
                rawPoints = []
            }

            function cancelSwipe() {
                gestureTrail.endStroke()
                km.swipeActive = false
                rawPoints = []
            }
        }

        ColumnLayout {
            id: letterCol
            anchors.fill: parent
            spacing: 1

            // 3. Row 2: Q W E R T Y U I O P (or Symbols)
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 1

                KeyButton {
                    text: !root.symbolMode ? l("q") : "@"
                    secondaryText: !root.symbolMode ? "~" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("q") : "@")
                    onHeld: km.tapSymbol(!root.symbolMode ? "~" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("w") : "#"
                    secondaryText: !root.symbolMode ? "|" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("w") : "#")
                    onHeld: km.tapSymbol(!root.symbolMode ? "|" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("e") : "₹"
                    secondaryText: !root.symbolMode ? "\\" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("e") : "₹")
                    onHeld: km.tapSymbol(!root.symbolMode ? "\\" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("r") : "$"
                    secondaryText: !root.symbolMode ? "/" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("r") : "$")
                    onHeld: km.tapSymbol(!root.symbolMode ? "/" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("t") : "%"
                    secondaryText: !root.symbolMode ? "_" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("t") : "%")
                    onHeld: km.tapSymbol(!root.symbolMode ? "_" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("y") : "&"
                    secondaryText: !root.symbolMode ? "<" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("y") : "&")
                    onHeld: km.tapSymbol(!root.symbolMode ? "<" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("u") : "-"
                    secondaryText: !root.symbolMode ? ">" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("u") : "-")
                    onHeld: km.tapSymbol(!root.symbolMode ? ">" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("i") : "+"
                    secondaryText: !root.symbolMode ? "[" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("i") : "+")
                    onHeld: km.tapSymbol(!root.symbolMode ? "[" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("o") : "("
                    secondaryText: !root.symbolMode ? "]" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("o") : "(")
                    onHeld: km.tapSymbol(!root.symbolMode ? "]" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("p") : ")"
                    secondaryText: !root.symbolMode ? "=" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("p") : ")")
                    onHeld: km.tapSymbol(!root.symbolMode ? "=" : "")
                }
            }

            // 4. Row 3: A S D F G H J K L
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 1

                Item { Layout.fillWidth: true; Layout.preferredWidth: 50; Layout.fillHeight: true }

                KeyButton {
                    text: !root.symbolMode ? l("a") : "*"
                    secondaryText: !root.symbolMode ? "!" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("a") : "*")
                    onHeld: km.tapSymbol(!root.symbolMode ? "!" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("s") : "\""
                    secondaryText: !root.symbolMode ? "@" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("s") : "\"")
                    onHeld: km.tapSymbol(!root.symbolMode ? "@" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("d") : "'"
                    secondaryText: !root.symbolMode ? "#" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("d") : "'")
                    onHeld: km.tapSymbol(!root.symbolMode ? "#" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("f") : ":"
                    secondaryText: !root.symbolMode ? "$" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("f") : ":")
                    onHeld: km.tapSymbol(!root.symbolMode ? "$" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("g") : ";"
                    secondaryText: !root.symbolMode ? "%" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("g") : ";")
                    onHeld: km.tapSymbol(!root.symbolMode ? "%" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("h") : "!"
                    secondaryText: !root.symbolMode ? "^" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("h") : "!")
                    onHeld: km.tapSymbol(!root.symbolMode ? "^" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("j") : "?"
                    secondaryText: !root.symbolMode ? "&" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("j") : "?")
                    onHeld: km.tapSymbol(!root.symbolMode ? "&" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("k") : "/"
                    secondaryText: !root.symbolMode ? "*" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("k") : "/")
                    onHeld: km.tapSymbol(!root.symbolMode ? "*" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("l") : "\\"
                    secondaryText: !root.symbolMode ? "?" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("l") : "\\")
                    onHeld: km.tapSymbol(!root.symbolMode ? "?" : "")
                }

                Item { Layout.fillWidth: true; Layout.preferredWidth: 50; Layout.fillHeight: true }
            }

            // 5. Row 4: Shift (or _ in symbols), Z-M, Backspace
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 1

                // Left key: Shift in QWERTY, "_" in symbol mode
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 150
                    sourceComponent: !root.symbolMode ? shiftKeyComp : symbolExtraKeyComp
                }

                Component {
                    id: shiftKeyComp
                    ModifierKey {
                        text: "⇧"
                        weight: 1.5
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
                }

                Component {
                    id: symbolExtraKeyComp
                    KeyButton {
                        text: "_"
                        secondaryText: "~"
                        weight: 1.5
                        customKeyColor: theme.keySpecialColor
                        onClicked: km.tapSymbol("_")
                        onHeld: km.tapSymbol("~")
                    }
                }

                KeyButton {
                    text: !root.symbolMode ? l("z") : "<"
                    secondaryText: !root.symbolMode ? "`" : "`"
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("z") : "<")
                    onHeld: km.tapSymbol("`")
                }
                KeyButton {
                    text: !root.symbolMode ? l("x") : ">"
                    secondaryText: !root.symbolMode ? "+" : "|"
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("x") : ">")
                    onHeld: km.tapSymbol(!root.symbolMode ? "+" : "|")
                }
                KeyButton {
                    text: !root.symbolMode ? l("c") : "["
                    secondaryText: !root.symbolMode ? "-" : "{"
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("c") : "[")
                    onHeld: km.tapSymbol(!root.symbolMode ? "-" : "{")
                }
                KeyButton {
                    text: !root.symbolMode ? l("v") : "]"
                    secondaryText: !root.symbolMode ? "{" : "}"
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("v") : "]")
                    onHeld: km.tapSymbol(!root.symbolMode ? "{" : "}")
                }
                KeyButton {
                    text: !root.symbolMode ? l("b") : "{"
                    secondaryText: !root.symbolMode ? "}" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("b") : "{")
                    onHeld: km.tapSymbol(!root.symbolMode ? "}" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("n") : "}"
                    secondaryText: !root.symbolMode ? ":" : ""
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("n") : "}")
                    onHeld: km.tapSymbol(!root.symbolMode ? ":" : "")
                }
                KeyButton {
                    text: !root.symbolMode ? l("m") : "="
                    secondaryText: !root.symbolMode ? ";" : "+"
                    weight: 1.0
                    swipeEnabled: !root.symbolMode
                    gestureTracker: gestureCoordinator
                    onClicked: km.tapSymbol(!root.symbolMode ? l("m") : "=")
                    onHeld: km.tapSymbol(!root.symbolMode ? ";" : "+")
                }

                KeyButton {
                    text: "⌫"
                    weight: 1.5
                    autoRepeat: true
                    customKeyColor: theme.keyDeleteColor
                    onClicked: km.tapNavKey("Backspace")
                }
            }
        }
    }

    // 6. Row 5: ?123, Comma, Spacebar, Period, Enter
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 100
        Layout.fillHeight: true
        spacing: 1

        KeyButton {
            text: root.symbolMode ? "ABC" : "?123"
            weight: 1.3
            customKeyColor: theme.keySpecialColor
            customFontSize: theme.fontSizeSmall
            onClicked: {
                km.playClick()
                root.symbolMode = !root.symbolMode
            }
        }
        KeyButton {
            text: ","
            secondaryText: "'"
            weight: 0.9
            onClicked: km.tapSymbol(",")
            onHeld: km.tapSymbol("'")
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
            secondaryText: "\""
            weight: 0.9
            onClicked: km.tapSymbol(".")
            onHeld: km.tapSymbol("\"")
        }
        KeyButton {
            text: "↵"
            weight: 1.5
            isAccent: true
            onClicked: km.tapNavKey("Enter")
        }
    }

}
