import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons as Commons

Item {
    id: root
    property var monitor: null
    readonly property var snapshot: monitor ? monitor.snapshot : ({projects: [], total: 0, warnings: []})
    readonly property bool healthy: monitor !== null && monitor.healthy
    readonly property double now: monitor ? monitor.now : Date.now()
    property string selectedKey: ""
    signal sessionActivated()
    implicitHeight: header.implicitHeight + body.implicitHeight + Commons.Style.space(12)
    readonly property color foreground: Commons.Color.popups.text
    readonly property color muted: Commons.Color.muted
    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
    function target(workspace) {
        return workspace.state === "attention"
            ? workspace.agents.find(function(agent) { return agent.state === "attention" && agent.selectable })
            : workspace.agents.find(function(agent) { return agent.selectable })
    }
    function elapsed(since) {
        if (!since || now < since) return ""
        var minutes = Math.floor((now - since) / 60000)
        return minutes < 1 ? "now" : minutes < 60 ? Commons.I18n.formatNumber(minutes) + "m"
            : minutes < 1440 ? Commons.I18n.formatNumber(Math.floor(minutes / 60)) + "h"
            : Commons.I18n.formatNumber(Math.floor(minutes / 1440)) + "d"
    }
    function selectableWorkspaces() {
        var found = []
        snapshot.projects.forEach(function(project) {
            project.workspaces.forEach(function(workspace) { if (target(workspace)) found.push(workspace) })
        })
        return found
    }
    function moveSelection(direction) {
        var workspaces = selectableWorkspaces()
        if (!workspaces.length) return
        var index = workspaces.findIndex(function(workspace) { return workspace.id === selectedKey })
        if (index < 0) index = direction > 0 ? -1 : 0
        selectedKey = workspaces[(index + direction + workspaces.length) % workspaces.length].id
    }
    function activate(workspace) {
        var agent = target(workspace)
        if (!healthy || !monitor || !agent) return
        monitor.focusSession(agent.workspace, agent.pane)
        sessionActivated()
    }
    function activateSelection() {
        var workspace = selectableWorkspaces().find(function(item) { return item.id === selectedKey })
        if (workspace) activate(workspace)
    }
    function errorText(code) { return strings.t(code === "unavailable" ? "unavailable_error" : code || "navigation") }

    ColumnLayout {
        id: header
        anchors.top: parent.top
        width: parent.width
        spacing: Commons.Style.space(4)
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Commons.Style.space(6)
            PlainText { text: strings.t("projects"); color: root.muted; Layout.fillWidth: true }
            AbstractButton {
                implicitWidth: Commons.Style.space(24)
                implicitHeight: Commons.Style.space(24)
                enabled: root.monitor !== null && !root.monitor.busy
                Accessible.name: strings.t("retry")
                contentItem: ThemedIcon { source: Qt.resolvedUrl("icons/rotate-cw.svg"); sourceSize.width: 13; sourceSize.height: 13; fillMode: Image.PreserveAspectFit }
                padding: Commons.Style.space(5)
                background: Rectangle { radius: Commons.Style.space(4); color: parent.hovered ? Commons.Util.alpha(root.foreground, 0.08) : "transparent" }
                onClicked: root.monitor.refresh()
            }
        }
        PlainText {
            Layout.fillWidth: true
            visible: !root.healthy
            text: root.monitor && root.monitor.hasSnapshot ? strings.t("stale") : strings.t("connecting")
            color: root.muted
            wrapMode: Text.Wrap
        }
        PlainText {
            Layout.fillWidth: true
            visible: !!root.monitor && root.monitor.error !== ""
            text: visible ? root.errorText(root.monitor.error) : ""
            color: Commons.Color.urgent
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        Repeater {
            model: root.snapshot.warnings
            PlainText { required property string modelData; Layout.fillWidth: true; text: strings.t(modelData); wrapMode: Text.Wrap; elide: Text.ElideNone; color: Commons.Color.urgent }
        }
        PlainText {
            Layout.fillWidth: true
            visible: !!root.monitor && root.monitor.actionError !== ""
            text: visible ? root.errorText(root.monitor.actionError) : ""
            color: Commons.Color.urgent
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
    }
    Flickable {
        id: scroll
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: Commons.Style.space(12)
        width: parent.width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { }
        Column {
            id: body
            width: scroll.width
            spacing: Commons.Style.space(16)
            opacity: root.healthy ? 1 : 0.55
            Repeater {
                model: root.snapshot.projects
                Column {
                    id: projectColumn
                    required property var modelData
                    width: body.width
                    spacing: Commons.Style.space(8)
                    RowLayout {
                        width: parent.width - Commons.Style.space(12)
                        x: Commons.Style.space(6)
                        spacing: Commons.Style.space(8)
                        PlainText {
                            visible: !!projectColumn.modelData.icon
                            text: projectColumn.modelData.icon || ""
                            font.pixelSize: Commons.Style.space(13)
                            Layout.preferredWidth: Commons.Style.space(16)
                        }
                        ThemedIcon {
                            visible: !projectColumn.modelData.icon
                            source: Qt.resolvedUrl("icons/folder.svg")
                            Layout.preferredWidth: Commons.Style.space(13)
                            Layout.preferredHeight: Commons.Style.space(13)
                        }
                        PlainText { Layout.fillWidth: true; text: projectColumn.modelData.name; font.weight: Font.DemiBold }
                        PlainText { visible: projectColumn.modelData.host !== "local"; text: projectColumn.modelData.host; color: root.muted; Layout.maximumWidth: parent.width / 3 }
                    }
                    Repeater {
                        model: projectColumn.modelData.workspaces
                        AbstractButton {
                            id: card
                            required property var modelData
                            readonly property bool selected: root.selectedKey === modelData.id
                            readonly property bool needsAttention: modelData.state === "attention"
                            width: projectColumn.width
                            implicitHeight: workspaceContent.implicitHeight + topPadding + bottomPadding
                            height: implicitHeight
                            leftPadding: Commons.Style.space(20)
                            rightPadding: Commons.Style.space(6)
                            topPadding: Commons.Style.space(6)
                            bottomPadding: Commons.Style.space(6)
                            hoverEnabled: true
                            enabled: root.healthy && !!root.target(modelData)
                            Accessible.name: modelData.name + ", " + modelData.agents.map(function(agent) {
                                return agent.type + ": " + agent.label + ", " + strings.t(agent.state)
                            }).join("; ")
                            onClicked: root.activate(modelData)
                            onSelectedChanged: {
                                if (!selected) return
                                var point = mapToItem(body, 0, 0)
                                if (point.y < scroll.contentY) scroll.contentY = point.y
                                else if (point.y + height > scroll.contentY + scroll.height)
                                    scroll.contentY = Math.max(0, point.y + height - scroll.height)
                            }
                            background: Rectangle {
                                radius: Commons.Style.space(8)
                                color: Commons.Util.alpha(card.needsAttention ? Commons.Color.urgent : Commons.Color.accent, card.needsAttention || card.modelData.active ? 0.1 : card.hovered || card.selected ? 0.06 : 0)
                                border.width: 1
                                border.color: Commons.Util.alpha(card.needsAttention ? Commons.Color.urgent : Commons.Color.accent, card.needsAttention ? 0.6 : card.selected ? 0.5 : card.modelData.active ? 0.3 : 0)
                            }
                            contentItem: Column {
                                id: workspaceContent
                                spacing: Commons.Style.space(4)
                                RowLayout {
                                    width: parent.width
                                    spacing: Commons.Style.space(6)
                                    StatusIndicator { state: card.modelData.state; healthy: root.healthy; workspace: true; Layout.alignment: Qt.AlignVCenter }
                                    PlainText { text: card.modelData.name; Layout.fillWidth: true; color: card.needsAttention ? Commons.Color.urgent : root.foreground }
                                    PlainText {
                                        visible: card.needsAttention
                                        text: strings.t("attention")
                                        font.pixelSize: Commons.Style.space(10)
                                        font.bold: true
                                        color: Commons.Color.urgent
                                    }
                                    Rectangle {
                                        visible: card.modelData.primary === true
                                        implicitWidth: primaryLabel.implicitWidth + Commons.Style.space(12)
                                        implicitHeight: Commons.Style.space(16)
                                        radius: Commons.Style.space(4)
                                        color: Commons.Util.alpha(root.foreground, 0.06)
                                        border.width: 1
                                        border.color: Commons.Util.alpha(root.foreground, 0.2)
                                        PlainText { id: primaryLabel; anchors.centerIn: parent; text: strings.t("primary"); font.pixelSize: Commons.Style.space(10); color: root.muted }
                                    }
                                }
                                PlainText {
                                    visible: card.needsAttention && !root.target(card.modelData)
                                    width: parent.width
                                    text: strings.t("noNavigation")
                                    font.pixelSize: Commons.Style.space(10)
                                    color: root.muted
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideNone
                                }
                                PlainText {
                                    visible: text !== ""
                                    width: parent.width - Commons.Style.space(18)
                                    x: Commons.Style.space(18)
                                    text: card.modelData.branch
                                    color: root.muted
                                    font.family: Commons.Style.font.family
                                    font.pixelSize: Commons.Style.space(11)
                                }
                                Repeater {
                                    model: card.modelData.agents
                                    RowLayout {
                                        id: agentRow
                                        required property var modelData
                                        width: workspaceContent.width - Commons.Style.space(8)
                                        x: Commons.Style.space(8)
                                        height: Commons.Style.space(24)
                                        spacing: Commons.Style.space(4)
                                        StatusIndicator { state: agentRow.modelData.state; healthy: root.healthy; Layout.alignment: Qt.AlignVCenter }
                                        AgentIcon { agent: agentRow.modelData.type; Layout.preferredWidth: Commons.Style.space(13); Layout.preferredHeight: Commons.Style.space(13) }
                                        PlainText {
                                            text: agentRow.modelData.label
                                            Layout.fillWidth: true
                                            font.pixelSize: Commons.Style.space(11)
                                        }
                                        PlainText { text: root.elapsed(agentRow.modelData.since); color: root.muted; font.pixelSize: Commons.Style.space(10) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Column {
                visible: root.snapshot.total === 0
                width: parent.width
                spacing: Commons.Style.space(8)
                PlainText { width: parent.width; text: root.healthy ? strings.t("empty") : strings.t("unavailable"); font.bold: true }
                PlainText { width: parent.width; text: strings.t("emptyHint"); wrapMode: Text.Wrap; elide: Text.ElideNone; color: root.muted }
            }
        }
    }
}
