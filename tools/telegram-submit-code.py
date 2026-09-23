#!/usr/bin/env python3
import argparse
import asyncio
import json
import os
from pathlib import Path
from dotenv import dotenv_values
from telethon import TelegramClient
from telethon.errors import SessionPasswordNeededError
from telethon.sessions import StringSession

ROOT = Path(__file__).resolve().parent.parent
ENV_PATH = ROOT / "telegram" / ".env"
SESSION_PATH = ROOT / "telegram" / "session.txt"
AUTH_STATE_PATH = ROOT / "telegram" / "auth_state.json"

values = dotenv_values(ENV_PATH)
api_id = int(values["TELEGRAM_API_ID"])
api_hash = values["TELEGRAM_API_HASH"]

async def main(code: str, password: str | None = None):
    if not AUTH_STATE_PATH.exists():
        raise SystemExit("No auth_state.json found. Run telegram-request-code.py first.")
    
    state = json.loads(AUTH_STATE_PATH.read_text(encoding="utf-8"))
    phone = state["phone"]
    phone_code_hash = state["phone_code_hash"]
    saved_session = state["session"]

    client = TelegramClient(StringSession(saved_session), api_id, api_hash)
    await client.connect()
    try:
        await client.sign_in(phone=phone, code=code, phone_code_hash=phone_code_hash)
    except SessionPasswordNeededError:
        if not password:
            print("2FA_REQUIRED")
            return
        await client.sign_in(password=password)

    # Save finalized session
    fd = os.open(SESSION_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(client.session.save())
    os.chmod(SESSION_PATH, 0o600)
    AUTH_STATE_PATH.unlink(missing_ok=True)
    me = await client.get_me()
    print(f"[✓] Successfully authenticated as {me.first_name} (@{me.username})!")
    await client.disconnect()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--code", required=True)
    parser.add_argument("--password", required=False)
    args = parser.parse_args()
    asyncio.run(main(args.code, args.password))
