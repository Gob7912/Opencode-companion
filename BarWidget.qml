import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar
import "."

// OpenCode on the panel. Pixel: the robot mascot + the count of live sessions
// (or today's tokens). Mac look (Skin.mac, the Golden Gate menu bar): the
// "bot" line icon and the numbers in the bar's ink, the popup a glass popover.
Item {
    id: root

    property var plugin
    property string screenName
    property var barWindow
    readonly property bool barOpen: popup.visible

    readonly property var _cfg: (Config.plugins.data || {})["opencode-companion"] || ({})
    readonly property string mode: _cfg.barMode || (plugin ? plugin.get("barMode", "auto") : "auto")   // auto | sessions | today | off
    readonly property string label: {
        if (mode === "off" || OpencodeState.status !== "ok")
            return "";
        if (mode === "today")
            return OpencodeState.tokens(OpencodeState.today.total_tokens);
        if (mode === "sessions")
            return String(OpencodeState.sessions.length);
        // auto: the live session count while there are sessions, else today's tokens
        return OpencodeState.sessions.length ? String(OpencodeState.sessions.length) : OpencodeState.tokens(OpencodeState.today.total_tokens);
    }
    visible: !plugin || (_cfg.barAlways !== undefined ? _cfg.barAlways : plugin.get("barAlways", true)) || OpencodeState.state !== "none"
    readonly property bool mac: Skin.mac
    implicitWidth: visible ? row.implicitWidth + (mac ? Skin.px(4) : Skin.px(8)) : 0
    implicitHeight: mac ? Skin.px(18) : Skin.px(24)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Skin.px(4)
        Mascot {
            anchors.verticalCenter: parent.verticalCenter
            pixel: root.mac ? Skin.px(2) : Theme.u
            mono: root.mac
            monoColor: Skin.ink(root.screenName)
        }
        PxText {
            visible: root.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.mac ? Skin.ink(root.screenName) : OpencodeState.stateColor(OpencodeState.state, Theme)
            font.bold: !root.mac
        }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => {
            panel.tab = m.button === Qt.RightButton ? "sessions" : m.button === Qt.MiddleButton ? "ask" : "usage";
            if (!popup.visible)
                OpencodeState.refresh();
            popup.toggle();
        }
    }

    BarPopup {
        id: popup
        panelId: "opencode"
        anchorItem: root
        above: BarLayout.bottom && !root.mac
        title: Skin.title(Skin.mac ? "OpenCode" : "opencode")
        icon: "bot"
        contentWidth: Skin.px(380)
        contentHeight: Skin.px(420)
        onVisibleChanged: if (visible && panel.tab === "ask") Qt.callLater(() => panel.q.focusField())
        PxScroll {
            anchors.fill: parent
            contentHeight: panel.implicitHeight
            Panel {
                id: panel
                width: parent.width
                plugin: root.plugin
            }
        }
    }
}
