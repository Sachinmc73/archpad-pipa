/* main.qml
 * ArchPad Agent Manager — Plasma 6 Plasmoid
 */
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: mainPlasmoid

    Plasmoid.title: "Agent Manager"
    Plasmoid.icon: "utilities-terminal-symbolic"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus

    compactRepresentation: CompactRepresentation { plasmoidItem: mainPlasmoid }
    fullRepresentation: FullRepresentation {
        plasmoidItem: mainPlasmoid
        providers: mainPlasmoid.providers
        refreshing: mainPlasmoid.refreshing
    }

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
    readonly property url currentBotIcon: mainPlasmoid.activeCount > 0
        ? danceFrames[danceFrameIdx]
        : idleIcon

    Timer {
        id: danceTimer
        interval: 420
        repeat: true
        running: mainPlasmoid.activeCount > 0
        onTriggered: mainPlasmoid.danceFrameIdx = (mainPlasmoid.danceFrameIdx + 1) % mainPlasmoid.danceFrames.length
        onRunningChanged: if (!running) mainPlasmoid.danceFrameIdx = 0
    }

    // ── Executable DataEngine ─────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: execEngine
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            var stdout = data["stdout"] ? data["stdout"].trim() : "";
            disconnectSource(source);
            mainPlasmoid.refreshing = false;

            var sIdx = stdout.indexOf("{");
            var eIdx = stdout.lastIndexOf("}");
            if (sIdx === -1 || eIdx <= sIdx) return;

            try {
                var parsed = JSON.parse(stdout.substring(sIdx, eIdx + 1));
                mainPlasmoid.providers = parsed.providers || [];
                var total = 0;
                for (var i = 0; i < mainPlasmoid.providers.length; i++) {
                    total += mainPlasmoid.providers[i].active_count || 0;
                }
                mainPlasmoid.activeCount = total;
            } catch (e) {
                console.warn("[AgentManager] JSON parse error:", e);
            }
        }
    }

    // ── Actions DataEngine ───────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: actionEngine
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            disconnectSource(source);
            mainPlasmoid.fetchData(false);
        }
    }

    readonly property string dataProviderScript:
        "/usr/bin/archpad-agent-manager-provider"

    function fetchData(forceRefresh) {
        if (mainPlasmoid.refreshing) return;
        mainPlasmoid.refreshing = true;
        var cmd = mainPlasmoid.dataProviderScript + (forceRefresh ? " --force-refresh" : "") + " #t=" + Date.now();
        execEngine.connectSource(cmd);
    }

    function openSession(workdir, conversationId, isActive) {
        var cmd = mainPlasmoid.dataProviderScript + " --action " + (isActive ? "focus" : "open");
        if (conversationId) {
            cmd += " --cid " + conversationId;
        }
        if (workdir) {
            cmd += " --workdir '" + workdir + "'";
        }
        cmd += " #t=" + Date.now();
        actionEngine.connectSource(cmd);
        mainPlasmoid.expanded = false;
    }

    function newSession(workdir) {
        var cmd = mainPlasmoid.dataProviderScript + " --action new";
        if (workdir) {
            cmd += " --workdir '" + workdir + "'";
        }
        cmd += " #t=" + Date.now();
        actionEngine.connectSource(cmd);
        mainPlasmoid.expanded = false;
    }

    function resumeLastSession() {
        var cmd = mainPlasmoid.dataProviderScript + " --action resume #t=" + Date.now();
        actionEngine.connectSource(cmd);
        mainPlasmoid.expanded = false;
    }

    // ── Background Poll every 15s ─────────────────────────────────────────────
    Timer {
        id: bgTimer
        interval: 15000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: mainPlasmoid.fetchData(false)
    }

    // ── Fetch immediately on open ─────────────────────────────────────────────
    onExpandedChanged: {
        if (mainPlasmoid.expanded) mainPlasmoid.fetchData(false);
    }

    Component.onCompleted: mainPlasmoid.fetchData(false)
}
