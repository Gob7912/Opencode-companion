import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "."

Column {
    id: root
    property var plugin
    width: parent ? parent.width : 400
    spacing: Skin.px(10)

    PxGroup {
        title: I18n.t("Сейчас", "Current")
        icon: "bot"
        width: parent.width
        Panel {
            width: parent.width
            plugin: root.plugin
        }
    }

    PxGroup {
        title: I18n.t("Откуда данные", "Where the numbers come from")
        icon: "info"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Из локальной базы самого OpenCode (~/.local/share/opencode/opencode.db, открыта только на чтение): заголовки сессий, счётчики токенов, модели и время. Содержимое переписки не читается, сеть не используется. «Сегодня» копится приростом между сканами — удалённые сессии ничего не вычитают.", "From OpenCode's own local database (~/.local/share/opencode/opencode.db, opened read-only): session titles, token counters, models and time. Conversation contents are never read and nothing goes over the network. \"Today\" accumulates the growth between scans — deleted sessions never subtract.")
        }
        PxButton {
            text: I18n.t("Открыть OpenCode", "Open OpenCode")
            icon: "terminal"
            onClicked: OpencodeState.launch([])
        }
        PxButton {
            text: I18n.t("Войти (auth login)", "Sign in (auth login)")
            icon: "lock"
            onClicked: OpencodeState.login()
        }
    }

    PxGroup {
        title: I18n.t("Вид", "Appearance")
        icon: "sparkle"
        width: parent.width
        SettingRow {
            label: I18n.t("На панели", "In the bar")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Авто", "Auto"),
                        "value": "auto"
                    },
                    {
                        "label": I18n.t("Сессии", "Sessions"),
                        "value": "sessions"
                    },
                    {
                        "label": I18n.t("Токены", "Tokens"),
                        "value": "today"
                    },
                    {
                        "label": I18n.t("Значок", "Icon"),
                        "value": "off"
                    }
                ]
                currentValue: root.plugin ? root.plugin.get("barMode", "auto") : "auto"
                onActivated: v => root.plugin.set("barMode", v)
            }
        }
        SettingRow {
            label: I18n.t("Значок на панели всегда", "Always show the bar icon")
            hint: I18n.t("иначе только когда идёт сессия", "Otherwise only while a session runs")
            PxToggle {
                checked: root.plugin ? root.plugin.get("barAlways", true) : true
                onToggled: c => root.plugin.set("barAlways", c)
            }
        }
        SettingRow {
            label: I18n.t("Уведомление по окончании", "Notify when task finishes")
            hint: I18n.t("Присылать уведомление, когда OpenCode завершил ответ", "Send a desktop notification when OpenCode finishes an answer")
            PxToggle {
                checked: root.plugin ? root.plugin.get("notifyOnDone", true) : true
                onToggled: c => root.plugin.set("notifyOnDone", c)
            }
        }
        SettingRow {
            label: I18n.t("Виджет на столе", "Desktop widget")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Всегда", "Always"),
                        "value": "always"
                    },
                    {
                        "label": I18n.t("Когда активен", "When active"),
                        "value": "active"
                    },
                    {
                        "label": I18n.t("Скрыт", "Hidden"),
                        "value": "off"
                    }
                ]
                currentValue: root.plugin ? root.plugin.get("orb", "always") : "always"
                onActivated: v => root.plugin.set("orb", v)
            }
        }
        SettingRow {
            label: I18n.t("Обновлять каждые", "Refresh every")
            PxSpin {
                from: 15
                to: 600
                stepSize: 15
                value: root.plugin ? root.plugin.get("interval", 60) : 60
                suffix: I18n.t(" с", " s")
                onMoved: v => {
                    root.plugin.set("interval", v);
                    OpencodeState.intervalSec = v;
                }
            }
        }
    }
}
