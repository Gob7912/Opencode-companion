pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// OpenCode state: live sessions, their state and today's tokens — all from
// scan.py reading the local opencode.db. No network, no conversation contents.
Singleton {
    id: root

    property var data: ({})
    property string status: "idle"      // idle | ok | noopencode | error
    property date updated: new Date(0)
    property int intervalSec: 60
    property string scanScript: ""      // Main.qml points it at the plugin folder
    property real now: Date.now()

    readonly property var today: data.today || ({})
    readonly property var sessions: data.sessions || []
    readonly property string state: sessions.some(s => s.state === "working") ? "working" : sessions.length ? "done" : "none"
    readonly property string model: data.model || ""
    readonly property string provider: data.provider || ""
    readonly property real cost: data.cost || 0
    readonly property int todaySessions: data.todaySessions || 0
    readonly property bool running: data.running === true

    readonly property string modelArg: {
        if (model)
            return provider ? (provider + "/" + model) : model;
        return "opencode/mimo-v2.6-flash-free";
    }

    function tokens(n) {
        n = n || 0;
        return n >= 1e6 ? (n / 1e6).toFixed(1) + "M" : n >= 1e3 ? (n / 1e3).toFixed(0) + "k" : String(n);
    }
    function ago(ms) {
        const m = Math.max(0, Math.round((now - ms) / 60000));
        return m < 1 ? I18n.t("только что", "just now") : m < 60 ? m + I18n.t(" мин назад", " min ago") : m < 2880 ? Math.round(m / 60) + I18n.t(" ч назад", " h ago") : Math.round(m / 1440) + I18n.t(" дн назад", " d ago");
    }
    function stateColor(s, theme) {
        return s === "working" ? theme.accent3 : s === "done" ? theme.ok : theme.textDim;
    }
    readonly property var words: ({
            "working": I18n.t("работает", "Working"),
            "done": I18n.t("готово ♡", "Ready ♡"),
            "none": I18n.t("нет сессий", "No sessions")
        })
    // hell (Theme.hell): plainer words in the circle's text colours
    readonly property var hellWords: ({
            "working": I18n.t("работает", "Working"),
            "done": I18n.t("готово", "Done"),
            "none": I18n.t("ни души", "No souls")
        })
    function hellStateColor(s, theme) {
        return s === "working" ? theme.hellText : s === "done" ? theme.hellAccent : theme.hellTextDim;
    }

    readonly property var _cfg: (Config.plugins.data || {})["opencode-companion"] || ({})
    readonly property bool notifyOnDone: _cfg.notifyOnDone !== false
    readonly property int pollIntervalMs: {
        if (!root.running)
            return Math.max(10, root.intervalSec) * 1000;
        if (root.state === "working")
            return 2000;
        return 5000;
    }

    property var _seenMsgIds: ({})
    property var _prevStates: ({})
    property bool _initialized: false

    function notifyFinished(session) {
        if (!session)
            return;
        const title = session.title ? (I18n.t("OpenCode: ", "OpenCode: ") + session.title) : I18n.t("OpenCode: готово ♡", "OpenCode: done ♡");
        const body = (session.lastText || "").trim() || (session.cwd ? (I18n.t("Папка: ", "Folder: ") + session.cwd) : I18n.t("Задача выполнена ♡", "Task completed ♡"));
        const preview = body.length > 280 ? body.slice(0, 280) + "…" : body;
        Quickshell.execDetached(["notify-send", "-a", "OpenCode", title, preview]);
    }

    function refresh() {
        now = Date.now();
        if (!scanScript || scanner.running)
            return;
        scanner.running = true;
    }
    Timer {
        interval: root.pollIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Process {
        id: scanner
        command: ["python3", root.scanScript]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.error) {
                        root.status = "error";
                        return;
                    }

                    const newSessions = d.sessions || [];
                    const prevStates = root._prevStates;
                    const seenMsgIds = root._seenMsgIds;
                    const nowMs = Date.now();

                    if (root._initialized && root.notifyOnDone) {
                        for (let i = 0; i < newSessions.length; ++i) {
                            const s = newSessions[i];
                            // Skip the companion's own inline ask tab queries
                            if (s.dir && s.dir.indexOf("opencode-ask") !== -1)
                                continue;

                            const wasWorking = (prevStates[s.fullId] === "working");
                            const prevMsgId = seenMsgIds[s.fullId];
                            const hasNewMsg = Boolean(s.lastMsgId && (!prevMsgId || s.lastMsgId !== prevMsgId));
                            const isRecent = Boolean(s.lastCompleted && (nowMs - s.lastCompleted) < 60000);
                            const isFastSession = (!prevMsgId && s.lastCompleted && (nowMs - s.lastCompleted) < 20000);

                            // Notify ONLY when the session is done, has a new completed message, completed recently,
                            // and either was tracked as working or completed right as it appeared.
                            if (s.state === "done" && hasNewMsg && isRecent && (wasWorking || isFastSession)) {
                                root.notifyFinished(s);
                            }
                        }
                    }

                    const nextStates = {};
                    const nextMsgIds = Object.assign({}, seenMsgIds);
                    for (let i = 0; i < newSessions.length; ++i) {
                        const s = newSessions[i];
                        nextStates[s.fullId] = s.state;
                        if (s.lastMsgId)
                            nextMsgIds[s.fullId] = s.lastMsgId;
                    }
                    root._prevStates = nextStates;
                    root._seenMsgIds = nextMsgIds;
                    root._initialized = true;

                    root.data = d;
                    root.status = d.installed ? "ok" : "noopencode";
                    root.updated = new Date();
                } catch (e) {
                    root.status = "error";
                }
            }
        }
        stderr: StdioCollector {}
    }

    // ---- quick question: `opencode run` with the read-only plan agent; the
    // answer arrives as a desktop notification (nothing is written anywhere)
    property var answer: null           // {q, text, error}
    property bool asking: false
    property bool timedOut: false
    function ask(q) {
        q = (q || "").trim();
        if (!q || asker.running)
            return;
        asking = true;
        timedOut = false;
        answer = {
            "q": q,
            "text": "",
            "error": false
        };
        asker.question = q + "\n\n(Ответь кратко обычным текстом: ответ покажет уведомление рабочего стола. Отвечай на языке вопроса.)";
        asker.command = [
            "sh", "-c",
            'mkdir -p "$1" && cd "$1" && exec opencode run --auto --agent plan -m "$2"',
            "sh",
            Config.cacheDir + "/opencode-ask",
            root.modelArg
        ];
        asker.running = true;
        askWatchdog.restart();
    }
    Timer {
        id: askWatchdog
        interval: 240 * 1000
        onTriggered: if (root.asking) {
            root.timedOut = true;
            asker.running = false;
            root.asking = false;
            root.answer = {
                "q": root.answer ? root.answer.q : "",
                "text": I18n.t("OpenCode не ответил за 4 минуты", "OpenCode did not answer within 4 minutes"),
                "error": true
            };
        }
    }
    Process {
        id: asker
        property string question: ""
        stdinEnabled: true
        onStarted: {
            write(question);
            stdinEnabled = false;
        }
        stdout: StdioCollector {
            id: askOut
        }
        stderr: StdioCollector {
            id: askErr
        }
        onExited: code => {
            stdinEnabled = true;
            if (root.timedOut) {
                root.timedOut = false;
                return;
            }
            let text = askOut.text.trim();
            // strip leading model banner if present
            if (text.startsWith("> plan")) {
                const nl = text.indexOf("\n");
                if (nl !== -1)
                    text = text.slice(nl).trim();
            }
            const failed = code !== 0 || text === "";
            const message = failed ? (code === 127 ? I18n.t("opencode не найден в PATH", "opencode was not found in PATH") : (askErr.text.trim().split("\n").slice(-2).join(" ") || I18n.t("opencode завершился с кодом ", "opencode exited with code ") + code)) : text;
            root.asking = false;
            root.answer = {
                "q": root.answer ? root.answer.q : "",
                "text": message,
                "error": failed
            };
            Quickshell.execDetached(["notify-send", "-a", "OpenCode", failed ? I18n.t("OpenCode: ошибка", "OpenCode: error") : I18n.t("OpenCode ответил ♡", "OpenCode replied ♡"), message.length > 280 ? message.slice(0, 280) + "…" : message]);
            root.refresh();
        }
    }

    // ---- terminal sessions ----
    function launch(args, dir) {
        const cdCmd = dir ? 'cd "' + dir.replace(/"/g, '\\"') + '"' : 'cd "$HOME"';
        const argv = ["sh", "-c", cdCmd + '; exec opencode "$@"', "sh"].concat(args || []);
        Quickshell.execDetached(Shell.terminalArgv(argv));
    }
    function login() {
        Quickshell.execDetached(Shell.terminalArgv(["sh", "-c", 'opencode auth login; printf "\\n♡ Enter — закрыть / close"; read _']));
    }
}
