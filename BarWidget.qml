import QtQuick
import QtQuick.Window
import QtQuick.Effects
import qs.Commons as Commons
import qs.Ui as Ui

Ui.Panel {
    id: root
    moduleName: "voyagen.oma-orca-monitor"
    ipcTarget: moduleName
    readonly property var monitor: Backend
    readonly property int refreshIntervalSec: {
        var value = Number((root.settings || ({})).refreshIntervalSec)
        return isFinite(value) && value > 0 ? Math.max(2, Math.min(60, value)) : 3
    }
    Binding { target: Backend; property: "pollSeconds"; value: root.refreshIntervalSec }
    readonly property bool healthy: monitor !== null && monitor.healthy
    readonly property var counts: healthy ? monitor.snapshot.counts : ({})
    readonly property int attention: (counts.attention || 0) + (counts.interrupted || 0)
    readonly property color stateColor: !healthy ? Commons.Color.muted
        : attention > 0 ? Commons.Color.urgent : counts.working > 0 ? Commons.Color.accent : barForeground
    implicitWidth: barContents.implicitWidth
    implicitHeight: barContents.implicitHeight
    onOpenedChanged: if (opened && monitor) monitor.refresh()

    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
    Commons.ShellIpc {
        target: "voyagen.oma-orca-monitor.widget"
        function status(): string {
            return JSON.stringify({opened: root.opened, bar: !!root.bar,
                button: [root.width, root.height, button.visible, button.opacity],
                popup: [popup.open, popup.visible, popup.contentWidth, popup.contentHeight],
                origin: popup.cardOrigin, content: [content.width, content.height, content.implicitHeight],
                status: barStatus.state, statusVisible: barStatus.visible, attentionTarget: !!barStatus.attentionTarget,
                hover: [button.tooltipHovered, statusButton.tooltipHovered, barContents.tooltipHovered], tooltip: barStatus.tooltipText,
                barPosition: root.mapToGlobal(0, 0), observer: [hoverObserver.width, hoverObserver.height, groupHover.hovered, hoverObserver.localPoint.x, hoverObserver.localPoint.y, !!root.Window.window],
                selected: content.selectedKey !== "", selectable: content.selectableWorkspaces().length})
        }
    }
    Item {
        id: barContents
        implicitWidth: button.width + statusButton.width
        implicitHeight: Math.max(button.height, statusButton.height)
        anchors.centerIn: parent
        readonly property bool tooltipHovered: groupHover.hovered
            && hoverObserver.localPoint.x >= 0 && hoverObserver.localPoint.x < root.width
            && hoverObserver.localPoint.y >= 0 && hoverObserver.localPoint.y < root.height
        onTooltipHoveredChanged: {
            if (!root.bar) return
            if (tooltipHovered) root.bar.showTooltip(barContents, barStatus.tooltipText)
            else root.bar.hideTooltip(barContents)
        }
        Item {
            id: hoverObserver
            anchors.fill: parent
            readonly property point localPoint: root.mapFromItem(hoverObserver, groupHover.point.position.x, groupHover.point.position.y)
            HoverHandler {
                id: groupHover
                blocking: false
            }
        }
        Ui.WidgetButton {
            id: button
            bar: root.bar
            labelVisible: false
            hasVisualContent: true
            fixedWidth: Commons.Style.space(24)
            active: root.opened
            tooltipText: barStatus.tooltipText
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: tooltipText
            Accessible.onPressAction: triggerPress(Qt.LeftButton)
            Keys.onReturnPressed: triggerPress(Qt.LeftButton)
            Keys.onSpacePressed: triggerPress(Qt.LeftButton)
            onPressed: function(code) {
                if (code === Qt.MiddleButton && root.monitor) root.monitor.refresh()
                else if (code === Qt.LeftButton) root.toggle()
            }
            Item {
                anchors.centerIn: parent
                width: Commons.Style.space(22)
                height: Commons.Style.space(22)
                Image {
                    id: logo
                    anchors.fill: parent
                    source: Qt.resolvedUrl("orca.svg")
                    fillMode: Image.PreserveAspectFit
                    visible: false
                }
                MultiEffect {
                    anchors.fill: logo
                    source: logo
                    colorization: 1
                    colorizationColor: root.stateColor
                }
            }
            Rectangle {
                visible: root.attention > 0
                width: Commons.Style.space(5)
                height: width
                radius: width / 2
                color: Commons.Color.urgent
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Commons.Style.space(3)
            }
        }
        Ui.WidgetButton {
            id: statusButton
            x: button.width
            bar: root.bar
            labelVisible: false
            hasVisualContent: true
            fixedWidth: Commons.Style.space(22)
            active: barStatus.state === "attention"
            tooltipText: barStatus.tooltipText + (barStatus.state === "attention"
                ? "\n" + strings.t(barStatus.attentionTarget ? "openAttention" : "attentionNoTarget") : "")
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: tooltipText
            Accessible.onPressAction: triggerPress(Qt.LeftButton)
            Keys.onReturnPressed: triggerPress(Qt.LeftButton)
            Keys.onSpacePressed: triggerPress(Qt.LeftButton)
            onPressed: function(code) {
                if (code === Qt.MiddleButton && root.monitor) root.monitor.refresh()
                else if (code === Qt.LeftButton) {
                    if (barStatus.state !== "attention") root.toggle()
                    else if (barStatus.activateAttention()) root.close()
                    else root.open()
                }
            }
            BarStatus {
                id: barStatus
                anchors.centerIn: parent
                monitor: root.monitor
            }
        }
    }
    Ui.KeyboardPanel {
        id: popup
        anchorItem: root
        owner: root
        bar: root.bar
        open: root.opened
        padding: Commons.Style.space(16)
        contentWidth: fittedContentWidth(Commons.Style.space(340))
        contentHeight: fittedContentHeight(content.implicitHeight, Commons.Style.space(640))
        focusTarget: keys

        Ui.PanelKeyCatcher {
            id: keys
            anchors.fill: parent
            onCloseRequested: root.close()
            onMoveRequested: function(dx, dy) { if (dy) content.moveSelection(dy) }
            onActivateRequested: content.activateSelection()
            onTabRequested: function(direction) { root.switchPanel(direction) }
            onTextKey: function(value) { if (value.toLowerCase() === "r" && root.monitor) root.monitor.refresh() }
            MonitorContent {
                id: content
                anchors.fill: parent
                monitor: root.monitor
                onSessionActivated: root.close()
            }
        }
    }
}
