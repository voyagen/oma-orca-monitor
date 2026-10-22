import QtQuick
import qs.Commons as Commons

Item {
    id: indicator
    property string state
    property bool workspace: false
    property bool healthy: true
    readonly property color ink: state === "working" || state === "done" ? Commons.Color.accent
        : state === "attention" ? Commons.Color.urgent : Commons.Color.muted
    implicitWidth: Commons.Style.space(workspace ? 12 : 10)
    implicitHeight: implicitWidth
    Rectangle {
        anchors.centerIn: parent
        visible: indicator.state === "ready" || indicator.state === "interrupted" || (indicator.state === "done" && indicator.workspace)
        width: Commons.Style.space(indicator.state === "interrupted" ? 6 : 8)
        height: width
        radius: width / 2
        color: indicator.ink
        opacity: indicator.state === "ready" ? 0.4 : 1
    }
    ThemedIcon {
        color: indicator.ink
        anchors.fill: parent
        visible: indicator.state === "attention" || indicator.state === "unknown" || (indicator.state === "done" && !indicator.workspace)
        source: Qt.resolvedUrl("icons/" + (indicator.state === "attention" ? "message-circle-question-mark.svg" : indicator.state === "done" ? "circle-check.svg" : "circle-dashed.svg"))
    }
    ThemedIcon {
        id: pending
        color: indicator.ink
        objectName: "pendingIcon"
        anchors.centerIn: parent
        width: Commons.Style.space(indicator.workspace ? 8 : 6)
        height: width
        visible: indicator.state === "working"
        source: Qt.resolvedUrl(indicator.workspace
            ? (Commons.Style.reduceMotion ? "icons/pending-static.svg" : "pending.svg")
            : (Commons.Style.reduceMotion ? "icons/pending-small-static.svg" : "icons/pending-small.svg"))
        property real phase: 0
        rotation: Math.floor(phase / 30) * 30
        NumberAnimation on phase {
            from: 0; to: 360; duration: 1000; loops: Animation.Infinite
            running: pending.visible && indicator.visible && indicator.healthy && !Commons.Style.reduceMotion
        }
    }
}

