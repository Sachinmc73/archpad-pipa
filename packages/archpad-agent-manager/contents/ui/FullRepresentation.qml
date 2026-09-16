/* FullRepresentation.qml
 * Full popup panel for ArchPad Agent Manager
 * Mirrors the GNOME extension's feature set in native Plasma/Kirigami QML
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
    property var plasmoidItem: null
    readonly property var root: plasmoidItem

    implicitWidth: Kirigami.Units.gridUnit * 22
    implicitHeight: Math.min(mainLayout.implicitHeight + Kirigami.Units.largeSpacing * 2,
                             Kirigami.Units.gridUnit * 36)

    // ── Resolve current provider from root state ───────────────────────────────
    readonly property var currentProvider: {
        var pList = (root && root.providers) ? root.providers : [];
        if (!pList || pList.length === 0) return {};
        var selId = root ? root.selectedProviderId : "agy";
        for (var i = 0; i < pList.length; i++) {
            if (pList[i] && pList[i].id === selId) return pList[i];
        }
        return pList[0] || {};
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

    // ── Scrollable Main Layout ────────────────────────────────────────────────
    QQC2.ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

        ColumnLayout {
            id: mainLayout
            width: fullRoot.width
            spacing: 0

            // ── 1. HEADER ─────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                // Bot hero icon
                Image {
                    source: (root && root.currentBotIcon) ? root.currentBotIcon : ""
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        PlasmaComponents3.Label {
                            text: (fullRoot.currentProvider && fullRoot.currentProvider.name) ? fullRoot.currentProvider.name : "Agent Manager"
                            font.bold: true
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                        }
                        // Account badge
                        Rectangle {
                            visible: !!(fullRoot.currentProvider && fullRoot.currentProvider.account)
                            color: Qt.rgba(0.2, 0.47, 0.9, 0.15)
                            border.color: Qt.rgba(0.2, 0.47, 0.9, 0.3)
                            border.width: 1
                            radius: 4
                            implicitWidth: accountLabel.implicitWidth + 10
                            implicitHeight: accountLabel.implicitHeight + 4
                            PlasmaComponents3.Label {
                                id: accountLabel
                                anchors.centerIn: parent
                                text: (fullRoot.currentProvider && fullRoot.currentProvider.account) ? fullRoot.currentProvider.account : ""
                                font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                                color: Kirigami.Theme.highlightColor
                            }
                        }
                    }
                    PlasmaComponents3.Label {
                        text: (fullRoot.currentProvider && fullRoot.currentProvider.tier) ? fullRoot.currentProvider.tier : ""
                        font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                // Status pill
                Rectangle {
                    color: (root && root.activeCount > 0)
                        ? Qt.rgba(0.18, 0.76, 0.49, 0.18)
                        : Qt.rgba(1, 1, 1, 0.06)
                    border.color: (root && root.activeCount > 0)
                        ? Qt.rgba(0.18, 0.76, 0.49, 0.35)
                        : Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1
                    radius: 8
                    implicitWidth: statusLabel.implicitWidth + 14
                    implicitHeight: statusLabel.implicitHeight + 6
                    PlasmaComponents3.Label {
                        id: statusLabel
                        anchors.centerIn: parent
                        text: (root && root.activeCount > 0) ? root.activeCount + " active" : "Idle"
                        font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                        font.bold: root ? root.activeCount > 0 : false
                        color: (root && root.activeCount > 0) ? "#2ec27e" : Kirigami.Theme.disabledTextColor
                    }
                }

                // Refresh button
                PlasmaComponents3.ToolButton {
                    icon.name: (root && root.refreshing) ? "process-working-symbolic" : "view-refresh-symbolic"
                    enabled: !root || !root.refreshing
                    implicitWidth: Kirigami.Units.gridUnit * 2
                    implicitHeight: Kirigami.Units.gridUnit * 2
                    onClicked: if (root) root.fetchData(true)
                    PlasmaComponents3.ToolTip { text: "Refresh" }
                }
            }

            // ── 2. PROVIDER TABS ──────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                spacing: 4

                Repeater {
                    model: (root && root.providers) ? root.providers : []
                    delegate: PlasmaComponents3.Button {
                        required property var modelData
                        text: modelData.name || ""
                        flat: !root || (modelData.id !== root.selectedProviderId)
                        highlighted: !!(root && modelData.id === root.selectedProviderId)
                        Layout.fillWidth: true
                        font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                        onClicked: if (root) root.selectedProviderId = modelData.id
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; Layout.leftMargin: Kirigami.Units.largeSpacing; Layout.rightMargin: Kirigami.Units.largeSpacing }

            // ── 3. LIMITS ─────────────────────────────────────────────────────
            PlasmaComponents3.Label {
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: "LIMITS"
                font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                font.bold: true
                font.letterSpacing: 0.8
                color: Kirigami.Theme.disabledTextColor
            }

            Repeater {
                model: (fullRoot.currentProvider && fullRoot.currentProvider.limits) ? fullRoot.currentProvider.limits : []
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.bottomMargin: 4
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents3.Label {
                            text: modelData.title || ""
                            Layout.fillWidth: true
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                        }
                        PlasmaComponents3.Label {
                            text: modelData.percent_str || (modelData.percent_int + "% remaining")
                            font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                            font.bold: true
                            color: modelData.alarming ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
                        }
                    }

                    QQC2.ProgressBar {
                        Layout.fillWidth: true
                        value: modelData.percent || 0
                        from: 0; to: 1
                    }

                    PlasmaComponents3.Label {
                        text: modelData.resets_in || ""
                        font.pointSize: Math.max(6, Kirigami.Theme.defaultFont.pointSize - 3)
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; Layout.leftMargin: Kirigami.Units.largeSpacing; Layout.rightMargin: Kirigami.Units.largeSpacing }

            // ── 4. ACTIVITY (7 DAYS) ──────────────────────────────────────────
            PlasmaComponents3.Label {
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: "ACTIVITY (7 DAYS)"
                font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                font.bold: true
                font.letterSpacing: 0.8
                color: Kirigami.Theme.disabledTextColor
            }

            Repeater {
                model: (fullRoot.currentProvider && fullRoot.currentProvider.recent_days) ? fullRoot.currentProvider.recent_days : []
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.bottomMargin: 2
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.Label {
                        text: modelData.day || ""
                        font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                        font.bold: !!modelData.is_today
                        color: modelData.is_today ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                    }

                    QQC2.ProgressBar {
                        Layout.fillWidth: true
                        value: modelData.ratio || 0
                        from: 0; to: 1
                    }

                    PlasmaComponents3.Label {
                        text: modelData.count_str || "0"
                        font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                        font.bold: !!modelData.is_today
                        color: modelData.is_today ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; Layout.leftMargin: Kirigami.Units.largeSpacing; Layout.rightMargin: Kirigami.Units.largeSpacing }

            // ── 5. ACTIONS ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    text: "New Session"
                    Layout.fillWidth: true
                    icon.name: "list-add-symbolic"
                    onClicked: fullRoot.launchSession("/home/archpad/Work", "")
                }

                PlasmaComponents3.Button {
                    text: "Resume Last"
                    icon.name: "media-playback-start-symbolic"
                    onClicked: fullRoot.resumeLastSession()
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; Layout.leftMargin: Kirigami.Units.largeSpacing; Layout.rightMargin: Kirigami.Units.largeSpacing }

            // ── 6. RECENT SESSIONS ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.topMargin: Kirigami.Units.smallSpacing
                PlasmaComponents3.Label {
                    text: "RECENT SESSIONS"
                    Layout.fillWidth: true
                    font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                    font.bold: true
                    font.letterSpacing: 0.8
                    color: Kirigami.Theme.disabledTextColor
                }
                PlasmaComponents3.Label {
                    text: (fullRoot.currentProvider && fullRoot.currentProvider.sessions) ? fullRoot.currentProvider.sessions.length : 0
                    font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                    color: Kirigami.Theme.disabledTextColor
                }
            }

            Repeater {
                model: (fullRoot.currentProvider && fullRoot.currentProvider.sessions) ? fullRoot.currentProvider.sessions : []
                delegate: Item {
                    required property var modelData
                    Layout.fillWidth: true
                    width: parent ? parent.width : 0
                    height: sessionCol.implicitHeight + Kirigami.Units.smallSpacing

                    // Hover background
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.largeSpacing
                        anchors.rightMargin: Kirigami.Units.largeSpacing
                        color: sessionArea.containsMouse
                            ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                      Kirigami.Theme.highlightColor.g,
                                      Kirigami.Theme.highlightColor.b, 0.08)
                            : Qt.rgba(1, 1, 1, 0.04)
                        border.color: Qt.rgba(1, 1, 1, sessionArea.containsMouse ? 0.12 : 0.05)
                        border.width: 1
                        radius: 6
                    }

                    ColumnLayout {
                        id: sessionCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            // Active/idle dot
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: modelData.is_active ? "#2ec27e" : Kirigami.Theme.disabledTextColor
                            }

                            PlasmaComponents3.Label {
                                text: modelData.title || "Untitled"
                                Layout.fillWidth: true
                                font.bold: !!modelData.is_active
                                elide: Text.ElideRight
                            }

                            PlasmaComponents3.Label {
                                text: modelData.time_ago || ""
                                font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                                color: Kirigami.Theme.disabledTextColor
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            PlasmaComponents3.Label {
                                text: (modelData.workspace_name || "") + " • " + (modelData.steps_str || "")
                                font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                                color: Kirigami.Theme.disabledTextColor
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            PlasmaComponents3.Button {
                                text: modelData.is_active ? "Focus" : "Resume"
                                flat: true
                                font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                                onClicked: {
                                    if (modelData.is_active) {
                                        if (root) root.expanded = false;
                                    } else {
                                        fullRoot.launchSession(
                                            modelData.workspace || "/home/archpad/Work",
                                            modelData.id
                                        );
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: sessionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!modelData.is_active) {
                                fullRoot.launchSession(
                                    modelData.workspace || "/home/archpad/Work",
                                    modelData.id
                                );
                            } else {
                                if (root) root.expanded = false;
                            }
                        }
                    }
                }
            }

            // ── 7. WORKSPACES ─────────────────────────────────────────────────
            PlasmaComponents3.Label {
                visible: !!(fullRoot.currentProvider && fullRoot.currentProvider.workspaces && fullRoot.currentProvider.workspaces.length > 0)
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: "WORKSPACES"
                font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                font.bold: true
                font.letterSpacing: 0.8
                color: Kirigami.Theme.disabledTextColor
            }

            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                spacing: 6

                Repeater {
                    model: (fullRoot.currentProvider && fullRoot.currentProvider.workspaces) ? fullRoot.currentProvider.workspaces : []
                    delegate: PlasmaComponents3.Button {
                        required property var modelData
                        text: modelData.name || ""
                        flat: true
                        font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                        onClicked: fullRoot.launchSession(modelData.path || "/home/archpad/Work", "")
                    }
                }
            }
        }
    }
}
