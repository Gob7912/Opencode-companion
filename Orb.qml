import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Desktop "opencode.exe": mascot, state and today's tokens. The host draws the frame.
Item {
    id: root

    property var plugin
    property string screenName
    property var widget

    readonly property var _cfg: (Config.plugins.data || {})["opencode-companion"] || ({})
    readonly property string mode: _cfg.orb || (plugin ? plugin.get("orb", "always") : "always")   // always | active | off
    readonly property bool wantVisible: mode !== "off" && (mode === "always" || OpencodeState.state !== "none")

    implicitWidth: Math.max(col.implicitWidth, Skin.px(220))
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Skin.px(8)

        PxText {
            visible: Skin.macWidgets && !Theme.hell
            text: "OpenCode"
            kind: "tiny"
            color: Skin.textDim
        }

        Mascot {
            anchors.horizontalCenter: parent.horizontalCenter
            pixel: Skin.macWidgets ? Skin.px(3) : Theme.u * 3
        }

        // hell (manifest "realms"): words in blackletter, fire colours
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (Theme.hell ? OpencodeState.hellWords : OpencodeState.words)[OpencodeState.state] || ""
            kind: "title"
            font.family: Theme.hell && Theme.hellCovers(text) ? Theme.fontHell : Theme.fontTitle
            font.pixelSize: Theme.hell && Theme.hellCovers(text) ? Theme.hellPx(Theme.fs) : Theme.sizeTitle
            color: Theme.hell ? OpencodeState.hellStateColor(OpencodeState.state, Theme) : OpencodeState.stateColor(OpencodeState.state, Theme)
        }

        Usage {
            width: parent.width
            compact: true
            hell: Theme.hell
        }
    }
}
