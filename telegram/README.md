# Read-only Telegram research

This is a deliberately narrow research client for public or already-accessible
Xiaomi Pad 6 Linux chats. It uses Telethon's in-memory `StringSession`, saved
only as `telegram/session.txt`; it does not create Telethon's SQLite message
database or a `.session` file.

## Setup

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp telegram/.env.example telegram/.env
chmod 600 telegram/.env
```

Put the API ID and hash obtained from <https://my.telegram.org/apps> in
`telegram/.env`. Both the credentials file and the authenticated session are
ignored by Git. On the first query the program asks for the phone number,
login code, and (if enabled) two-step-verification password. Input is never
printed or saved except for the authorization session token in `session.txt`.

## Queries

All queries require an explicit bounded `--limit` (1-100). The client connects,
reads at most that many matching or recent messages, prints them for immediate
human review, and disconnects in a `finally` block. It never sends a message,
reacts, joins/leaves a chat, marks messages read, downloads media, or writes
message content to disk.

```bash
# Exact public username or an accessible chat ID. No joining is attempted.
.venv/bin/python telegram/research.py recent pipa_mainline --limit 20
.venv/bin/python telegram/research.py search pipa_mainline \
  --keyword 'kernel 6.12' --limit 20
```

Only manually distilled findings may be recorded. `notes.md` intentionally
contains no raw message text, exports, message database, or media:

```bash
.venv/bin/python telegram/research.py note \
  --topic kernel --source 'pipa_mainline, 2026-09-04' \
  --text 'Maintainer report: validate the named branch against its upstream commit before adopting it.'
```

Before publishing or sharing this repository, run `git status --ignored` and
confirm that `telegram/.env` and `telegram/session.txt` are not staged.

