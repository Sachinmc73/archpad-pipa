/* main.qml
 * ArchPad Agent Manager — Plasma 6 Plasmoid
 */
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    Plasmoid.title: "Agent Manager"
    Plasmoid.icon: "utilities-terminal-symbolic"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus

    compactRepresentation: CompactRepresentation { plasmoidItem: root }
    fullRepresentation: FullRepresentation { plasmoidItem: root }

    // ── Data Properties ───────────────────────────────────────────────────────
    property var  providers:       []
    property int  activeCount:     0
    property bool refreshing:      false
    property string selectedProviderId: "agy"

    // ── Bot Animation ─────────────────────────────────────────────────────────
    readonly property var danceFrames: [
        Qt.resolvedUrl("icons/bot-dance-1.svg"),
        Qt.resolvedUrl("icons/bot-dance-2.svg"),
        Qt.resolvedUrl("icons/bot-dance-1.svg"),
        Qt.resolvedUrl("icons/bot-dance-4.svg"),
        Qt.resolvedUrl("icons/bot-dance-3.svg"),
        Qt.resolvedUrl("icons/bot-dance-5.svg")
    ]
    readonly property url idleIcon: Qt.resolvedUrl("icons/bot-idle.svg")
    property int danceFrameIdx: 0
    readonly property url currentBotIcon: activeCount > 0
        ? danceFrames[danceFrameIdx]
        : idleIcon

    Timer {
        id: danceTimer
        interval: 420
        repeat: true
        running: root.activeCount > 0
        onTriggered: root.danceFrameIdx = (root.danceFrameIdx + 1) % root.danceFrames.length
        onRunningChanged: if (!running) root.danceFrameIdx = 0
    }

    // ── Executable DataEngine ─────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: execEngine
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            var stdout = data["stdout"] ? data["stdout"].trim() : "";
            disconnectSource(source);
            root.refreshing = false;

            var sIdx = stdout.indexOf("{");
            var eIdx = stdout.lastIndexOf("}");
            if (sIdx === -1 || eIdx <= sIdx) return;

            try {
                var parsed = JSON.parse(stdout.substring(sIdx, eIdx + 1));
                root.providers = parsed.providers || [];
                var total = 0;
                for (var i = 0; i < root.providers.length; i++) {
                    total += root.providers[i].active_count || 0;
                }
                root.activeCount = total;
            } catch (e) {
                console.log("[AgentManager] JSON parse error:", e);
            }
        }
    }

    readonly property string dataProviderScript:
        "/home/archpad/.local/bin/archpad-agent-manager-provider"

    function fetchData(forceRefresh) {
        if (root.refreshing) return;
        root.refreshing = true;
        var cmd = root.dataProviderScript + (forceRefresh ? " --force-refresh" : "");
        execEngine.connectSource(cmd);
    }

    // ── Background Poll every 15s ─────────────────────────────────────────────
    Timer {
        id: bgTimer
        interval: 15000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.fetchData(false)
    }

    // ── Fetch immediately on open ─────────────────────────────────────────────
    onExpandedChanged: {
        if (root.expanded) root.fetchData(false);
    }

    Component.onCompleted: root.fetchData(false)
}
