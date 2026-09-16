/* FullRepresentation.qml
 * Pixel-matched flat Adwaita/Omarchy-dark card for ArchPad Agent Manager
 * Exact recreation of Ubuntu agy-agent-manager stylesheet & layout.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: fullRoot
    required property PlasmoidItem plasmoidItem
    readonly property var root: plasmoidItem

    implicitWidth: 378
    implicitHeight: Math.min(cardContainer.implicitHeight, 560)
    Layout.preferredWidth: 378
    Layout.preferredHeight: Math.min(cardContainer.implicitHeight, 560)
    Layout.minimumWidth: 378
    Layout.minimumHeight: 280

    readonly property var currentProvider: {
        var pList = (root && root.providers) ? root.providers : [];
        if (!pList || pList.length === 0) return null;
        var selId = root ? root.selectedProviderId : "agy";
        for (var i = 0; i < pList.length; i++) {
            if (pList[i] && pList[i].id === selId) return pList[i];
        }
        return pList[0] || null;
    }

    // ── Launch helper ─────────────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: launchEngine
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) { disconnectSource(source); }
    }

    function launchSession(workdir, conversationId) {
        var cmd;
        if (conversationId) {
            cmd = "konsole --workdir '" + workdir + "' -e /home/archpad/.local/bin/agy --conversation " + conversationId;
        } else {
            cmd = "konsole --workdir '" + workdir + "' -e /home/archpad/.local/bin/agy";
        }
        launchEngine.connectSource(cmd);
        if (root) root.expanded = false;
    }

    function resumeLastSession() {
        var p = fullRoot.currentProvider;
        if (!p || !p.sessions) { launchSession("/home/archpad/Work", ""); return; }
        var active = null;
        for (var i = 0; i < p.sessions.length; i++) {
            if (p.sessions[i].is_active) { active = p.sessions[i]; break; }
        }
        if (active) {
            launchEngine.connectSource("qdbus6 org.kde.KWin /KWin activateWindow 0 2>/dev/null || true");
            if (root) root.expanded = false;
        } else if (p.sessions.length > 0) {
            var last = p.sessions[0];
            launchSession(last.workspace || "/home/archpad/Work", "--continue");
        } else {
            launchSession("/home/archpad/Work", "");
        }
    }

    // ── Main Card (Exact Omarchy Adwaita-dark: #20232c, radius 12, padding 12 14) ──
    Rectangle {
        id: cardContainer
        anchors.fill: parent
        color: "#20232c"
        radius: 12
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
        implicitHeight: mainCol.implicitHeight + 24

        // ── Loading Skeleton ──────────────────────────────────────────────────
        ColumnLayout {
            anchors.centerIn: parent
            visible: !fullRoot.currentProvider
            spacing: 8

            Kirigami.Icon {
                source: (root && root.currentBotIcon) ? root.currentBotIcon : ""
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                isMask: true
                color: "#ffffff"
            }

            Text {
                text: "Loading Antigravity data…"
                font.pixelSize: 12
                color: "#9a9996"
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // ── Populated View ────────────────────────────────────────────────────
        ColumnLayout {
            id: mainCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 8
            visible: !!fullRoot.currentProvider

            // ── 1. HEADER ─────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Hero Bot Icon (24x24)
                Kirigami.Icon {
                    source: (root && root.currentBotIcon) ? root.currentBotIcon : ""
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    isMask: true
                    color: (root && root.activeCount > 0) ? "#2ec27e" : "#ffffff"
                }

                // Title + Account Badge & Tier
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    RowLayout {
                        spacing: 6
                        Text {
                            text: fullRoot.currentProvider ? (fullRoot.currentProvider.name || "Antigravity") : ""
                            font.pixelSize: 13
                            font.bold: true
                            color: "#ffffff"
                        }
                        // Account badge
                        Rectangle {
                            visible: !!(fullRoot.currentProvider && fullRoot.currentProvider.account)
                            color: Qt.rgba(53/255, 132/255, 228/255, 0.14)
                            border.color: Qt.rgba(53/255, 132/255, 228/255, 0.28)
                            border.width: 1
                            radius: 6
                            implicitWidth: acctTxt.implicitWidth + 12
                            implicitHeight: 18
                            Text {
                                id: acctTxt
                                anchors.centerIn: parent
                                text: (fullRoot.currentProvider && fullRoot.currentProvider.account) ? fullRoot.currentProvider.account : ""
                                font.pixelSize: 10
                                font.bold: true
                                color: "#78aeed"
                            }
                        }
                    }

                    Text {
                        text: fullRoot.currentProvider ? (fullRoot.currentProvider.tier || "") : ""
                        font.pixelSize: 11
                        color: "#9a9996"
                    }
                }

                // Status Pill
                Rectangle {
                    color: (root && root.activeCount > 0)
                        ? Qt.rgba(46/255, 194/255, 126/255, 0.18)
                        : Qt.rgba(1, 1, 1, 0.06)
                    border.color: (root && root.activeCount > 0)
                        ? Qt.rgba(46/255, 194/255, 126/255, 0.35)
                        : Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1
                    radius: 10
                    implicitWidth: pillText.implicitWidth + 16
                    implicitHeight: 20

                    Text {
                        id: pillText
                        anchors.centerIn: parent
                        text: (root && root.activeCount > 0) ? (root.activeCount + " active") : "Idle"
                        font.pixelSize: 10
                        font.bold: (root && root.activeCount > 0)
                        color: (root && root.activeCount > 0) ? "#2ec27e" : "#9a9996"
                    }
                }

                // Refresh Button
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 6
                    color: rfMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: (root && root.refreshing) ? "process-working-symbolic" : "view-refresh-symbolic"
                        implicitWidth: 12
                        implicitHeight: 12
                        isMask: true
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: rfMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (root) root.fetchData(true)
                    }
                }
            }

            // ── 2. PROVIDER TABS ──────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                radius: 6

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 4

                    Repeater {
                        model: (root && root.providers) ? root.providers : []
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 4
                            readonly property bool isSelected: !!(root && modelData.id === root.selectedProviderId)
                            color: isSelected ? Qt.rgba(1, 1, 1, 0.14) : (tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name || ""
                                font.pixelSize: 11
                                font.bold: true
                                color: isSelected ? "#ffffff" : "#9a9996"
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: if (root) root.selectedProviderId = modelData.id
                            }
                        }
                    }
                }
            }

            // Separator
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            // ── 3. LIMITS ─────────────────────────────────────────────────────
            Text {
                text: "LIMITS"
                font.pixelSize: 10
                font.bold: true
                color: "#9a9996"
            }

            Repeater {
                model: (fullRoot.currentProvider && fullRoot.currentProvider.limits) ? fullRoot.currentProvider.limits : []
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: modelData.title || ""
                            font.pixelSize: 12
                            color: "#ffffff"
                            Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.percent_str || (modelData.percent_int + "% remaining")
                            font.pixelSize: 11
                            font.bold: true
                            color: modelData.alarming ? "#e01b24" : "#9a9996"
                        }
                    }

                    // Meter track (5px, radius 3, rgba(255,255,255,0.12))
                    Rectangle {
                        id: limitTrack
                        Layout.fillWidth: true
                        implicitHeight: 5
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.12)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(4, Math.min(limitTrack.width, limitTrack.width * (modelData.percent || 0)))
                            radius: 3
                            color: modelData.alarming ? "#e01b24" : "#deddda"
                        }
                    }

                    Text {
                        text: modelData.resets_in || ""
                        font.pixelSize: 10
                        color: "#8c8b88"
                    }
                }
            }

            // Separator
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            // ── 4. ACTIVITY (7 DAYS) ──────────────────────────────────────────
            Text {
                text: "ACTIVITY (7 DAYS)"
                font.pixelSize: 10
                font.bold: true
                color: "#9a9996"
            }

            Repeater {
                model: (fullRoot.currentProvider && fullRoot.currentProvider.recent_days) ? fullRoot.currentProvider.recent_days : []
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: modelData.day || ""
                        font.pixelSize: 11
                        font.bold: !!modelData.is_today
                        color: modelData.is_today ? "#ffffff" : "#8c8b88"
                        Layout.preferredWidth: 44
                    }

                    Rectangle {
                        id: dayTrack
                        Layout.fillWidth: true
                        implicitHeight: 5
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.12)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(4, Math.min(dayTrack.width, dayTrack.width * (modelData.ratio || 0)))
                            radius: 3
                            color: "#deddda"
                        }
                    }

                    Text {
                        text: modelData.count_str || "0"
                        font.pixelSize: 11
                        font.bold: !!modelData.is_today
                        color: modelData.is_today ? "#ffffff" : "#8c8b88"
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // Separator
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            // ── 5. ACTIONS ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // New Session (Primary Blue #3584e4)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 6
                    color: newMouse.containsMouse ? "#1c71d8" : "#3584e4"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Kirigami.Icon {
                            source: "list-add-symbolic"
                            implicitWidth: 12
                            implicitHeight: 12
                            isMask: true
                            color: "#ffffff"
                        }
                        Text {
                            text: "New Session"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    MouseArea {
                        id: newMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: fullRoot.launchSession("/home/archpad/Work", "")
                    }
                }

                // Resume Last (Secondary)
                Rectangle {
                    implicitWidth: 110
                    implicitHeight: 30
                    radius: 6
                    color: resMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Kirigami.Icon {
                            source: "media-playback-start-symbolic"
                            implicitWidth: 12
                            implicitHeight: 12
                            isMask: true
                            color: "#ffffff"
                        }
                        Text {
                            text: "Resume Last"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    MouseArea {
                        id: resMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: fullRoot.resumeLastSession()
                    }
                }
            }

            // Separator
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            // ── 6. RECENT SESSIONS ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "RECENT SESSIONS"
                    font.pixelSize: 10
                    font.bold: true
                    color: "#9a9996"
                    Layout.fillWidth: true
                }
                Text {
                    text: (fullRoot.currentProvider && fullRoot.currentProvider.sessions) ? fullRoot.currentProvider.sessions.length : "0"
                    font.pixelSize: 11
                    color: "#9a9996"
                }
            }

            // Scrollable sessions (max height 160)
            ListView {
                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 160)
                clip: true
                spacing: 4
                model: (fullRoot.currentProvider && fullRoot.currentProvider.sessions) ? fullRoot.currentProvider.sessions : []

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: sCol.implicitHeight + 12
                    radius: 6
                    color: sMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: sMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1

                    ColumnLayout {
                        id: sCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 8
                        spacing: 3

                        // Top row: dot + title + time
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: modelData.is_active ? "#2ec27e" : "#5e6573"
                            }

                            Text {
                                text: modelData.title || "Untitled"
                                font.pixelSize: 12
                                font.bold: !!modelData.is_active
                                color: "#ffffff"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.time_ago || ""
                                font.pixelSize: 10
                                color: "#8c8b88"
                            }
                        }

                        // Bottom row: meta + action badge
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: (modelData.workspace_name || "") + " • " + (modelData.steps_str || "")
                                font.pixelSize: 10
                                color: "#8c8b88"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                implicitWidth: btnTxt.implicitWidth + 16
                                implicitHeight: 20
                                radius: 4
                                color: modelData.is_active
                                    ? (actMouse.containsMouse ? "#2ec27e" : Qt.rgba(46/255, 194/255, 126/255, 0.14))
                                    : (actMouse.containsMouse ? "#3584e4" : Qt.rgba(53/255, 132/255, 228/255, 0.14))
                                border.color: modelData.is_active
                                    ? Qt.rgba(46/255, 194/255, 126/255, 0.28)
                                    : Qt.rgba(53/255, 132/255, 228/255, 0.25)
                                border.width: 1

                                Text {
                                    id: btnTxt
                                    anchors.centerIn: parent
                                    text: modelData.is_active ? "Focus" : "Resume"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: actMouse.containsMouse
                                        ? "#ffffff"
                                        : (modelData.is_active ? "#2ec27e" : "#3584e4")
                                }

                                MouseArea {
                                    id: actMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (modelData.is_active) {
                                            if (root) root.expanded = false;
                                        } else {
                                            fullRoot.launchSession(modelData.workspace || "/home/archpad/Work", modelData.id);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: sMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!modelData.is_active) {
                                fullRoot.launchSession(modelData.workspace || "/home/archpad/Work", modelData.id);
                            } else {
                                if (root) root.expanded = false;
                            }
                        }
                    }
                }
            }

            // ── 7. WORKSPACES ─────────────────────────────────────────────────
            Text {
                visible: !!(fullRoot.currentProvider && fullRoot.currentProvider.workspaces && fullRoot.currentProvider.workspaces.length > 0)
                text: "WORKSPACES"
                font.pixelSize: 10
                font.bold: true
                color: "#9a9996"
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: !!(fullRoot.currentProvider && fullRoot.currentProvider.workspaces && fullRoot.currentProvider.workspaces.length > 0)

                Repeater {
                    model: (fullRoot.currentProvider && fullRoot.currentProvider.workspaces) ? fullRoot.currentProvider.workspaces : []
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: wsText.implicitWidth + 16
                        implicitHeight: 22
                        radius: 5
                        color: wsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        Text {
                            id: wsText
                            anchors.centerIn: parent
                            text: modelData.name || ""
                            font.pixelSize: 10
                            color: wsMouse.containsMouse ? "#ffffff" : "#9a9996"
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: fullRoot.launchSession(modelData.path || "/home/archpad/Work", "")
                        }
                    }
                }
            }
        }
    }
}
