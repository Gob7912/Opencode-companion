import QtQuick
import qs.config
import qs.services
import "."

// "oc <task>" → OpenCode in a terminal with the task · "oc ? question" → quick answer.
QtObject {
    id: root

    property var plugin
    property string pluginId
    readonly property string prefix: "oc"
    readonly property bool global: false
    signal changed

    function query(text, prefixed) {
        if (!prefixed)
            return [];
        if (text === "") {
            const list = [
                {
                    "id": "resume",
                    "title": I18n.t("Продолжить последнюю сессию", "Resume last session"),
                    "subtitle": "opencode -c",
                    "icon": "bot"
                },
                {
                    "id": "new",
                    "title": I18n.t("Новая сессия OpenCode", "New OpenCode session"),
                    "subtitle": I18n.t("opencode в терминале", "opencode in a terminal"),
                    "icon": "bot"
                }
            ];
            for (let i = 0; i < Math.min(3, OpencodeState.sessions.length); i++) {
                const s = OpencodeState.sessions[i];
                list.push({
                    "id": "session:" + (s.fullId || s.id) + "::" + (s.dir || ""),
                    "title": s.title || s.cwd || s.id,
                    "subtitle": (s.cwd ? s.cwd + " · " : "") + (OpencodeState.words[s.state] || s.state) + " · " + OpencodeState.ago(Date.now() - s.age * 1000),
                    "icon": "terminal"
                });
            }
            return list;
        }
        const m = text.match(/^\?\s*(.*)$/);
        if (m)
            return [
                {
                    "id": "ask:" + m[1],
                    "title": m[1] ? I18n.t("Спросить OpenCode", "Ask OpenCode") : I18n.t("Спросить: oc ? вопрос", "Ask: oc ? question"),
                    "subtitle": m[1] || I18n.t("агент plan без записи файлов, ответ уведомлением", "the plan agent, no file writes; the answer arrives as a notification"),
                    "icon": "bot",
                    "score": 100
                }
            ];
        return [
            {
                "id": "task:" + text,
                "title": I18n.t("Запустить OpenCode", "Launch OpenCode"),
                "subtitle": text,
                "icon": "bot",
                "score": 100
            }
        ];
    }

    function activate(id) {
        if (id === "resume")
            OpencodeState.launch(["-c"]);
        else if (id === "new")
            OpencodeState.launch([]);
        else if (id.startsWith("session:")) {
            const parts = id.slice(8).split("::");
            OpencodeState.launch(["-s", parts[0]], parts[1] || "");
        } else if (id.startsWith("ask:") && id.length > 4)
            OpencodeState.ask(id.slice(4));
        else if (id.startsWith("task:"))
            OpencodeState.launch(["--prompt", id.slice(5)]);
    }
}
