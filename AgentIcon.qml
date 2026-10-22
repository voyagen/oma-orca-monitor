import QtQuick
import qs.Commons as Commons

Item {
    id: root
    property string agent: ""
    implicitWidth: 13
    implicitHeight: 13
    readonly property var assets: ({
        "pi": "pi.svg", "claude": "claude.svg", "claude-agent-teams": "claude.svg",
        "codex": "codex.svg", "droid": "droid.svg", "omp": "omp.svg", "aider": "aider.svg",
        "kilo": "kilo.svg", "copilot": "copilot.svg", "opencode": "opencode.svg", "opencode2": "opencode.svg",
        "amp": "amp.png", "ante": "ante.png", "antigravity": "antigravity.png", "aug": "aug.png",
        "autohand": "autohand.png", "cline": "cline.png", "codebuddy": "codebuddy.png", "codebuff": "codebuff.png",
        "command-code": "command-code.png", "continue": "continue.png", "crush": "crush.png", "cursor": "cursor.png",
        "devin": "devin.png", "dsh": "dsh.png", "dsb": "dsh.png", "freebuff": "freebuff.png",
        "gemini": "gemini.png", "goose": "goose.png", "grok": "grok.png", "hermes": "hermes.png",
        "jcode": "jcode.png", "kimi": "kimi.png", "kiro": "kiro.png", "mimo-code": "mimo-code.png",
        "mistral-vibe": "mistral-vibe.png", "muse": "muse.png", "openclaude": "openclaude.png",
        "openclaw": "openclaw.png", "prime-agent": "prime-agent.png", "qoder": "qoder.png",
        "qoder-cn": "qoder.png", "qwen-code": "qwen-code.png", "rovo": "rovo.png", "trae": "trae.png", "zcode": "zcode.png"
    })
    readonly property string asset: Object.prototype.hasOwnProperty.call(assets, agent) ? assets[agent] : ""
    ThemedIcon {
        objectName: "agentIcon"
        color: Commons.Color.popups.text
        tinted: ["pi.svg", "codex.svg", "aider.svg", "copilot.svg", "opencode.svg"].includes(root.asset)
        anchors.fill: parent
        source: root.asset ? Qt.resolvedUrl("icons/" + root.asset) : ""
        fillMode: Image.PreserveAspectFit
        visible: root.asset !== ""
    }
    Rectangle {
        anchors.fill: parent
        visible: root.asset === ""
        radius: 3
        color: Commons.Util.alpha(Commons.Color.popups.text, 0.1)
        PlainText {
            anchors.centerIn: parent
            text: root.agent ? root.agent.charAt(0).toUpperCase() : "?"
            font.pixelSize: 9
            font.bold: true
        }
    }
}
