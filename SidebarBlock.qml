import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Sidebar block: OpenCode state and today's tokens at a glance.
Column {
    id: root

    property var plugin
    spacing: Skin.px(4)

    Row {
        spacing: Skin.px(6)
        Mascot {
            anchors.verticalCenter: parent.verticalCenter
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            text: "OpenCode · " + (OpencodeState.words[OpencodeState.state] || "")
            color: OpencodeState.stateColor(OpencodeState.state, Theme)
        }
    }
    Usage {
        width: root.width
        compact: true
    }
}
