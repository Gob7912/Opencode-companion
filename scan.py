#!/usr/bin/env python3
"""OpenCode Companion scanner: live sessions, their state and today's tokens.

Reads OpenCode's local SQLite database (~/.local/share/opencode/opencode.db,
opened read-only). Session rows carry titles, directories, token counters and
timestamps; of the newest message only two things are looked at — its model
and whether it finished (the "completed" timestamp). Conversation contents are
never parsed or stored. Nothing goes over the network. A small day series in
~/.cache/angelos accumulates per-scan growth into "today's usage": a dip
(deleted sessions) never subtracts, only real growth is counted.

Prints one JSON object.
"""
import datetime
import json
import os
import re
import sqlite3
import sys
import time
from pathlib import Path

DATA = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
DB = DATA / "opencode" / "opencode.db"
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "angelos" / "opencode-scan.json"
LIVE_WINDOW = 60 * 60   # a session is live while updated within this (seconds)
STALE_WORKING_TIMEOUT = 2 * 60 * 60  # only consider an unfinished task abandoned after 2 hours
KEEP_DAYS = 30

MODEL_RE = re.compile(r'"model"\s*:\s*\{\s*"id"\s*:\s*"([^"]+)"[^}]*?"providerID"\s*:\s*"([^"]+)"')


def opencode_running():
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/comm") as f:
                if f.read().strip() == "opencode":
                    return True
        except OSError:
            pass
    return False


def load_cache():
    try:
        data = json.loads(CACHE.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save_cache(cache):
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    tmp = CACHE.with_suffix(".tmp")
    tmp.write_text(json.dumps(cache))
    tmp.replace(CACHE)


def model_of(text):
    m = MODEL_RE.search(text or "")
    return m.group(1) if m else ""


def main():
    running = opencode_running()
    if not DB.is_file():
        print(json.dumps({"installed": False, "running": running}))
        return
    now = time.time()
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=3)
    try:
        # -- live sessions (newest first).
        # time_suspended is NOT "paused": a streaming session gets it between
        # turns too — only time_archived takes a session out of the list.
        rows = con.execute(
            "select id, title, directory, time_updated, time_archived,"
            " tokens_input, tokens_output from session_v2"
            " order by time_updated desc limit 100").fetchall()
        sessions = []
        for sid, title, directory, updated, archived, tin, tout in rows:
            if archived:
                continue

            # Latest core message (ignoring meta events like agent-switched)
            got = con.execute(
                "select type, data, json_extract(data, '$.model.id'),"
                " json_extract(data, '$.finish'), json_extract(data, '$.time.completed'),"
                " max(time_updated, time_created)"
                " from session_message where session_id = ?"
                " and type in ('idle', 'user', 'assistant')"
                " order by seq desc limit 1", (sid,)).fetchone()
            mtype, data, mid, finish, completed, msg_time = got if got else ("", "", "", "", None, 0)

            last_act_ms = max(updated or 0, msg_time or 0)
            age = max(0, int(now - last_act_ms / 1000.0))

            # A session is working while:
            # 1) OpenCode process is actively running in the OS
            # 2) User prompt was sent (waiting for assistant)
            # 3) Assistant message is still streaming (completed is null)
            # 4) Assistant emitted tool calls (finish == 'tool-calls') and tools are executing
            # It is ONLY done when:
            # - OpenCode process is not running, OR
            # - The agent explicitly went idle (mtype == 'idle'), OR
            # - The assistant turn ended with a terminal finish ('stop' or 'length') and completed timestamp, OR
            # - An abandoned turn had zero activity for over 2 hours
            if not running or mtype == "idle":
                working = False
            elif mtype == "user":
                working = True
            elif mtype == "assistant":
                if not completed:
                    working = True
                elif finish == "tool-calls":
                    working = True
                elif finish in ("stop", "length"):
                    working = False
                else:
                    working = False
            else:
                working = False

            if working and age >= STALE_WORKING_TIMEOUT:
                working = False

            # If not working and older than LIVE_WINDOW, skip
            if not working and age > LIVE_WINDOW:
                continue

            model = mid if (mtype == "assistant" and mid) else ""
            if not model:
                older = con.execute(
                    "select json_extract(data, '$.model.id'), data from session_message where session_id = ?"
                    " and type = 'assistant' order by seq desc limit 1", (sid,)).fetchone()
                if older:
                    model = older[0] or model_of(older[1])
            last_text, last_msg_id, last_completed = "", "", 0
            # Only consider the final assistant answer (exclude intermediate tool-call steps and streaming)
            ast = con.execute(
                "select id, data, time_created from session_message where session_id = ?"
                " and type = 'assistant' and json_extract(data, '$.finish') in ('stop', 'length')"
                " and json_extract(data, '$.time.completed') is not null"
                " order by seq desc limit 1", (sid,)).fetchone()
            if ast:
                last_msg_id = ast[0] or ""
                try:
                    ast_data = json.loads(ast[1] or "{}")
                    last_completed = ast_data.get("time", {}).get("completed") or ast[2] or 0
                    parts = [c.get("text", "") for c in ast_data.get("content", []) if isinstance(c, dict) and c.get("type") == "text"]
                    last_text = " ".join(parts).strip()[:280]
                    if not last_text:
                        rparts = [c.get("text", "") for c in ast_data.get("content", []) if isinstance(c, dict) and c.get("type") == "reasoning"]
                        last_text = " ".join(rparts).strip()[:280]
                except Exception:
                    pass
            sessions.append({
                "id": sid[-8:],
                "fullId": sid,
                "dir": directory or "",
                "cwd": os.path.basename(directory or "") or "~",
                "title": (title or "")[:80],
                "model": model or "",
                "state": "working" if working else "done",
                "age": age,
                "in": tin or 0,
                "out": tout or 0,
                "lastMsgId": last_msg_id,
                "lastText": last_text,
                "lastCompleted": last_completed,
            })

        # -- totals across all sessions, turned into "today" by the day series
        row = con.execute(
            "select coalesce(sum(tokens_input),0), coalesce(sum(tokens_output),0),"
            " coalesce(sum(tokens_cache_read),0), coalesce(sum(cost),0)"
            " from session_v2").fetchone()
        totals = {"in": row[0] or 0, "out": row[1] or 0, "cache": row[2] or 0,
                  "cost": row[3] or 0}
        midnight = datetime.datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        today_start = int(midnight.timestamp() * 1000)
        today_sessions = con.execute(
            "select count(*) from session_v2 where time_created >= ?",
            (today_start,)).fetchone()[0] or 0

        # active model & provider
        active_model, active_provider = "", ""
        model_row = con.execute(
            "select json_extract(data, '$.model.id'), json_extract(data, '$.model.providerID'), data"
            " from session_message where type = 'assistant'"
            " order by time_created desc limit 1").fetchone()
        if model_row:
            active_model = model_row[0] or ""
            active_provider = model_row[1] or ""
            if not active_model and model_row[2]:
                m = MODEL_RE.search(model_row[2])
                if m:
                    active_model, active_provider = m.group(1), m.group(2)
    finally:
        con.close()

    # -- "today": accumulate only positive growth since the previous scan, per
    # metric and per day. Deleted sessions make totals dip — a dip never
    # subtracts; the first scan starts at zero (no historical overcount).
    today = datetime.date.today().isoformat()
    cache = load_cache()
    days = cache.setdefault("days", {})
    last = cache.get("last") if isinstance(cache.get("last"), dict) else None
    accum = days.setdefault(today, {"in": 0, "out": 0, "cache": 0})
    if last is None:
        # first scan ever: remember the totals, count nothing — activity from
        # before the plugin existed must not read as "today"
        cache["last"] = dict(totals)
    else:
        for k in ("in", "out", "cache"):
            delta = totals[k] - (last.get(k) or 0)
            if delta > 0:
                accum[k] = (accum.get(k) or 0) + delta
        cache["last"] = dict(totals)
    horizon = (datetime.date.today() - datetime.timedelta(days=KEEP_DAYS)).isoformat()
    for day in [d for d in days if d < horizon]:
        del days[day]
    save_cache(cache)
    usage = accum

    print(json.dumps({
        "installed": True,
        "running": running,
        "model": active_model,
        "provider": active_provider,
        "today": {"input_tokens": usage["in"], "output_tokens": usage["out"],
                  "cached_input_tokens": usage["cache"],
                  "total_tokens": usage["in"] + usage["out"]},
        "todaySessions": today_sessions,
        "cost": round(totals["cost"] or 0, 4),
        "sessions": sessions,
    }))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:   # a scanner bug must not break the widget
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
