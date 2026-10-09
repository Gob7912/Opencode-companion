pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "."

// Tabs: usage / sessions / ask.
Column {
    id: root

    property var plugin
    property string tab: "usage"
    property alias q: q
    spacing: Skin.px(8)

    PxSegmented {
        model: [
            {
                "label": I18n.t("Расход", "Usage"),
                "value": "usage"
            },
            {
                "label": I18n.t("Сессии (", "Sessions (") + OpencodeState.sessions.length + ")",
                "value": "sessions"
            },
            {
                "label": I18n.t("Спросить", "Ask"),
                "value": "ask"
            }
        ]
        currentValue: root.tab
        onActivated: v => root.tab = v
    }

    Row {
        spacing: Skin.px(8)
        Mascot {
            pixel: Skin.px(3)
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            PxText {
                text: "OpenCode " + (OpencodeState.words[OpencodeState.state] || "")
                kind: "title"
            }
            PxText {
                text: (OpencodeState.model || "opencode") + (OpencodeState.provider ? " · " + OpencodeState.provider : "") + (OpencodeState.running ? "" : " · " + I18n.t("не запущен", "not running"))
                dim: true
            }
        }
    }

    Usage {
        visible: root.tab === "usage"
        width: parent.width
    }
    Row {
        visible: root.tab === "usage"
        spacing: Skin.px(8)
        PxButton {
            compact: true
            text: I18n.t("Обновить", "Refresh")
            icon: "refresh"
            onClicked: OpencodeState.refresh()
        }
        PxButton {
            compact: true
            text: I18n.t("Новая сессия", "New session")
            icon: "terminal"
            onClicked: OpencodeState.launch([])
        }
    }

    Column {
        visible: root.tab === "sessions"
        width: parent.width
        spacing: Skin.px(6)
        PxText {
            visible: OpencodeState.sessions.length === 0
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Нет живых сессий. Запущенный opencode находится сам — по локальной базе ~/.local/share/opencode.", "No live sessions. A running opencode is found on its own — from the local database ~/.local/share/opencode.")
        }
        Repeater {
            model: OpencodeState.sessions
            SkinCard {
                id: card
                required property var modelData
                width: root.width
                height: Skin.px(54)
                padding: 0
                group: true
                shadow: false
                pixelColor: Theme.faceAlt
                Row {
                    anchors.fill: parent
                    anchors.margins: Skin.px(8)
                    spacing: Skin.px(8)
                    Column {
                        width: parent.width - btnOpen.implicitWidth - Skin.px(8)
                        anchors.verticalCenter: parent.verticalCenter
                        PxText {
                            width: parent.width
                            elide: Text.ElideRight
                            font.bold: true
                            text: (card.modelData.title || card.modelData.id || "") + " · " + (OpencodeState.words[card.modelData.state] || card.modelData.state)
                            color: OpencodeState.stateColor(card.modelData.state, Theme)
                        }
                        PxText {
                            kind: "tiny"
                            dim: true
                            width: parent.width
                            elide: Text.ElideRight
                            text: (card.modelData.cwd ? card.modelData.cwd + " · " : "") + (card.modelData.model ? card.modelData.model + " · " : "") + OpencodeState.ago(Date.now() - card.modelData.age * 1000) + " · " + I18n.t("вх ", "in ") + OpencodeState.tokens(card.modelData.in) + " · " + I18n.t("вых ", "out ") + OpencodeState.tokens(card.modelData.out)
                        }
                    }
                    PxButton {
                        id: btnOpen
                        compact: true
                        icon: "terminal"
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("Открыть", "Open")
                        onClicked: OpencodeState.launch(["-s", card.modelData.fullId || card.modelData.id], card.modelData.dir)
                    }
                }
            }
        }
        PxButton {
            compact: true
            text: I18n.t("Продолжить последнюю", "Resume last")
            icon: "terminal"
            onClicked: OpencodeState.launch(["-c"])
        }
    }

    onTabChanged: if (tab === "ask") Qt.callLater(() => q.focusField())

    Column {
        visible: root.tab === "ask"
        width: parent.width
        spacing: Skin.px(6)
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Быстрый вопрос: opencode run с read-only агентом plan — без записи файлов. Ответ придёт уведомлением.", "Quick question: opencode run with the read-only plan agent — no files are written. The answer arrives as a notification.")
        }
        PxField {
            id: q
            width: parent.width
            placeholder: I18n.t("спроси OpenCode…", "Ask OpenCode…")
            enabled: !OpencodeState.asking
            onAccepted: {
                OpencodeState.ask(text);
                text = "";
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onPressed: m => {
                    q.focusField();
                    m.accepted = false;
                }
            }
        }
        PxButton {
            text: OpencodeState.asking ? I18n.t("Думаю…", "Thinking…") : I18n.t("Спросить", "Ask")
            icon: "bot"
            accent: true
            enabled: !OpencodeState.asking && q.text.trim() !== ""
            onClicked: q.accepted()
        }
        SkinCard {
            visible: !!OpencodeState.answer
            width: parent.width
            sunken: true
            padding: Skin.px(8)
            pixelColor: Qt.alpha(Theme.sunken, 0.8)
            Column {
                width: parent.width
                spacing: Skin.px(6)
                Row {
                    width: parent.width
                    PxText {
                        width: parent.width - btnCopy.implicitWidth - Skin.px(4)
                        wrapMode: Text.Wrap
                        font.bold: true
                        text: OpencodeState.answer ? "? " + OpencodeState.answer.q : ""
                    }
                    PxButton {
                        id: btnCopy
                        compact: true
                        icon: "copy"
                        text: I18n.t("Копировать", "Copy")
                        visible: !!(OpencodeState.answer && OpencodeState.answer.text)
                        onClicked: Quickshell.clipboardText = OpencodeState.answer ? OpencodeState.answer.text : ""
                    }
                }
                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: OpencodeState.answer ? (OpencodeState.answer.text || (OpencodeState.asking ? I18n.t("думаю…", "Thinking…") : "")) : ""
                    color: OpencodeState.answer && OpencodeState.answer.error ? Skin.danger : Skin.text
                }
            }
        }
    }
}
