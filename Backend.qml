pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    property int consumers: 0
    property int pollSeconds: 3
    readonly property bool active: consumers > 0
    onActiveChanged: { if (active) refresh(); else { poll.running = false; navigation.running = false } }
    property var snapshot: ({ projects: [], counts: {}, total: 0, warnings: [] })
    property string error: ""
    property string actionError: ""
    property bool hasSnapshot: false
    property double lastSeen: 0
    property double now: Date.now()
    readonly property bool healthy: active && hasSnapshot && error === "" && now - lastSeen < 15000
    readonly property bool busy: poll.running
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("monitor.py").toString().replace(/^file:\/\//, ""))
    property bool received: false

    function refresh() {
        if (!active || poll.running || navigation.running) return
        received = false
        poll.running = true
    }
    function focusSession(workspace, pane) {
        if (!root.healthy || navigation.running) return
        actionError = ""
        navigation.command = ["python3", "-B", script, "focus", workspace, pane]
        navigation.running = true
    }

    Process {
        id: poll
        command: ["python3", "-B", root.script]
        stdout: SplitParser {
            onRead: function(line) {
                root.received = true
                try {
                    var response = JSON.parse(line)
                    if (!response.ok) { root.error = response.error || "invalid_response"; return }
                    var next = response.snapshot
                    if (!next || next.version !== 1 || !Array.isArray(next.projects)) throw new Error()
                    root.snapshot = next
                    root.now = root.lastSeen = Date.now()
                    root.hasSnapshot = true
                    root.error = ""
                } catch (e) { root.error = "invalid_response" }
            }
        }
        onExited: function(code) {
            if (!root.received) root.error = "unavailable"
        }
    }
    Process {
        id: navigation
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    var response = JSON.parse(line)
                    root.actionError = response.ok ? "" : (response.error || "navigation")
                } catch (e) { root.actionError = "navigation" }
            }
        }
        onExited: function(code) {
            if (code !== 0) root.actionError = "navigation"
            root.refresh()
        }
    }
    Timer {
        interval: root.error === "" ? root.pollSeconds * 1000 : Math.max(10000, root.pollSeconds * 1000)
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.now = Date.now()
    }
    IpcHandler {
        target: "voyagen.oma-orca-monitor.monitor"
        function status(): string {
            return JSON.stringify({active: root.active, busy: root.busy, healthy: root.healthy, error: root.error, actionError: root.actionError,
                                   snapshot: root.snapshot})
        }
        function refresh(): void { root.refresh() }
    }
}
