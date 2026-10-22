import QtQuick
import qs.Commons as Commons

StatusIndicator {
    property var monitor: null
    readonly property var counts: healthy ? (monitor.snapshot.counts || {}) : ({})
    workspace: true
    healthy: monitor !== null && monitor.healthy
    state: !healthy || !monitor.snapshot.total ? "ready"
        : counts.attention > 0 ? "attention"
        : counts.working > 0 ? "working"
        : counts.interrupted > 0 ? "interrupted"
        : counts.unknown > 0 ? "unknown" : "done"

    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
    readonly property string tooltipText: {
        var title = strings.t("title")
        if (!healthy) return title + "\n" + strings.t("unavailable")
        if (!monitor.snapshot.total) return title + "\n" + strings.t("empty")
        var parts = []
        for (var state of ["working", "attention", "done", "ready", "interrupted", "unknown"]) {
            var count = counts[state] || 0
            var phrase = strings.tn("summary." + state, count, "")
            if (count > 0 && phrase) parts.push(phrase.arg(Commons.I18n.formatNumber(count)))
        }
        var summary = title + "\n" + parts.join(" · ")
        if (attentionTarget) {
            // Shell tooltips may use AutoText; external task names must not become markup.
            var label = String(attentionTarget.label || "").replace(/&/g, "＆").replace(/</g, "‹").replace(/>/g, "›")
            if (label) summary += "\n" + label
        }
        return summary
    }

    readonly property var attentionTarget: {
        if (!healthy) return null
        for (var project of monitor.snapshot.projects) {
            for (var workspace of project.workspaces) {
                var agent = workspace.agents.find(function(item) { return item.state === "attention" && item.selectable })
                if (agent) return agent
            }
        }
        return null
    }
    function activateAttention() {
        var agent = attentionTarget
        if (!healthy || !agent) return false
        monitor.focusSession(agent.workspace, agent.pane)
        return true
    }
}
