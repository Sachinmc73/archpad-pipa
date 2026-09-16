#!/usr/bin/env python3
"""
agy-data-provider.py
Multi-provider agent metadata provider for GNOME Shell Agent Manager.
Implements Omarchy's usage, limits, and activity contract.
"""

import os
import sys
import json
import sqlite3
import fcntl
import time
from datetime import datetime, timezone, timedelta

def format_time_ago(dt_str):
    if not dt_str:
        return ""
    try:
        clean_str = dt_str.split(".")[0]
        if "+" in dt_str:
            clean_str += "+" + dt_str.split("+")[1]
        elif "Z" in dt_str:
            clean_str += "+00:00"
        else:
            clean_str += "+00:00"
        dt = datetime.fromisoformat(clean_str)
        now = datetime.now(timezone.utc)
        diff = (now - dt).total_seconds()
        if diff < 60:
            return "Just now"
        elif diff < 3600:
            return f"{int(diff // 60)}m ago"
        elif diff < 86400:
            return f"{int(diff // 3600)}h ago"
        elif diff < 172800:
            return "Yesterday"
        elif diff < 604800:
            return f"{int(diff // 86400)}d ago"
        else:
            return f"{int(diff // 604800)}w ago"
    except Exception:
        return ""

def format_count(count):
    if not count:
        return "0"
    if count >= 1000:
        return f"{count / 1000:.1f}k".replace(".0k", "k")
    return str(count)

def get_keyring_account_and_token():
    try:
        import gi
        from gi.repository import Gio, GLib
        import base64

        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        res = bus.call_sync(
            'org.freedesktop.secrets',
            '/org/freedesktop/secrets',
            'org.freedesktop.Secret.Service',
            'SearchItems',
            GLib.Variant('(a{ss})', [{'service': 'gemini', 'username': 'antigravity'}]),
            None, Gio.DBusCallFlags.NONE, 1000, None
        )
        unlocked, _ = res.unpack()
        if not unlocked:
            return None, {}

        res_session = bus.call_sync(
            'org.freedesktop.secrets',
            '/org/freedesktop/secrets',
            'org.freedesktop.Secret.Service',
            'OpenSession',
            GLib.Variant('(sv)', ['plain', GLib.Variant('s', '')]),
            None, Gio.DBusCallFlags.NONE, 1000, None
        )
        _, session_path = res_session.unpack()
        res_sec = bus.call_sync(
            'org.freedesktop.secrets',
            unlocked[0],
            'org.freedesktop.Secret.Item',
            'GetSecret',
            GLib.Variant('(o)', [session_path]),
            None, Gio.DBusCallFlags.NONE, 1000, None
        )
        sec_json = json.loads(bytes(res_sec.unpack()[0][2]).decode('utf-8'))
        access_token = sec_json.get('token', {}).get('access_token')

        account_info = {}
        id_token = sec_json.get('id_token')
        if id_token and isinstance(id_token, str) and '.' in id_token:
            try:
                payload = id_token.split('.')[1]
                payload += '=' * (-len(payload) % 4)
                claims = json.loads(base64.urlsafe_b64decode(payload))
                account_info['email'] = claims.get('email', '')
                account_info['name'] = claims.get('name', '')
            except Exception:
                pass
        return access_token, account_info
    except Exception:
        return None, {}

def fetch_dynamic_agy_quotas(access_token, account_email, force_refresh=False):
    cache_dir = os.path.expanduser("~/.cache/agy-agent-manager")
    os.makedirs(cache_dir, exist_ok=True)
    cache_file = os.path.join(cache_dir, "quota-cache.json")

    # Reuse cache ONLY if not forced AND same account AND within 20-second reuse window
    if not force_refresh and os.path.exists(cache_file):
        try:
            mtime = os.path.getmtime(cache_file)
            if time.time() - mtime < 20:
                with open(cache_file, "r", encoding="utf-8") as f:
                    cached = json.load(f)
                    if cached and "groups" in cached:
                        cached_acc = cached.get("_account_email", "")
                        if not account_email or cached_acc == account_email:
                            return cached
        except Exception:
            pass

    if not access_token:
        if os.path.exists(cache_file):
            try:
                with open(cache_file, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return None

    try:
        import urllib.request
        body = json.dumps({'project': 'aicode-consumers'}).encode('utf-8')
        req = urllib.request.Request(
            'https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary',
            data=body,
            headers={
                'Authorization': f'Bearer {access_token}',
                'Content-Type': 'application/json',
                'User-Agent': 'antigravity/1.2.0'
            }
        )
        with urllib.request.urlopen(req, timeout=4) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            data["_account_email"] = account_email
            try:
                with open(cache_file, "w", encoding="utf-8") as f:
                    json.dump(data, f)
            except Exception:
                pass
            return data
    except Exception:
        # Graceful fallback to cached data if network times out
        if os.path.exists(cache_file):
            try:
                with open(cache_file, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return None

def compute_agy_limits(now, recent_5h_steps, week_steps, access_token=None, account_email=None, force_refresh=False):
    quota_data = fetch_dynamic_agy_quotas(access_token, account_email, force_refresh)
    if quota_data and "groups" in quota_data:
        limits = []
        for group in quota_data.get("groups", []):
            group_name = group.get("displayName", "")
            short_prefix = "Gemini" if "gemini" in group_name.lower() else ("Claude" if "claude" in group_name.lower() else group_name)
            buckets = group.get("buckets", [])
            
            def bucket_sort_key(b):
                w = b.get("window", "").lower()
                return 0 if "5h" in w or "session" in w else 1

            for b in sorted(buckets, key=bucket_sort_key):
                rem_frac = b.get("remainingFraction", 1.0)
                if rem_frac is None:
                    rem_frac = 1.0
                remaining_ratio = max(0.0, min(1.0, float(rem_frac)))
                pct_int = round(remaining_ratio * 100)
                
                window = b.get("window", "").lower()
                window_label = "5-hour" if "5h" in window else ("Weekly" if "week" in window else b.get("displayName", "Limit"))
                title = f"{short_prefix} ({window_label})"
                reset_time_str = b.get("resetTime", "")
                
                resets_in = "Ready"
                if remaining_ratio < 1.0 and reset_time_str:
                    try:
                        clean = reset_time_str.replace("Z", "+00:00")
                        dt = datetime.fromisoformat(clean)
                        diff = (dt - now).total_seconds()
                        if diff > 0:
                            days = int(diff // 86400)
                            hours = int((diff % 86400) // 3600)
                            mins = int((diff % 3600) // 60)
                            if days > 0:
                                resets_in = f"Resets in {days}d {hours}h"
                            elif hours > 0:
                                resets_in = f"Resets in {hours}h {mins}m"
                            else:
                                resets_in = f"Resets in {max(1, mins)}m"
                    except Exception:
                        pass
                        
                limits.append({
                    "group": group_name,
                    "title": title,
                    "window": window_label,
                    "percent": round(remaining_ratio, 4),
                    "percent_int": pct_int,
                    "percent_str": f"{pct_int}% remaining",
                    "resets_in": resets_in,
                    "resets_at": reset_time_str,
                    "alarming": remaining_ratio <= 0.1
                })
        if limits:
            return limits

    # Fallback to local heuristic if offline and no cache exists
    session_quota = 500
    session_rem = max(0.0, min(1.0, 1.0 - (recent_5h_steps / session_quota)))
    weekly_quota = 10000
    weekly_rem = max(0.0, min(1.0, 1.0 - (week_steps / weekly_quota)))
    resets_session_in = "4h 12m" if recent_5h_steps > 0 else "Ready"
    days_to_sunday = (6 - now.weekday()) % 7
    resets_weekly_in = f"{days_to_sunday}d {24 - now.hour}h" if days_to_sunday > 0 else f"{24 - now.hour}h"

    return [
        {
            "group": "Gemini Models",
            "title": "Gemini (5-hour)",
            "window": "5-hour",
            "percent": round(session_rem, 4),
            "percent_int": round(session_rem * 100),
            "percent_str": f"{round(session_rem * 100)}% remaining",
            "resets_in": f"Resets in {resets_session_in}" if session_rem < 1.0 else "Ready",
            "alarming": session_rem <= 0.1
        },
        {
            "group": "Gemini Models",
            "title": "Gemini (Weekly)",
            "window": "Weekly",
            "percent": round(weekly_rem, 4),
            "percent_int": round(weekly_rem * 100),
            "percent_str": f"{round(weekly_rem * 100)}% remaining",
            "resets_in": f"Resets in {resets_weekly_in}" if weekly_rem < 1.0 else "Ready",
            "alarming": weekly_rem <= 0.1
        },
        {
            "group": "Claude and GPT models",
            "title": "Claude (5-hour)",
            "window": "5-hour",
            "percent": 1.0,
            "percent_int": 100,
            "percent_str": "100% remaining",
            "resets_in": "Ready",
            "alarming": False
        },
        {
            "group": "Claude and GPT models",
            "title": "Claude (Weekly)",
            "window": "Weekly",
            "percent": 1.0,
            "percent_int": 100,
            "percent_str": "100% remaining",
            "resets_in": "Ready",
            "alarming": False
        }
    ]

def get_agy_provider_data(force_refresh=False):
    base_dir = os.path.expanduser("~/.gemini/antigravity-cli")
    db_path = os.path.join(base_dir, "conversation_summaries.db")
    presence_dir = os.path.join(base_dir, "presence")
    settings_path = os.path.join(base_dir, "settings.json")

    # Retrieve current active keyring credentials & account info
    access_token, account_info = get_keyring_account_and_token()
    account_email = account_info.get("email", "")
    account_name = account_info.get("name", "")

    # 1. Active lock detection via /proc/locks and fcntl test
    active_cids = {}  # cid -> [pids]
    inode_to_pid = {}
    try:
        with open("/proc/locks", "r") as pf:
            for line in pf:
                parts = line.strip().split()
                if len(parts) >= 6 and parts[1] == "FLOCK":
                    try:
                        pid = int(parts[4])
                        ino = int(parts[5].split(":")[2])
                        inode_to_pid[ino] = pid
                    except Exception:
                        pass
    except Exception:
        pass

    def get_ancestors(pid):
        res = [pid]
        curr = pid
        while curr > 1:
            try:
                with open(f"/proc/{curr}/stat", "r") as stat_f:
                    stat_parts = stat_f.read().split()
                    ppid = int(stat_parts[3])
                    if ppid <= 1:
                        break
                    res.append(ppid)
                    curr = ppid
            except Exception:
                break
        return res

    if os.path.exists(presence_dir):
        for fname in os.listdir(presence_dir):
            if fname.endswith(".lock"):
                cid = fname[:-5]
                fpath = os.path.join(presence_dir, fname)
                try:
                    is_locked = False
                    with open(fpath, "r") as lock_file:
                        try:
                            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
                        except (BlockingIOError, PermissionError):
                            is_locked = True
                    if is_locked:
                        st = os.stat(fpath)
                        holder_pid = inode_to_pid.get(st.st_ino)
                        if holder_pid:
                            active_cids[cid] = get_ancestors(holder_pid)
                        else:
                            active_cids[cid] = []
                except Exception:
                    pass

    # 2. Settings
    settings = {}
    if os.path.exists(settings_path):
        try:
            with open(settings_path, "r", encoding="utf-8") as sf:
                settings = json.load(sf)
        except Exception:
            pass

    current_model = settings.get("model", "Gemini 3.8 Flash (High)")
    current_mode = settings.get("agentMode", "accept-edits")
    trusted_workspaces = settings.get("trustedWorkspaces", ["/home/archpad/Work"])

    # 3. Database records
    total_sessions = 0
    total_steps = 0
    db_rows = []
    
    # 7-day activity tracking & 5-hour rolling usage in local timezone
    now = datetime.now().astimezone()
    today = now.date()
    cutoff = now - timedelta(days=7)
    daily_stats = {today - timedelta(days=i): {"steps": 0, "sessions": 0} for i in range(6, -1, -1)}
    recent_5h_steps = 0

    # Scan active transcripts from the last 7 days for true step-level timestamps
    brain_dir = os.path.join(base_dir, "brain")
    if os.path.exists(brain_dir):
        try:
            for cid in os.listdir(brain_dir):
                t_path = os.path.join(brain_dir, cid, ".system_generated", "logs", "transcript.jsonl")
                if not os.path.exists(t_path) or os.path.getmtime(t_path) < cutoff.timestamp():
                    continue
                with open(t_path, "r", encoding="utf-8") as f:
                    for line in f:
                        idx = line.find('"created_at":"')
                        if idx != -1:
                            end_idx = line.find('"', idx + 14)
                            try:
                                dt = datetime.fromisoformat(line[idx+14:end_idx]).astimezone()
                                d = dt.date()
                                if d in daily_stats:
                                    daily_stats[d]["steps"] += 1
                                if (now - dt).total_seconds() <= 18000:
                                    recent_5h_steps += 1
                            except Exception:
                                pass
        except Exception:
            pass

    if os.path.exists(db_path):
        try:
            db_uri = f"file:{os.path.abspath(db_path)}?mode=ro"
            con = sqlite3.connect(db_uri, uri=True, timeout=1.0)
            try:
                cur = con.cursor()
                tot = cur.execute("SELECT count(*), sum(step_count) FROM conversation_summaries;").fetchone()
                if tot:
                    total_sessions = tot[0] or 0
                    total_steps = tot[1] or 0

                db_rows = cur.execute(
                    "SELECT conversation_id, title, preview, step_count, last_modified_time, workspace_uris "
                    "FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 25;"
                ).fetchall()
            finally:
                con.close()
        except Exception:
            pass

    # Build 7-day breakdown for Activity Chart
    recent_days = []
    peak_day_steps = 1
    for d in sorted(daily_stats.keys()):
        peak_day_steps = max(peak_day_steps, daily_stats[d]["steps"])

    for d in sorted(daily_stats.keys()):
        day_label = "Today" if d == today else d.strftime("%a")
        st = daily_stats[d]["steps"]
        recent_days.append({
            "date": d.isoformat(),
            "day": day_label,
            "count": st,
            "count_str": format_count(st),
            "ratio": round(st / peak_day_steps, 3),
            "is_today": (d == today)
        })

    week_steps = sum(d["steps"] for d in daily_stats.values())
    # Dynamic Limit Windows from Antigravity backend API (Gemini & Claude pools)
    limits = compute_agy_limits(now, recent_5h_steps, week_steps, access_token, account_email, force_refresh)

    # Sessions List
    sessions = []
    seen_ids = set()

    for cid in active_cids:
        title = "Active Agent Session"
        workspace = "/home/archpad/Work"
        t_path = os.path.join(base_dir, "brain", cid, ".system_generated/logs/transcript.jsonl")
        if os.path.exists(t_path):
            try:
                with open(t_path, "r", encoding="utf-8") as tf:
                    for line in tf:
                        entry = json.loads(line)
                        if entry.get("type") == "USER_INPUT":
                            cnt = entry.get("content", "")
                            clean_cnt = cnt.replace("<USER_REQUEST>", "").replace("</USER_REQUEST>", "").strip()
                            if clean_cnt:
                                first_line = clean_cnt.split("\n")[0].strip()
                                title = first_line[:26] + "…" if len(first_line) > 26 else first_line
                                break
            except Exception:
                pass

        sessions.append({
            "id": cid,
            "title": title[:26] + "…" if len(title) > 26 else title,
            "workspace": workspace,
            "workspace_name": os.path.basename(workspace),
            "steps": 0,
            "steps_str": "Active",
            "time_ago": "Active now",
            "is_active": True,
            "pids": active_cids.get(cid, [])
        })
        seen_ids.add(cid)

    for r in db_rows:
        cid, title, preview, steps, mtime, w_uris = r
        raw_t = title if title else (preview if preview else "Untitled Session")
        clean_t = raw_t.replace("<USER_REQUEST>", "").replace("</USER_REQUEST>", "").strip().split("\n")[0].strip()
        formatted_title = clean_t[:26] + "…" if len(clean_t) > 26 else clean_t

        if cid in seen_ids:
            for s in sessions:
                if s["id"] == cid:
                    s["title"] = formatted_title
                    s["steps"] = steps or 0
                    s["steps_str"] = format_count(steps or 0)
                    s["pids"] = active_cids.get(cid, [])
                    if w_uris:
                        try:
                            wu = json.loads(w_uris)
                            if wu:
                                s["workspace"] = wu[0].replace("file://", "")
                                s["workspace_name"] = os.path.basename(s["workspace"])
                        except Exception:
                            pass
            continue

        w_list = []
        if w_uris:
            try:
                w_list = json.loads(w_uris)
            except Exception:
                pass
        w_dir = w_list[0].replace("file://", "") if w_list else "/home/archpad/Work"

        sessions.append({
            "id": cid,
            "title": formatted_title,
            "workspace": w_dir,
            "workspace_name": os.path.basename(w_dir),
            "steps": steps or 0,
            "steps_str": f"{format_count(steps or 0)} turns",
            "time_ago": format_time_ago(mtime),
            "is_active": cid in active_cids,
            "pids": active_cids.get(cid, [])
        })
        seen_ids.add(cid)

    # Models breakdown
    models = [
        {
            "name": current_model,
            "total": total_steps,
            "total_str": format_count(total_steps),
            "share": 1.0
        }
    ]

    # Trusted workspaces
    workspaces = []
    seen_w = set()
    for w in trusted_workspaces:
        if w not in seen_w and os.path.isdir(w):
            seen_w.add(w)
            workspaces.append({
                "path": w,
                "name": os.path.basename(w) or w
            })

    return {
        "id": "agy",
        "name": "Antigravity",
        "account": account_email,
        "account_name": account_name,
        "cli": "agy",
        "tier": current_model,
        "mode": current_mode,
        "is_active": len(active_cids) > 0,
        "active_count": len(active_cids),
        "total_sessions": max(total_sessions, len(sessions)),
        "total_steps": total_steps,
        "total_steps_str": format_count(total_steps),
        "limits": limits,
        "recent_days": recent_days,
        "models": models,
        "sessions": sessions[:10],
        "workspaces": workspaces[:5]
    }

def get_claude_provider_data():
    claude_dir = os.path.expanduser("~/.claude")
    installed = os.path.exists(claude_dir) or os.path.exists("/usr/local/bin/claude") or os.path.exists(os.path.expanduser("~/.local/bin/claude"))
    return {
        "id": "claude",
        "name": "Claude Code",
        "account": "",
        "account_name": "",
        "cli": "claude",
        "tier": "Pro / Max" if installed else "Not Configured",
        "mode": "auto",
        "is_active": False,
        "active_count": 0,
        "total_sessions": 0,
        "total_steps": 0,
        "total_steps_str": "0",
        "limits": [
            {"title": "Session (5-hour)", "percent": 1.0, "percent_int": 100, "percent_str": "100% remaining", "resets_in": "Ready", "alarming": False},
            {"title": "Weekly (7-day)", "percent": 1.0, "percent_int": 100, "percent_str": "100% remaining", "resets_in": "Ready", "alarming": False}
        ],
        "recent_days": [],
        "models": [],
        "sessions": [],
        "workspaces": []
    }

def get_codex_provider_data():
    return {
        "id": "codex",
        "name": "Codex",
        "account": "",
        "account_name": "",
        "cli": "codex",
        "tier": "Not Configured",
        "mode": "approve-for-me",
        "is_active": False,
        "active_count": 0,
        "total_sessions": 0,
        "total_steps": 0,
        "total_steps_str": "0",
        "limits": [
            {"title": "Session (5-hour)", "percent": 1.0, "percent_int": 100, "percent_str": "100% remaining", "resets_in": "Ready", "alarming": False},
            {"title": "Weekly (7-day)", "percent": 1.0, "percent_int": 100, "percent_str": "100% remaining", "resets_in": "Ready", "alarming": False}
        ],
        "recent_days": [],
        "models": [],
        "sessions": [],
        "workspaces": []
    }

def get_all_data(force_refresh=False):
    providers = [get_agy_provider_data(force_refresh=force_refresh), get_claude_provider_data(), get_codex_provider_data()]
    return {
        "providers": providers,
        "active_provider_id": "agy"
    }

if __name__ == "__main__":
    force_refresh = "--force-refresh" in sys.argv
    json.dump(get_all_data(force_refresh=force_refresh), sys.stdout)
    sys.stdout.write("\n")
