#!/usr/bin/env python3
import asyncio
import json
from pathlib import Path
from dotenv import dotenv_values
from telethon import TelegramClient
from telethon.sessions import StringSession

ROOT = Path(__file__).resolve().parent.parent
ENV_PATH = ROOT / "telegram" / ".env"
AUTH_STATE_PATH = ROOT / "telegram" / "auth_state.json"

values = dotenv_values(ENV_PATH)
api_id = int(values["TELEGRAM_API_ID"])
api_hash = values["TELEGRAM_API_HASH"]
phone = "+917259544880"

async def main():
    client = TelegramClient(StringSession(""), api_id, api_hash)
    await client.connect()
    print(f"[*] Sending login code request to {phone}...")
    sent = await client.send_code_request(phone)
    AUTH_STATE_PATH.write_text(json.dumps({
        "phone": phone,
        "phone_code_hash": sent.phone_code_hash,
        "session": client.session.save()
    }), encoding="utf-8")
    print(f"[✓] Code successfully sent to Telegram app for {phone}!")
    await client.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
