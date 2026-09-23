/* FullRepresentation.qml
 * ArchPad Agent Manager — Native KDE Plasma 6 & Kirigami Full Representation
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmaExtras.Representation {
    id: fullRoot

    implicitWidth: Kirigami.Units.gridUnit * 22
    implicitHeight: Kirigami.Units.gridUnit * 32
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Kirigami.Units.gridUnit * 32
    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: Kirigami.Units.gridUnit * 20

    // ── Plasmoid Link & Model State ──────────────────────────────────────────
    property PlasmoidItem plasmoidItem: null

    property var  providers:          (plasmoidItem && plasmoidItem.providers) ? plasmoidItem.providers : []
    property bool refreshing:         plasmoidItem ? plasmoidItem.refreshing : false
    property string selectedProviderId: (plasmoidItem && plasmoidItem.selectedProviderId) ? plasmoidItem.selectedProviderId : "agy"

    onSelectedProviderIdChanged: {
        if (plasmoidItem && plasmoidItem.selectedProviderId !== selectedProviderId) {
            plasmoidItem.selectedProviderId = selectedProviderId;
        }
    }

    readonly property var currentProvider: {
        if (!providers || providers.length === 0) return null;
        for (var i = 0; i < providers.length; i++) {
            if (providers[i] && providers[i].id === selectedProviderId) return providers[i];
        }
        return providers[0] || null;
    }

    readonly property int totalActiveCount: {
        if (!providers) return 0;
        var total = 0;
        for (var i = 0; i < providers.length; i++) {
            total += providers[i].active_count || 0;
        }
        return total;
    }

    function fetchData(forceRefresh) {
        if (plasmoidItem) {
            plasmoidItem.fetchData(forceRefresh);
        }
    }

    function openSession(workdir, conversationId, isActive) {
        if (plasmoidItem) {
            plasmoidItem.openSession(workdir, conversationId, isActive);
        }
    }

    function newSession(workdir) {
        if (plasmoidItem) {
            plasmoidItem.newSession(workdir);
        }
    }

    function resumeLastSession() {
        if (plasmoidItem) {
            plasmoidItem.resumeLastSession();
        }
    }

    onVisibleChanged: {
        if (visible && plasmoidItem) {
            plasmoidItem.fetchData(false);
        }
    }

    Component.onCompleted: {
        if (plasmoidItem) {
            plasmoidItem.fetchData(false);
        }
    }

    // ── Header ────────────────────────────────────────────────────────────────
    header: PlasmaExtras.PlasmoidHeading {
        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: Qt.resolvedUrl("icons/bot-idle.svg")
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                isMask: true
                color: (fullRoot.totalActiveCount > 0) ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Kirigami.Heading {
                    text: fullRoot.currentProvider ? (fullRoot.currentProvider.name || i18n("Agent Manager")) : i18n("Agent Manager")
                    level: 3
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                PlasmaComponents3.Label {
                    text: fullRoot.currentProvider ? (fullRoot.currentProvider.account || fullRoot.currentProvider.tier || "") : ""
                    font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                    opacity: 0.7
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            // Status Badge
            Rectangle {
                implicitWidth: badgeText.implicitWidth + Kirigami.Units.largeSpacing
                implicitHeight: badgeText.implicitHeight + Kirigami.Units.smallSpacing
                radius: height / 2
                color: (fullRoot.totalActiveCount > 0)
                    ? Qt.alpha(Kirigami.Theme.positiveTextColor, 0.18)
                    : Qt.alpha(Kirigami.Theme.textColor, 0.08)
                border.color: (fullRoot.totalActiveCount > 0)
                    ? Qt.alpha(Kirigami.Theme.positiveTextColor, 0.35)
                    : Qt.alpha(Kirigami.Theme.textColor, 0.15)
                border.width: 1

                PlasmaComponents3.Label {
                    id: badgeText
                    anchors.centerIn: parent
                    text: (fullRoot.totalActiveCount > 0) ? (fullRoot.totalActiveCount + " active") : i18n("Idle")
                    font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                    font.bold: fullRoot.totalActiveCount > 0
                    color: (fullRoot.totalActiveCount > 0) ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                }
            }

            PlasmaComponents3.ToolButton {
                icon.name: fullRoot.refreshing ? "process-working" : "view-refresh"
                text: i18n("Refresh")
                display: PlasmaComponents3.AbstractButton.IconOnly
                onClicked: fullRoot.fetchData(true)
            }
        }
    }

    // ── Main Content Area ─────────────────────────────────────────────────────
    contentItem: Item {
        // Loading State
        ColumnLayout {
            anchors.centerIn: parent
            visible: !fullRoot.currentProvider || fullRoot.providers.length === 0
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents3.BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: parent.visible
            }

            PlasmaComponents3.Label {
                text: i18n("Loading agent data…")
                opacity: 0.7
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Populated Content ScrollView
        PlasmaComponents3.ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            visible: !!fullRoot.currentProvider && fullRoot.providers.length > 0
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width
                spacing: Kirigami.Units.mediumSpacing

                // ── 1. Provider Tabs (if multi-provider) ──────────────────────
                Item {
                    Layout.fillWidth: true
                    implicitHeight: providerTabBar.implicitHeight
                    visible: !!(fullRoot.providers && fullRoot.providers.length > 1)

                    PlasmaComponents3.TabBar {
                        id: providerTabBar
                        anchors.fill: parent
                        currentIndex: {
                            if (!fullRoot.providers) return 0;
                            for (var i = 0; i < fullRoot.providers.length; i++) {
                                if (fullRoot.providers[i].id === fullRoot.selectedProviderId) return i;
                            }
                            return 0;
                        }

                        Repeater {
                            model: fullRoot.providers || []
                            PlasmaComponents3.TabButton {
                                required property var modelData
                                text: modelData.name || ""
                                onClicked: fullRoot.selectedProviderId = modelData.id
                            }
                        }
                    }
                }

                // ── 2. Primary Actions ────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.Button {
                        Layout.fillWidth: true
                        text: i18n("New Session")
                        icon.name: "list-add"
                        highlighted: true
                        onClicked: fullRoot.newSession("")
                    }

                    PlasmaComponents3.Button {
                        Layout.fillWidth: true
                        text: i18n("Resume Last")
                        icon.name: "media-playback-start"
                        onClicked: fullRoot.resumeLastSession()
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                // ── 3. Limits / Quotas ────────────────────────────────────────
                Kirigami.Heading {
                    text: i18n("Resource Limits")
                    level: 4
                    visible: !!(fullRoot.currentProvider && fullRoot.currentProvider.limits && fullRoot.currentProvider.limits.length > 0)
                }

                Repeater {
                    model: (fullRoot.currentProvider && fullRoot.currentProvider.limits) ? fullRoot.currentProvider.limits : []
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents3.Label {
                                text: modelData.title || ""
                                Layout.fillWidth: true
                                font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 1)
                            }
                            PlasmaComponents3.Label {
                                text: modelData.percent_str || (modelData.percent_int + "% remaining")
                                font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                                font.bold: true
                                color: modelData.alarming ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                            }
                        }

                        PlasmaComponents3.ProgressBar {
                            Layout.fillWidth: true
                            from: 0.0
                            to: 1.0
                            value: Math.max(0.0, Math.min(1.0, Number(modelData.percent) || 0.0))
                        }

                        PlasmaComponents3.Label {
                            text: modelData.resets_in || ""
                            font.pointSize: Math.max(6, Kirigami.Theme.defaultFont.pointSize - 3)
                            opacity: 0.6
                        }
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                // ── 4. 7-Day Activity ─────────────────────────────────────────
                Kirigami.Heading {
                    text: i18n("Activity (Last 7 Days)")
                    level: 4
                    visible: !!(fullRoot.currentProvider && fullRoot.currentProvider.recent_days && fullRoot.currentProvider.recent_days.length > 0)
                }

                Repeater {
                    model: (fullRoot.currentProvider && fullRoot.currentProvider.recent_days) ? fullRoot.currentProvider.recent_days : []
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents3.Label {
                            text: modelData.day || ""
                            font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                            font.bold: !!modelData.is_today
                            color: modelData.is_today ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                        }

                        PlasmaComponents3.ProgressBar {
                            Layout.fillWidth: true
                            from: 0.0
                            to: 1.0
                            value: Math.max(0.0, Math.min(1.0, Number(modelData.ratio) || 0.0))
                        }

                        PlasmaComponents3.Label {
                            text: modelData.count_str || "0"
                            font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                            font.bold: !!modelData.is_today
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                // ── 5. Recent Sessions ────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Kirigami.Heading {
                        text: i18n("Recent Sessions")
                        level: 4
                        Layout.fillWidth: true
                    }
                    PlasmaComponents3.Label {
                        text: (fullRoot.currentProvider && fullRoot.currentProvider.sessions) ? fullRoot.currentProvider.sessions.length : 0
                        font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                        opacity: 0.6
                    }
                }

                Repeater {
                    model: (fullRoot.currentProvider && fullRoot.currentProvider.sessions) ? fullRoot.currentProvider.sessions : []
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: sessionRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                        radius: Kirigami.Units.smallSpacing
                        color: sArea.containsMouse ? Qt.alpha(Kirigami.Theme.textColor, 0.08) : Qt.alpha(Kirigami.Theme.textColor, 0.03)
                        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.1)
                        border.width: 1

                        RowLayout {
                            id: sessionRow
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.smallSpacing

                            // Dot
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: modelData.is_active ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                PlasmaComponents3.Label {
                                    text: modelData.title || "Untitled"
                                    Layout.fillWidth: true
                                    font.bold: !!modelData.is_active
                                    elide: Text.ElideRight
                                    font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 1)
                                }

                                PlasmaComponents3.Label {
                                    text: (modelData.workspace_name || "") + " • " + (modelData.steps_str || "") + " • " + (modelData.time_ago || "")
                                    font.pointSize: Math.max(6, Kirigami.Theme.defaultFont.pointSize - 3)
                                    opacity: 0.6
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            PlasmaComponents3.Button {
                                text: modelData.is_active ? i18n("Focus") : i18n("Resume")
                                icon.name: modelData.is_active ? "window-focus" : "media-playback-start"
                                font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                                onClicked: fullRoot.openSession(modelData.workspace, modelData.id, modelData.is_active)
                            }
                        }

                        MouseArea {
                            id: sArea
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: false
                            z: -1
                            onClicked: fullRoot.openSession(modelData.workspace, modelData.id, modelData.is_active)
                        }
                    }
                }

                // ── 6. Quick Workspaces ───────────────────────────────────────
                Kirigami.Heading {
                    text: i18n("Workspaces")
                    level: 4
                    visible: !!(fullRoot.currentProvider && fullRoot.currentProvider.workspaces && fullRoot.currentProvider.workspaces.length > 0)
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    visible: !!(fullRoot.currentProvider && fullRoot.currentProvider.workspaces && fullRoot.currentProvider.workspaces.length > 0)

                    Repeater {
                        model: (fullRoot.currentProvider && fullRoot.currentProvider.workspaces) ? fullRoot.currentProvider.workspaces : []
                        delegate: PlasmaComponents3.Button {
                            required property var modelData
                            text: modelData.name || ""
                            icon.name: "folder"
                            font.pointSize: Math.max(7, Kirigami.Theme.defaultFont.pointSize - 2)
                            onClicked: fullRoot.newSession(modelData.path)
                        }
                    }
                }
            }
        }
    }
}
