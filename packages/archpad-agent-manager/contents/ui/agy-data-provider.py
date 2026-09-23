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
import shutil
import tempfile
import subprocess
import argparse
from datetime import datetime, timezone, timedelta

def clean_session_title(title, preview=None):
    raw = (title or preview or "Untitled Session").strip()
    for tag in ["<USER_REQUEST>", "</USER_REQUEST>", "<ADDITIONAL_METADATA>", "</ADDITIONAL_METADATA>", "<thinking>", "</thinking>"]:
        raw = raw.replace(tag, "")
    lines = [line.strip() for line in raw.split("\n") if line.strip()]
    if not lines:
        return "Untitled Session"
    first = lines[0].lstrip("#").strip()
    if len(first) > 42:
        return first[:41].rstrip() + "…"
    return first or "Untitled Session"

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

def ensure_dbus_env():
    uid = os.getuid()
    if not os.environ.get("XDG_RUNTIME_DIR"):
        run_dir = f"/run/user/{uid}"
        if os.path.exists(run_dir):
            os.environ["XDG_RUNTIME_DIR"] = run_dir
    if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        bus_path = f"/run/user/{uid}/bus"
        if os.path.exists(bus_path):
            os.environ["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={bus_path}"
    if not os.environ.get("WAYLAND_DISPLAY") and not os.environ.get("DISPLAY"):
        for w in ["wayland-0", "wayland-1"]:
            if os.path.exists(f"/run/user/{uid}/{w}"):
                os.environ["WAYLAND_DISPLAY"] = w
                break

def get_qdbus_cmd():
    for cmd in ["qdbus6", "qdbus", "/usr/lib/qt6/bin/qdbus", "/usr/bin/qdbus6"]:
        if shutil.which(cmd) or os.path.exists(cmd):
            return cmd
    return None

def get_agy_cmd():
    user_agy = os.path.expanduser("~/.local/bin/agy")
    if os.path.exists(user_agy):
        return user_agy
    which_agy = shutil.which("agy")
    if which_agy:
        return which_agy
    if os.path.exists("/home/archpad/.local/bin/agy"):
        return "/home/archpad/.local/bin/agy"
    return "agy"

def get_default_workdir():
    base_dir = os.path.expanduser("~/.gemini/antigravity-cli")
    settings_path = os.path.join(base_dir, "settings.json")
    if os.path.exists(settings_path):
        try:
            with open(settings_path, "r", encoding="utf-8") as sf:
                s = json.load(sf)
                tw = s.get("trustedWorkspaces", [])
                for w in tw:
                    if os.path.isdir(w):
                        return w
        except Exception:
            pass
    hw = os.path.expanduser("~/Work")
    if os.path.isdir(hw):
        return hw
    return os.path.expanduser("~")

def get_session_workspace(cid):
    if not cid:
        return None
    base_dir = os.path.expanduser("~/.gemini/antigravity-cli")
    db_path = os.path.join(base_dir, "conversation_summaries.db")
    if os.path.exists(db_path):
        try:
            db_uri = f"file:{os.path.abspath(db_path)}?mode=ro"
            con = sqlite3.connect(db_uri, uri=True, timeout=1.0)
            try:
                cur = con.cursor()
                row = cur.execute(
                    "SELECT workspace_uris FROM conversation_summaries WHERE conversation_id = ?;",
                    (cid,)
                ).fetchone()
                if row and row[0]:
                    wu = json.loads(row[0])
                    if wu:
                        p = wu[0].replace("file://", "")
                        if os.path.isdir(p):
                            return p
            finally:
                con.close()
        except Exception:
            pass
    return None

def focus_window_by_pids(pids):
    if not pids:
        return False
    ensure_dbus_env()
    qdbus_cmd = get_qdbus_cmd()
    if not qdbus_cmd:
        return False

    pid_list = [int(p) for p in pids if str(p).isdigit()]
    if not pid_list:
        return False

    script_content = f"""
    var pids = {pid_list};
    var clients = workspace.windowList();
    var matched = false;
    for (var i = 0; i < clients.length; i++) {{
        var c = clients[i];
        if (pids.indexOf(c.pid) !== -1) {{
            if (c.desktops && c.desktops.length > 0) {{
                workspace.currentDesktop = c.desktops[0];
            }}
            if (c.minimized) {{
                c.minimized = false;
            }}
            workspace.activeWindow = c;
            matched = true;
            break;
        }}
    }}
    """
    plugin_name = f"archpad_focus_{os.getpid()}_{int(time.time()*1000)%100000}"
    fd, path = tempfile.mkstemp(suffix=".js", prefix="kwin_focus_")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(script_content)

        load_res = subprocess.run(
            [qdbus_cmd, "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.loadScript", path, plugin_name],
            capture_output=True, text=True, timeout=3
        )
        out_lines = load_res.stdout.strip().splitlines()
        if not out_lines:
            return False
        script_id = out_lines[-1].strip()
        if not script_id.isdigit():
            return False

        script_path = f"/Scripting/Script{script_id}"
        subprocess.run([qdbus_cmd, "org.kde.KWin", script_path, "org.kde.kwin.Script.run"], timeout=2)
        subprocess.run([qdbus_cmd, "org.kde.KWin", script_path, "org.kde.kwin.Script.stop"], timeout=2)
        subprocess.run([qdbus_cmd, "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.unloadScript", plugin_name], timeout=2)
        return True
    except Exception:
        return False
    finally:
        if os.path.exists(path):
            try:
                os.remove(path)
            except Exception:
                pass

def launch_terminal(workdir, cmd_args):
    ensure_dbus_env()
    workdir = workdir or get_default_workdir()
    if not os.path.isdir(workdir):
        workdir = os.path.expanduser("~")
    konsole_bin = shutil.which("konsole") or "/usr/bin/konsole"
    full_cmd = [konsole_bin, "--workdir", workdir, "-e"] + cmd_args
    try:
        systemd_cmd = ["systemd-run", "--user"] + full_cmd
        res = subprocess.run(systemd_cmd, capture_output=True, timeout=5)
        if res.returncode == 0:
            return True
    except Exception:
        pass
    subprocess.Popen(full_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return True

def get_active_sessions_map():
    base_dir = os.path.expanduser("~/.gemini/antigravity-cli")
    presence_dir = os.path.join(base_dir, "presence")
    db_path = os.path.join(base_dir, "conversation_summaries.db")

    active_cids = {}
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

    # Exclude subagents (nesting_depth > 0) and killed conversations
    if active_cids and os.path.exists(db_path):
        try:
            db_uri = f"file:{os.path.abspath(db_path)}?mode=ro"
            con = sqlite3.connect(db_uri, uri=True, timeout=1.0)
            try:
                cur = con.cursor()
                placeholders = ",".join("?" for _ in active_cids)
                bad_rows = cur.execute(
                    f"SELECT conversation_id FROM conversation_summaries "
                    f"WHERE conversation_id IN ({placeholders}) AND (nesting_depth > 0 OR killed = 1);",
                    list(active_cids.keys())
                ).fetchall()
                for (bad_cid,) in bad_rows:
                    active_cids.pop(bad_cid, None)
            finally:
                con.close()
        except Exception:
            pass

    return active_cids

def open_session(cid, workdir=None):
    if cid:
        active_map = get_active_sessions_map()
        if cid in active_map:
            pids = active_map[cid]
            if focus_window_by_pids(pids):
                return {"status": "focused", "cid": cid}

    if not workdir and cid:
        workdir = get_session_workspace(cid)
    if not workdir:
        workdir = get_default_workdir()

    agy_bin = get_agy_cmd()
    cmd_args = [agy_bin]
    if cid:
        cmd_args.extend(["--conversation", cid])
    launch_terminal(workdir, cmd_args)
    return {"status": "launched", "cid": cid, "workdir": workdir}

def resume_last_session():
    base_dir = os.path.expanduser("~/.gemini/antigravity-cli")
    db_path = os.path.join(base_dir, "conversation_summaries.db")
    last_cid = None
    last_workdir = None

    if os.path.exists(db_path):
        try:
            db_uri = f"file:{os.path.abspath(db_path)}?mode=ro"
            con = sqlite3.connect(db_uri, uri=True, timeout=1.0)
            try:
                cur = con.cursor()
                row = cur.execute(
                    "SELECT conversation_id, workspace_uris "
                    "FROM conversation_summaries "
                    "WHERE nesting_depth = 0 AND killed = 0 "
                    "ORDER BY MAX(last_modified_time, last_user_input_time) DESC LIMIT 1;"
                ).fetchone()
                if row:
                    last_cid = row[0]
                    w_uris = row[1]
                    if w_uris:
                        try:
                            wu = json.loads(w_uris)
                            if wu:
                                last_workdir = wu[0].replace("file://", "")
                        except Exception:
                            pass
            finally:
                con.close()
        except Exception:
            pass

    active_map = get_active_sessions_map()
    if active_map:
        if last_cid and last_cid in active_map:
            if focus_window_by_pids(active_map[last_cid]):
                return {"status": "focused", "cid": last_cid}
        for act_cid, pids in active_map.items():
            if focus_window_by_pids(pids):
                return {"status": "focused", "cid": act_cid}

    if not last_cid:
        workdir = get_default_workdir()
        launch_terminal(workdir, [get_agy_cmd()])
        return {"status": "launched_new", "workdir": workdir}

    workdir = last_workdir or get_default_workdir()
    launch_terminal(workdir, [get_agy_cmd(), "--conversation", last_cid])
    return {"status": "resumed", "cid": last_cid, "workdir": workdir}

def new_session(workdir=None):
    workdir = workdir or get_default_workdir()
    launch_terminal(workdir, [get_agy_cmd()])
    return {"status": "launched_new", "workdir": workdir}

def focus_session(cid):
    if not cid:
        return resume_last_session()
    active_map = get_active_sessions_map()
    if cid in active_map:
        if focus_window_by_pids(active_map[cid]):
            return {"status": "focused", "cid": cid}
    return open_session(cid)

def get_agy_provider_data(force_refresh=False):
    base_dir = os.path.expanduser("~/.gemini/antigravity-cli")
    db_path = os.path.join(base_dir, "conversation_summaries.db")
    settings_path = os.path.join(base_dir, "settings.json")

    # Retrieve current active keyring credentials & account info
    access_token, account_info = get_keyring_account_and_token()
    account_email = account_info.get("email", "")
    account_name = account_info.get("name", "")

    # 1. Active lock detection
    active_cids = get_active_sessions_map()

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
    
    now = datetime.now().astimezone()
    today = now.date()
    cutoff = now - timedelta(days=7)
    daily_stats = {today - timedelta(days=i): {"steps": 0, "sessions": 0} for i in range(6, -1, -1)}
    recent_5h_steps = 0

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
                tot = cur.execute(
                    "SELECT count(*), sum(step_count) FROM conversation_summaries "
                    "WHERE nesting_depth = 0 AND killed = 0;"
                ).fetchone()
                if tot:
                    total_sessions = tot[0] or 0
                    total_steps = tot[1] or 0

                db_rows = cur.execute(
                    "SELECT conversation_id, title, preview, step_count, last_modified_time, last_user_input_time, workspace_uris "
                    "FROM conversation_summaries "
                    "WHERE nesting_depth = 0 AND killed = 0 "
                    "ORDER BY MAX(last_modified_time, last_user_input_time) DESC LIMIT 25;"
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
    limits = compute_agy_limits(now, recent_5h_steps, week_steps, access_token, account_email, force_refresh)

    # Sessions List
    sessions = []
    seen_ids = set()

    # Active sessions first
    for cid in active_cids:
        title = "Active Session"
        workspace = get_default_workdir()
        steps = 0
        mtime = None

        if os.path.exists(db_path):
            try:
                db_uri = f"file:{os.path.abspath(db_path)}?mode=ro"
                con = sqlite3.connect(db_uri, uri=True, timeout=1.0)
                try:
                    cur = con.cursor()
                    r = cur.execute(
                        "SELECT title, preview, step_count, last_modified_time, workspace_uris "
                        "FROM conversation_summaries WHERE conversation_id = ?;",
                        (cid,)
                    ).fetchone()
                    if r:
                        t, prev, st, mt, wu = r
                        title = clean_session_title(t, prev)
                        steps = st or 0
                        mtime = mt
                        if wu:
                            try:
                                parsed_wu = json.loads(wu)
                                if parsed_wu:
                                    w_candidate = parsed_wu[0].replace("file://", "")
                                    if os.path.isdir(w_candidate):
                                        workspace = w_candidate
                            except Exception:
                                pass
                finally:
                    con.close()
            except Exception:
                pass

        if title == "Active Session":
            t_path = os.path.join(base_dir, "brain", cid, ".system_generated/logs/transcript.jsonl")
            if os.path.exists(t_path):
                try:
                    with open(t_path, "r", encoding="utf-8") as tf:
                        for line in tf:
                            entry = json.loads(line)
                            if entry.get("type") == "USER_INPUT":
                                cnt = entry.get("content", "")
                                title = clean_session_title(cnt)
                                break
                except Exception:
                    pass

        sessions.append({
            "id": cid,
            "title": title,
            "workspace": workspace,
            "workspace_name": os.path.basename(workspace) or workspace,
            "steps": steps,
            "steps_str": f"{format_count(steps)} turns" if steps > 0 else "Active",
            "time_ago": "Active now",
            "is_active": True,
            "pids": active_cids.get(cid, [])
        })
        seen_ids.add(cid)

    # Inactive recent sessions
    for r in db_rows:
        cid, title_raw, preview, steps, mtime, user_input_time, w_uris = r
        if cid in seen_ids:
            continue

        clean_t = clean_session_title(title_raw, preview)
        w_dir = get_default_workdir()
        if w_uris:
            try:
                wu = json.loads(w_uris)
                if wu:
                    w_cand = wu[0].replace("file://", "")
                    if os.path.isdir(w_cand):
                        w_dir = w_cand
            except Exception:
                pass

        effective_time = mtime
        if user_input_time and user_input_time > (mtime or ""):
            effective_time = user_input_time

        sessions.append({
            "id": cid,
            "title": clean_t,
            "workspace": w_dir,
            "workspace_name": os.path.basename(w_dir) or w_dir,
            "steps": steps or 0,
            "steps_str": f"{format_count(steps or 0)} turns",
            "time_ago": format_time_ago(effective_time),
            "is_active": False,
            "pids": []
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

    # Dynamic workspaces
    workspaces = []
    seen_w = set()
    for w in trusted_workspaces:
        if w and w not in seen_w and os.path.isdir(w):
            seen_w.add(w)
            workspaces.append({
                "path": w,
                "name": os.path.basename(w) or w
            })
    for s in sessions:
        w = s.get("workspace")
        if w and w not in seen_w and os.path.isdir(w):
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
    installed = (shutil.which("claude") is not None) or os.path.exists(claude_dir) or os.path.exists("/usr/local/bin/claude") or os.path.exists(os.path.expanduser("~/.local/bin/claude"))
    return {
        "id": "claude",
        "name": "Claude Code",
        "is_installed": bool(installed),
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
    installed = (shutil.which("codex") is not None) or os.path.exists("/usr/local/bin/codex") or os.path.exists(os.path.expanduser("~/.codex")) or os.path.exists(os.path.expanduser("~/.local/bin/codex"))
    return {
        "id": "codex",
        "name": "Codex",
        "is_installed": bool(installed),
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
    providers = [get_agy_provider_data(force_refresh=force_refresh)]
    claude = get_claude_provider_data()
    if claude.get("is_installed"):
        providers.append(claude)
    codex = get_codex_provider_data()
    if codex.get("is_installed"):
        providers.append(codex)
    return {
        "providers": providers,
        "active_provider_id": "agy"
    }

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ArchPad Agent Manager Provider")
    parser.add_argument("--action", choices=["data", "open", "focus", "resume", "new"], default="data")
    parser.add_argument("--cid", default=None, help="Conversation ID")
    parser.add_argument("--workdir", default=None, help="Working directory")
    parser.add_argument("--force-refresh", action="store_true", help="Force refresh quota cache")
    args = parser.parse_args()

    if args.action == "data":
        data = get_all_data(force_refresh=args.force_refresh)
        try:
            cache_dir = os.path.expanduser("~/.cache/archpad-agent-manager")
            os.makedirs(cache_dir, exist_ok=True)
            with open(os.path.join(cache_dir, "data.json"), "w", encoding="utf-8") as f:
                json.dump(data, f)
        except Exception:
            pass
        json.dump(data, sys.stdout)
        sys.stdout.write("\n")
    elif args.action == "focus":
        res = focus_session(args.cid)
        print(json.dumps(res))
    elif args.action == "open":
        res = open_session(args.cid, workdir=args.workdir)
        print(json.dumps(res))
    elif args.action == "resume":
        res = resume_last_session()
        print(json.dumps(res))
    elif args.action == "new":
        res = new_session(workdir=args.workdir)
        print(json.dumps(res))
