import QtQuick
import Quickshell
import Quickshell.Io
import "."

// IPC:  qs -c angelos ipc call opencode <fn>
Item {
    id: root
    property var plugin

    function apply() {
        if (!plugin)
            return;
        OpencodeState.scanScript = plugin.dir + "/scan.py";
        OpencodeState.intervalSec = plugin.get("interval", 60);
        OpencodeState.refresh();
    }
    Component.onCompleted: apply()
    onPluginChanged: apply()

    IpcHandler {
        target: "opencode"

        function status(): string {
            return JSON.stringify({
                "state": OpencodeState.state,
                "sessions": OpencodeState.sessions.length,
                "today_tokens": OpencodeState.today.total_tokens || 0,
                "model": OpencodeState.model,
                "provider": OpencodeState.provider,
                "cost": OpencodeState.cost
            });
        }
        function refresh(): void {
            OpencodeState.refresh();
        }
        function resume(): void {
            OpencodeState.launch(["-c"]);
        }
        function newSession(): void {
            OpencodeState.launch([]);
        }
        function ask(question: string): void {
            OpencodeState.ask(question);
        }
    }
}
