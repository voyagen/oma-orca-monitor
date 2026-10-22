import QtQuick
import Quickshell
import qs.Commons as Commons

ShellRoot {
    id: test
    property int phase: 0
    property var spinner: null
    property real previousRotation: 0
    property var barStatus: null
    property var barSpinner: null
    property real previousBarRotation: 0
    QtObject {
        id: source
        property bool healthy: true
        property bool busy: false
        property bool hasSnapshot: true
        property string error: ""
        property string actionError: ""
        property double now: Date.now()
        property int opened: 0
        property string target: ""
        property var snapshot: ({total: 4, counts: {working: 2, done: 1, unknown: 1}, warnings: [], projects: [{name: "Project", host: "local", workspaces: [
            {id: "first", name: "First", branch: "main", active: true, state: "working", agents: [
                {workspace: "first", pane: "stale", type: "pi", label: "Old pane", state: "working", since: 0, selectable: false},
                {workspace: "first", pane: "live", type: "pi", label: "Live pane", state: "working", since: 0, selectable: true}]},
            {id: "second", name: "Second", branch: "topic", active: false, state: "done", agents: [
                {workspace: "second", pane: "other", type: "claude", label: "Done", state: "done", since: 0, selectable: true}]},
            {id: "offline", name: "Offline", branch: "", active: false, state: "unknown", agents: [
                {workspace: "offline", pane: "missing", type: "pi", label: "Missing", state: "unknown", since: 0, selectable: false}]}
        ]}]})
        function refresh() {}
        function focusSession(workspace, pane) { opened++; target = workspace + "/" + pane }
    }
    Item {
        id: barHost
        BarStatus { id: hoverStatus; monitor: source }
    }
    StatusIndicator { id: themeAttention; state: "attention"; visible: false }
    StatusIndicator { id: themeDone; state: "done"; visible: false }
    AgentIcon { id: unknownProvider; agent: "__proto__"; visible: false }
    Item {
        id: providers
        visible: false
        Repeater {
            model: Object.keys(unknownProvider.assets)
            AgentIcon { required property string modelData; agent: modelData }
        }
    }
    MonitorContent { id: view; width: 430; height: 600; monitor: source }
    function descendants(item) {
        var found = []
        for (var child of item.children) found = found.concat([child], descendants(child))
        return found
    }
    function check(condition, message) { if (!condition) throw new Error(message) }
    Timer {
        interval: 250
        repeat: true
        running: true
        onTriggered: {
            try {
                if (test.phase === 0) {
                    test.barStatus = hoverStatus
                    test.check(test.barStatus.state === "working", "bar shows pending while any agent works")
                    test.check(test.barStatus.tooltipText.indexOf("2 working") !== -1, "hover summarizes working sessions")
                    var originalSnapshot = source.snapshot
                    var renamedSnapshot = JSON.parse(JSON.stringify(originalSnapshot))
                    renamedSnapshot.projects[0].name = "Renamed project"
                    renamedSnapshot.projects[0].icon = "✈️"
                    source.snapshot = renamedSnapshot
                    var renamedItems = test.descendants(view)
                    test.check(renamedItems.some(function(item) { return item.text === "Renamed project" }), "project display name updates from each snapshot")
                    test.check(renamedItems.some(function(item) { return item.text === "✈️" && item.visible }), "configured project emoji updates automatically")
                    source.snapshot = originalSnapshot
                    for (var sample of [
                        [{done: 4}, 4, "done"], [{ready: 4}, 4, "done"],
                        [{attention: 1, done: 3}, 4, "attention"],
                        [{attention: 1, working: 3}, 4, "attention"],
                        [{interrupted: 1, done: 3}, 4, "interrupted"],
                        [{unknown: 1, done: 3}, 4, "unknown"], [{}, 0, "ready"]
                    ]) {
                        source.snapshot = {total: sample[1], counts: sample[0], projects: [], warnings: []}
                        test.check(test.barStatus.state === sample[2], "bar distinguishes " + sample[2])
                    }
                    source.snapshot = originalSnapshot
                    source.healthy = false
                    test.check(test.barStatus.state === "ready", "unhealthy bar never implies working or completion")
                    test.check(test.barStatus.tooltipText.indexOf("Orca unavailable") !== -1 && test.barStatus.tooltipText.indexOf("working") === -1, "unhealthy hover does not present stale counts as current")
                    source.healthy = true
                    test.barSpinner = test.descendants(test.barStatus).find(function(item) { return item.objectName === "pendingIcon" })
                    test.check(!!test.barSpinner && test.barSpinner.visible, "bar has a visible pending ring")
                    test.previousBarRotation = test.barSpinner.rotation
                    var items = test.descendants(view)
                    var buttons = items.filter(function(item) { return typeof item.clicked === "function" })
                    var agentIcons = items.filter(function(item) { return item.objectName === "agentIcon" })
                    var providerImages = test.descendants(providers).filter(function(item) { return item.objectName === "agentIcon" })
                    test.check(providerImages.length > 30 && providerImages.every(function(icon) { return icon.status === Image.Ready }), "every bundled provider icon loads offline")
                    test.check(unknownProvider.asset === "", "unknown provider cannot escape the local icon allowlist")
                    unknownProvider.agent = "../../outside.svg"
                    test.check(unknownProvider.asset === "", "provider names cannot become asset paths")
                    test.check(agentIcons.length === 4 && agentIcons.every(function(icon) { return icon.status === Image.Ready }), "all agent/provider icons load from bundled assets")
                    test.check(items.some(function(item) { return item.font && item.font.family === "Geist" }), "sidebar uses Orca's Geist font")
                    Commons.Color.userShellValues = ({})
                    for (var palette of [
                        {text: "#18212b", background: "#faf7ef", accent: "#6d28d9", muted: "#596579", urgent: "#b91c1c"},
                        {text: "#f3e6d0", background: "#201a24", accent: "#f2a65a", muted: "#b0a0b7", urgent: "#ff677d"}
                    ]) {
                        Commons.Color.loadColors('foreground="' + palette.text + '"\nbackground="' + palette.background
                            + '"\naccent="' + palette.accent + '"\nmuted="' + palette.muted + '"\ncolor1="' + palette.urgent + '"')
                        Commons.Color.loadShell('[popups]\ntext="' + palette.text + '"\nbackground="' + palette.background + '"')
                        test.check(Qt.colorEqual(view.foreground, palette.text), "popup foreground follows theme changes")
                        test.check(Qt.colorEqual(view.muted, palette.muted), "secondary text follows theme changes")
                        var label = items.find(function(item) { return item.text === "Live pane" })
                        test.check(Qt.colorEqual(label.color, palette.text), "agent text follows light and dark themes")
                        var folder = items.find(function(item) { return item.source && item.source.toString().endsWith("/folder.svg") })
                        test.check(Qt.colorEqual(folder.color, palette.muted), "interface SVGs use theme ink")
                        test.check(Qt.colorEqual(test.barStatus.ink, palette.accent), "bar pending ring follows theme accent")
                        test.check(Qt.colorEqual(themeDone.ink, palette.accent), "completion follows theme accent")
                        test.check(Qt.colorEqual(themeAttention.ink, palette.urgent), "attention follows theme urgent color")
                        var pi = providerImages.find(function(icon) { return icon.source.toString().endsWith("/pi.svg") })
                        var claude = providerImages.find(function(icon) { return icon.source.toString().endsWith("/claude.svg") })
                        test.check(pi.tinted && Qt.colorEqual(pi.color, palette.text), "monochrome provider glyphs follow theme foreground")
                        test.check(!claude.tinted, "colored provider logos retain their branding")
                    }
                    test.check(buttons.length === 4, "expected one card button per workspace, no agent buttons; got " + buttons.length)
                    test.check(view.selectableWorkspaces().length === 2, "skip workspaces without a live target")
                    view.moveSelection(1)
                    test.check(view.selectedKey === "first", "keyboard selects a whole workspace")
                    view.activateSelection()
                    test.check(source.target === "first/live", "card opens first live agent, not stale pane")
                    view.moveSelection(1)
                    test.check(view.selectedKey === "second", "keyboard skips agent rows")
                    view.moveSelection(1)
                    test.check(view.selectedKey === "first", "keyboard wraps past offline card")
                    source.healthy = false
                    view.activateSelection()
                    test.check(source.opened === 1, "stale data must not navigate")
                    source.healthy = true
                    var attentionSnapshot = JSON.parse(JSON.stringify(source.snapshot))
                    attentionSnapshot.counts.attention = 2
                    attentionSnapshot.total = 6
                    var waitingCard = attentionSnapshot.projects[0].workspaces[0]
                    waitingCard.state = "attention"
                    waitingCard.agents.push({workspace: "first", pane: "stale-wait", type: "pi", label: "Offline question", state: "attention", selectable: false})
                    waitingCard.agents.push({workspace: "first", pane: "waiting", type: "claude", label: "Approve a tool", state: "attention", selectable: true})
                    source.snapshot = attentionSnapshot
                    test.check(test.barStatus.state === "attention", "needs-you takes priority over working agents")
                    test.check(test.barStatus.activateAttention() === true && source.target === "first/waiting", "bar attention action skips working and offline agents")
                    test.check(test.barStatus.tooltipText.indexOf("2 need you") !== -1 && test.barStatus.tooltipText.indexOf("Approve a tool") !== -1, "hover includes attention count and live waiting task")
                    waitingCard.agents[3].label = '<img src="https://example.invalid">'
                    source.snapshot = JSON.parse(JSON.stringify(attentionSnapshot))
                    test.check(test.barStatus.tooltipText.indexOf("<") === -1, "hover neutralizes external markup")
                    waitingCard.agents[3].label = "Approve a tool"
                    var highlighted = test.descendants(view).find(function(item) { return item.modelData && item.modelData.id === "first" && item.needsAttention === true })
                    test.check(!!highlighted, "waiting workspace is explicitly highlighted")
                    test.check(test.descendants(highlighted).some(function(item) { return item.text === "Needs you" }), "waiting workspace has a readable needs-you label")
                    view.activate(waitingCard)
                    test.check(source.target === "first/waiting", "clicking a highlighted card opens its waiting agent")
                    var offlineAttention = JSON.parse(JSON.stringify(attentionSnapshot))
                    offlineAttention.projects[0].workspaces[0].agents.forEach(function(agent) { if (agent.state === "attention") agent.selectable = false })
                    source.snapshot = offlineAttention
                    test.check(test.barStatus.activateAttention() === false, "offline waiting sessions cannot open an unrelated working agent")
                    view.activate(offlineAttention.projects[0].workspaces[0])
                    test.check(source.opened === 3, "attention card does not fall back to a working session")
                    source.snapshot = attentionSnapshot
                    source.healthy = false
                    test.check(test.barStatus.activateAttention() === false && source.opened === 3, "stale attention cannot navigate")
                    source.healthy = true
                    source.snapshot = originalSnapshot
                    test.check(test.barStatus.activateAttention() === false && source.opened === 3, "no attention never falls back to an unrelated agent")
                    Commons.Style.reduceMotion = false
                    items = test.descendants(view)
                    test.spinner = items.find(function(item) { return item.objectName === "pendingIcon" })
                    test.check(!!test.spinner, "working status has a pending icon")
                    test.previousRotation = test.spinner.rotation
                } else if (test.phase === 1) {
                    test.check(test.spinner.rotation !== test.previousRotation, "pending icon rotates")
                    test.check(test.barSpinner.rotation !== test.previousBarRotation, "bar pending icon rotates with popup closed")
                    Commons.Style.reduceMotion = true
                    test.previousRotation = test.spinner.rotation
                    test.previousBarRotation = test.barSpinner.rotation
                } else {
                    test.check(test.spinner.rotation === test.previousRotation, "reduced motion stops rotation")
                    test.check(test.barSpinner.rotation === test.previousBarRotation, "reduced motion stops the bar spinner too")
                    console.log("UI_PASS: workspace controls, safe navigation, needs-you priority and safe direct navigation, live light/dark theme colors, shared pending animation, reduced motion")
                    stop()
                    Qt.quit()
                }
                test.phase++
            } catch (error) {
                console.error("UI_FAIL: " + error)
                stop()
                Qt.quit()
            }
        }
    }
}
