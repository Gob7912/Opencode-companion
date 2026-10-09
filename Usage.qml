pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Today's usage and data notes. Pixel: plain counters; the Mac look
// (Skin.mac, not on hell's desktop) keeps them one line. In hell's orb the
// same numbers in fire colours — tokens read as souls.
Column {
    id: root

    property bool compact: false
    property bool hell: false
    readonly property bool mac: (Skin.macWidgets || Skin.mac) && !hell
    spacing: Skin.px(compact ? 4 : 8)

    PxText {
        visible: OpencodeState.status !== "ok"
        width: root.width
        wrapMode: Text.Wrap
        color: root.hell ? Theme.hellTextDim : Skin.textDim
        text: ({
                "idle": "…",
                "noopencode": I18n.t("OpenCode не найден (~/.local/share/opencode). Установи opencode и войди в него.", "OpenCode not found (~/.local/share/opencode). Install opencode and sign in."),
                "error": I18n.t("не удалось прочитать базу OpenCode", "Could not read the OpenCode database")
            })[OpencodeState.status] || ""
    }

    Row {
        visible: OpencodeState.status === "ok"
        spacing: Skin.px(8)
        PxText {
            text: (root.hell ? I18n.t("душ сегодня: ", "souls today: ") : I18n.t("сегодня: ", "today: ")) + OpencodeState.tokens(OpencodeState.today.total_tokens)
            font.bold: true
            color: root.hell ? Theme.hellFlame : Skin.text
        }
        PxText {
            visible: !root.compact
            text: I18n.t("вх ", "in ") + OpencodeState.tokens(OpencodeState.today.input_tokens) + I18n.t(" (кэш ", " (cache ") + OpencodeState.tokens(OpencodeState.today.cached_input_tokens) + ") · " + I18n.t("вых ", "out ") + OpencodeState.tokens(OpencodeState.today.output_tokens)
            color: root.hell ? Theme.hellTextDim : Skin.textDim
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    PxText {
        visible: OpencodeState.status === "ok" && OpencodeState.cost > 0
        text: I18n.t("стоимость всего: ", "cost so far: ") + "$" + OpencodeState.cost.toFixed(3)
        color: root.hell ? Theme.hellText : Skin.text
    }
    PxText {
        visible: OpencodeState.status === "ok" && !root.compact && OpencodeState.todaySessions > 0
        text: I18n.t("сессий сегодня: ", "sessions today: ") + OpencodeState.todaySessions
        kind: "tiny"
        color: root.hell ? Theme.hellTextDim : Skin.textDim
    }
    PxText {
        visible: OpencodeState.status === "ok" && !root.compact
        text: I18n.t("из opencode.db (локально) · обновлено ", "from opencode.db (local) · updated ") + OpencodeState.ago(OpencodeState.updated.getTime())
        kind: "tiny"
        color: root.hell ? Theme.hellTextDim : Skin.textDim
    }
}
