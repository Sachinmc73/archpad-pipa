#!/usr/bin/env python3
"""Bounded, read-only Telegram research for ArchPad.

This program has no mutation APIs in its implementation. It uses StringSession
instead of Telethon's default SQLite session, does not request media, and never
persists message text. Search output exists only in the terminal process.
"""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from datetime import timezone
from pathlib import Path

from dotenv import dotenv_values
from telethon import TelegramClient
from telethon.errors import SessionPasswordNeededError
from telethon.sessions import StringSession


ROOT = Path(__file__).resolve().parent
ENV_PATH = ROOT / ".env"
SESSION_PATH = ROOT / "session.txt"
NOTES_PATH = ROOT / "notes.md"
MAX_LIMIT = 100


def config() -> tuple[int, str, str | None]:
    values = dotenv_values(ENV_PATH)
    try:
        api_id = int(values["TELEGRAM_API_ID"])
        api_hash = values["TELEGRAM_API_HASH"]
    except (KeyError, TypeError, ValueError) as exc:
        raise SystemExit(
            "Missing TELEGRAM_API_ID or TELEGRAM_API_HASH in telegram/.env. "
            "Copy telegram/.env.example first."
        ) from exc
    if not api_hash:
        raise SystemExit("TELEGRAM_API_HASH must not be empty.")
    return api_id, api_hash, values.get("TELEGRAM_PHONE")


def load_session() -> str:
    if not SESSION_PATH.exists():
        return ""
    return SESSION_PATH.read_text(encoding="utf-8").strip()


def save_session(session: str) -> None:
    # StringSession is an authentication secret. Owner-only permissions are set
    # on creation and every update, including on systems with a loose umask.
    fd = os.open(SESSION_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(session)
    os.chmod(SESSION_PATH, 0o600)


async def login(client: TelegramClient, configured_phone: str | None) -> None:
    await client.connect()
    if await client.is_user_authorized():
        return
    phone = configured_phone or input("Telegram phone (+countrycode…): ").strip()
    if not phone:
        raise SystemExit("A phone number is required for initial authorization.")
    await client.send_code_request(phone)
    code = input("Telegram login code: ").strip()
    try:
        await client.sign_in(phone=phone, code=code)
    except SessionPasswordNeededError:
        # getpass prevents the password from being echoed to the terminal.
        from getpass import getpass
        await client.sign_in(password=getpass("Two-step verification password: "))


def message_line(message) -> str:
    stamp = message.date.astimezone(timezone.utc).isoformat() if message.date else "unknown-time"
    sender = getattr(message, "sender_id", "unknown-sender")
    text = (message.message or "").replace("\r", "").strip()
    # Avoid accidental terminal control sequences from chat content.
    text = text.replace("\x1b", "?")
    return f"[{stamp}] message={message.id} sender={sender}\n{text}\n"


async def run_query(args: argparse.Namespace) -> int:
    api_id, api_hash, phone = config()
    client = TelegramClient(StringSession(load_session()), api_id, api_hash)
    try:
        await login(client, phone)
        entity = await client.get_entity(args.chat)
        if args.command == "recent":
            messages = await client.get_messages(entity, limit=args.limit)
        else:
            messages = await client.get_messages(entity, search=args.keyword, limit=args.limit)
        print(f"Live read-only result: chat={args.chat!r}; returned={len(messages)}; limit={args.limit}")
        for message in reversed(messages):
            print(message_line(message))
        # Persist only the authorization token, never messages or query output.
        save_session(client.session.save())
        return 0
    finally:
        if client.is_connected():
            await client.disconnect()


def add_note(args: argparse.Namespace) -> int:
    # Explicit human-authored summary only. Raw output is never available here.
    if "\n" in args.text or not args.text.strip():
        raise SystemExit("--text must be one non-empty distilled finding.")
    NOTES_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not NOTES_PATH.exists():
        NOTES_PATH.write_text("# Telegram-distilled research notes\n\n", encoding="utf-8")
    with NOTES_PATH.open("a", encoding="utf-8") as handle:
        handle.write(f"- **{args.topic}** — {args.text.strip()} (source: {args.source})\n")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("recent", "search"):
        command = sub.add_parser(name)
        command.add_argument("chat", help="Existing public username or accessible chat ID")
        command.add_argument("--limit", type=int, required=True, choices=range(1, MAX_LIMIT + 1))
        if name == "search":
            command.add_argument("--keyword", required=True)
    note = sub.add_parser("note", help="Append one manually distilled finding; never raw message text")
    note.add_argument("--topic", required=True)
    note.add_argument("--source", required=True)
    note.add_argument("--text", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.command == "note":
        return add_note(args)
    return asyncio.run(run_query(args))


if __name__ == "__main__":
    sys.exit(main())
