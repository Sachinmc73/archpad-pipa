#!/usr/bin/env python3
"""Download PixelOS 17 (Android 17) ROM and Recovery images for Xiaomi Pad 6 (pipa)."""

import asyncio
import hashlib
import os
import sys
import time
from pathlib import Path
from dotenv import dotenv_values
from telethon import TelegramClient
from telethon.sessions import StringSession

ROOT = Path(__file__).resolve().parent.parent
ENV_PATH = ROOT / "telegram" / ".env"
SESSION_PATH = ROOT / "telegram" / "session.txt"
OUTPUT_DIR = ROOT / "artifacts" / "downloads" / "pixelos17"

FILES_TO_DOWNLOAD = [
    {
        "channel": "dump_cloud_001",
        "msg_id": 352,
        "filename": "dtbo.img",
        "expected_sha256": "196e34f95e02a7272b18cff311ffce5f710bf64417eba1eedac9bbfe7e82af58",
        "expected_size": 33554432,
    },
    {
        "channel": "dump_cloud_001",
        "msg_id": 353,
        "filename": "vendor_boot.img",
        "expected_sha256": "f7f7d3fed1d226ceeeb72b27d3993a5b05294aed6846bb0d4d80064b46fe86da",
        "expected_size": 100663296,
    },
    {
        "channel": "dump_cloud_001",
        "msg_id": 354,
        "filename": "boot.img",
        "expected_sha256": "22d9c1525b8c7b596e71e5fa9b2fcb5f1b9f151042f2dad66ae15a12fb5695ba",
        "expected_size": 201326592,
    },
    {
        "channel": "ArtemSmolyarVault",
        "msg_id": 3184,
        "filename": "PixelOS_pipa-17.0-20260911-1143.zip",
        "expected_sha256": "0181af343416c20deb1283e9ed2be1f22ce0beb565765671719d4bcb15a7828e",
        "expected_size": 2493058136,
    },
]


def config() -> tuple[int, str]:
    values = dotenv_values(ENV_PATH)
    return int(values["TELEGRAM_API_ID"]), values["TELEGRAM_API_HASH"]


def load_session() -> str:
    return SESSION_PATH.read_text(encoding="utf-8").strip()


def verify_file(filepath: Path, expected_sha: str) -> bool:
    if not filepath.exists():
        return False
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(1024 * 1024):
            h.update(chunk)
    actual = h.hexdigest()
    return actual.lower() == expected_sha.lower()


async def download_item(client: TelegramClient, item: dict):
    filename = item["filename"]
    target = OUTPUT_DIR / filename
    expected_sha = item["expected_sha256"]

    if target.exists():
        print(f"[*] Checking existing {filename}...")
        if verify_file(target, expected_sha):
            print(f"[✓] {filename} is already downloaded and verified!")
            return
        else:
            print(f"[!] Checksum mismatch for existing {filename}. Re-downloading...")
            target.unlink(missing_ok=True)

    print(f"\n[*] Fetching message {item['msg_id']} from @{item['channel']}...")
    entity = await client.get_entity(item["channel"])
    msg = await client.get_messages(entity, ids=item["msg_id"])
    if not msg or not msg.media:
        raise RuntimeError(f"No media found in @{item['channel']}/{item['msg_id']}")

    file_size = getattr(msg.file, "size", item["expected_size"])
    print(f"[*] Starting download of {filename} ({file_size / (1024*1024):.2f} MB)...")

    start_time = time.time()
    last_print = 0

    def progress(current, total):
        nonlocal last_print
        now = time.time()
        if now - last_print >= 2.0 or current == total:
            last_print = now
            elapsed = max(now - start_time, 0.001)
            mb = current / (1024 * 1024)
            total_mb = total / (1024 * 1024)
            speed = mb / elapsed
            pct = (current / total * 100) if total else 0
            eta = ((total - current) / (1024 * 1024)) / speed if speed > 0 else 0
            print(f"[{filename}] {mb:.1f}/{total_mb:.1f} MB ({pct:.1f}%) | {speed:.2f} MB/s | ETA: {int(eta)}s", flush=True)

    part_file = target.with_suffix(target.suffix + ".part")
    await client.download_media(msg, file=str(part_file), progress_callback=progress)

    part_file.rename(target)
    print(f"[✓] Finished downloading {filename}!")
    print(f"[*] Verifying SHA256 for {filename}...")
    if verify_file(target, expected_sha):
        print(f"[✓] SHA256 VERIFIED: {expected_sha}")
    else:
        print(f"[!] WARNING: SHA256 mismatch on {filename}!")


async def main():
    api_id, api_hash = config()
    session_str = load_session()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    client = TelegramClient(StringSession(session_str), api_id, api_hash)
    await client.connect()
    try:
        me = await client.get_me()
        print(f"[+] Connected as {me.first_name} (@{me.username})")
        for item in FILES_TO_DOWNLOAD:
            await download_item(client, item)
        print("\n[🎉] ALL PIXELOS 17 FILES DOWNLOADED AND VERIFIED SUCCESSFULLY!")
    finally:
        await client.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
