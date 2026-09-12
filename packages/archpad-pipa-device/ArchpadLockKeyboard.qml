import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root

    required property Item screenRoot
    required property var mainStack
    required property Item mainBlock
    required property var passwordField

    readonly property bool keyboardActive: state === "visible"
    readonly property int status: 1 // Loader.Ready = 1

    property bool shiftActive: false
    property bool pinPadMode: false
    property bool symbolsMode: false

    function showHide() {
        state = (state === "hidden") ? "visible" : "hidden";
    }

    function sendKey(c) {
        if (!passwordField) return;
        var pos = passwordField.cursorPosition;
        passwordField.insert(pos, c);
        if (shiftActive) shiftActive = false;
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

    anchors {
        left: parent.left
        right: parent.right
    }

    height: (screenRoot.width > screenRoot.height) ? 310 : 360
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

    // Keyboard Background Card
    Rectangle {
        anchors.fill: parent
        color: "#F5131620"
        border.color: "#2EFFFFFF"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4

            // --- Top Header / Toolbar ---
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                spacing: 8

                Text {
                    text: root.pinPadMode ? "ArchPad · PIN Pad" : (root.symbolsMode ? "ArchPad · Symbols" : "ArchPad · Keyboard")
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: "#38BDF8"
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 8
                }

                Item { Layout.fillWidth: true }

                // Mode switch button
                Rectangle {
                    width: 76
                    height: 28
                    radius: 6
                    color: root.pinPadMode ? "#38BDF8" : "#222733"
                    border.color: "#33FFFFFF"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.pinPadMode ? "QWERTY" : "PIN Pad"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: root.pinPadMode ? "#0F172A" : "#E2E8F0"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.pinPadMode = !root.pinPadMode;
                            root.symbolsMode = false;
                        }
                    }
                }

                // Clear input button
                Rectangle {
                    width: 52
                    height: 28
                    radius: 6
                    color: "#222733"
                    border.color: "#33FFFFFF"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#F87171"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.passwordField) root.passwordField.text = "";
                        }
                    }
                }

                // Hide keyboard button
                Rectangle {
                    width: 52
                    height: 28
                    radius: 6
                    color: "#222733"
                    border.color: "#33FFFFFF"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Hide"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#94A3B8"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.state = "hidden"
                    }
                }
            }

            // --- Main Area ---
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ==================== PIN PAD MODE ====================
                GridLayout {
                    visible: root.pinPadMode
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 40, 360)
                    height: parent.height - 8
                    columns: 3
                    rowSpacing: 6
                    columnSpacing: 8

                    Repeater {
                        model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "Unlock"]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: {
                                if (modelData === "Unlock") return pMouse.pressed ? "#059669" : "#10B981";
                                if (modelData === "⌫") return pMouse.pressed ? "#334155" : "#1F2430";
                                return pMouse.pressed ? "#3B4456" : "#222837";
                            }
                            border.color: "#26FFFFFF"
                            border.width: 1
                            scale: pMouse.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: modelData === "Unlock" ? 15 : 20
                                font.weight: Font.DemiBold
                                color: (modelData === "Unlock") ? "#FFFFFF" : ((modelData === "⌫") ? "#F87171" : "#F1F5F9")
                            }

                            MouseArea {
                                id: pMouse
                                anchors.fill: parent
                                onClicked: {
                                    if (modelData === "Unlock") {
                                        root.sendEnter();
                                    } else if (modelData === "⌫") {
                                        root.sendBackspace();
                                    } else {
                                        root.sendKey(modelData);
                                    }
                                }
                            }
                        }
                    }
                }

                // ==================== QWERTY / SYMBOLS MODE ====================
                ColumnLayout {
                    visible: !root.pinPadMode
                    anchors.fill: parent
                    spacing: 3

                    // Row 1: Numbers / Symbols
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2
                        Repeater {
                            model: root.symbolsMode ? ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="] : ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                color: km1.pressed ? "#3B4456" : "#202533"
                                border.color: "#1EFFFFFF"
                                border.width: 1
                                scale: km1.pressed ? 0.94 : 1.0
                                Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 16
                                    font.weight: Font.Normal
                                    color: "#F1F5F9"
                                }
                                MouseArea {
                                    id: km1
                                    anchors.fill: parent
                                    onClicked: root.sendKey(modelData)
                                }
                            }
                        }
                    }

                    // Row 2: Q W E R T Y U I O P
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2
                        Repeater {
                            model: root.symbolsMode ? ["_", "-", "/", ":", ";", "(", ")", "$", "&", "@"] :
                                   (root.shiftActive ? ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"] :
                                                       ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                color: km2.pressed ? "#3B4456" : "#202533"
                                border.color: "#1EFFFFFF"
                                border.width: 1
                                scale: km2.pressed ? 0.94 : 1.0
                                Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 16
                                    font.weight: Font.Normal
                                    color: "#F1F5F9"
                                }
                                MouseArea {
                                    id: km2
                                    anchors.fill: parent
                                    onClicked: root.sendKey(modelData)
                                }
                            }
                        }
                    }

                    // Row 3: A S D F G H J K L
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2
                        Item { Layout.preferredWidth: 14 }
                        Repeater {
                            model: root.symbolsMode ? ["\"", "\'", "`", "~", "|", "<", ">", "?", "!"] :
                                   (root.shiftActive ? ["A", "S", "D", "F", "G", "H", "J", "K", "L"] :
                                                  ["a", "s", "d", "f", "g", "h", "j", "k", "l"])
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                color: km3.pressed ? "#3B4456" : "#202533"
                                border.color: "#1EFFFFFF"
                                border.width: 1
                                scale: km3.pressed ? 0.94 : 1.0
                                Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 16
                                    font.weight: Font.Normal
                                    color: "#F1F5F9"
                                }
                                MouseArea {
                                    id: km3
                                    anchors.fill: parent
                                    onClicked: root.sendKey(modelData)
                                }
                            }
                        }
                        Item { Layout.preferredWidth: 14 }
                    }

                    // Row 4: Shift, Z X C V B N M, Backspace
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        // Shift Key
                        Rectangle {
                            Layout.preferredWidth: 72
                            Layout.fillHeight: true
                            radius: 6
                            color: root.shiftActive ? "#38BDF8" : (sm.pressed ? "#3B4456" : "#1B202C")
                            border.color: "#1EFFFFFF"
                            border.width: 1
                            scale: sm.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                            Text {
                                anchors.centerIn: parent
                                text: "⇧ Shift"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: root.shiftActive ? "#0F172A" : "#E2E8F0"
                            }
                            MouseArea {
                                id: sm
                                anchors.fill: parent
                                onClicked: root.shiftActive = !root.shiftActive
                            }
                        }

                        Repeater {
                            model: root.symbolsMode ? ["€", "£", "¥", "•", "°", "©", "®"] :
                                   (root.shiftActive ? ["Z", "X", "C", "V", "B", "N", "M"] :
                                                       ["z", "x", "c", "v", "b", "n", "m"])
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                color: km4.pressed ? "#3B4456" : "#202533"
                                border.color: "#1EFFFFFF"
                                border.width: 1
                                scale: km4.pressed ? 0.94 : 1.0
                                Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 16
                                    font.weight: Font.Normal
                                    color: "#F1F5F9"
                                }
                                MouseArea {
                                    id: km4
                                    anchors.fill: parent
                                    onClicked: root.sendKey(modelData)
                                }
                            }
                        }

                        // Backspace Key with auto-repeat
                        Rectangle {
                            Layout.preferredWidth: 72
                            Layout.fillHeight: true
                            radius: 6
                            color: bm.pressed ? "#3B4456" : "#1B202C"
                            border.color: "#1EFFFFFF"
                            border.width: 1
                            scale: bm.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                            Text {
                                anchors.centerIn: parent
                                text: "⌫"
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                                color: "#F87171"
                            }
                            MouseArea {
                                id: bm
                                anchors.fill: parent
                                Timer {
                                    id: bsRepeat
                                    interval: 350
                                    repeat: true
                                    running: bm.pressed
                                    onTriggered: {
                                        interval = 60;
                                        root.sendBackspace();
                                    }
                                }
                                onPressed: {
                                    bsRepeat.interval = 350;
                                    root.sendBackspace();
                                }
                            }
                        }
                    }

                    // Row 5: ?123 / ABC, Space, Period, Unlock
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 3

                        // Symbols Toggle
                        Rectangle {
                            Layout.preferredWidth: 72
                            Layout.fillHeight: true
                            radius: 6
                            color: root.symbolsMode ? "#38BDF8" : (symm.pressed ? "#3B4456" : "#1B202C")
                            border.color: "#1EFFFFFF"
                            border.width: 1
                            scale: symm.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                            Text {
                                anchors.centerIn: parent
                                text: root.symbolsMode ? "ABC" : "?123"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: root.symbolsMode ? "#0F172A" : "#E2E8F0"
                            }
                            MouseArea {
                                id: symm
                                anchors.fill: parent
                                onClicked: root.symbolsMode = !root.symbolsMode
                            }
                        }

                        // Comma
                        Rectangle {
                            Layout.preferredWidth: 50
                            Layout.fillHeight: true
                            radius: 6
                            color: cmm.pressed ? "#3B4456" : "#202533"
                            border.color: "#1EFFFFFF"
                            border.width: 1
                            scale: cmm.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                            Text {
                                anchors.centerIn: parent
                                text: ","
                                font.pixelSize: 16
                                color: "#F1F5F9"
                            }
                            MouseArea {
                                id: cmm
                                anchors.fill: parent
                                onClicked: root.sendKey(",")
                            }
                        }

                        // Spacebar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 6
                            color: spm.pressed ? "#3B4456" : "#202533"
                            border.color: "#1EFFFFFF"
                            border.width: 1
                            scale: spm.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                            Text {
                                anchors.centerIn: parent
                                text: "Space"
                                font.pixelSize: 13
                                color: "#94A3B8"
                            }
                            MouseArea {
                                id: spm
                                anchors.fill: parent
                                onClicked: root.sendKey(" ")
                            }
                        }

                        // Period
                        Rectangle {
                            Layout.preferredWidth: 50
                            Layout.fillHeight: true
                            radius: 6
                            color: dtm.pressed ? "#3B4456" : "#202533"
                            border.color: "#1EFFFFFF"
                            border.width: 1
                            scale: dtm.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                            Text {
                                anchors.centerIn: parent
                                text: "."
                                font.pixelSize: 16
                                color: "#F1F5F9"
                            }
                            MouseArea {
                                id: dtm
                                anchors.fill: parent
                                onClicked: root.sendKey(".")
                            }
                        }

                        // Unlock Button
                        Rectangle {
                            Layout.preferredWidth: 96
                            Layout.fillHeight: true
                            radius: 6
                            color: entm.pressed ? "#059669" : "#10B981"
                            border.color: "#20FFFFFF"
                            border.width: 1
                            scale: entm.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                            Text {
                                anchors.centerIn: parent
                                text: "Unlock ↵"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: "#FFFFFF"
                            }
                            MouseArea {
                                id: entm
                                anchors.fill: parent
                                onClicked: root.sendEnter()
                            }
                        }
                    }
                }
            }
        }
    }
}
