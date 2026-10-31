#!/usr/bin/env python3
"""inspect_cache.py -- Check the desktop app's usage cache against what the app expects.

Read-only. It lists the cache folder's file names, decodes them back to keys, and
reads exactly the two entries GbotUsageBar reads (the account slot and that slot's
weekly-usage entry). It never opens any other entry -- the folder also holds
conversation transcripts -- and it masks the account slot, so its output is safe to
paste into an issue or a pull request.

Each finding names the Swift file that owns the assumption it checks, so a change in
the desktop app maps straight to the place to fix:

  folder path           -> Sources/GbotUsageBarPlatform/CacheFolderReader.swift
  key names, base32,
  percent-encoding      -> Sources/GbotUsageBarCore/CacheFileName.swift
  JSON shape            -> Sources/GbotUsageBarCore/UsageCache.swift

--search-bundle prints short snippets of the desktop app's bundled JavaScript around
the terms the app depends on, to see how the desktop app now names or parses them.

Usage:
  inspect_cache.py [--folder DIR] [--keys] [--search-bundle [--bundle FILE] [TERM ...]]

Exit status: 0 when both entries are found and parse as expected, 1 otherwise.
"""
from __future__ import annotations

import argparse
import base64
import datetime as _dt
import json
import sys
import urllib.parse
from pathlib import Path

DEFAULT_FOLDER = Path.home() / "Library/Application Support/Grok Bot/sand-client-persistence"
DEFAULT_BUNDLE = Path("/Applications/Grok Bot.app/Contents/Resources/app.asar")
ACCOUNT_SLOT_KEY = "sand.client.slice.client-meta.account-slot"
DEFAULT_TERMS = ["weekly-usage", "percentUsed", "account-slot", "nextResetMs"]
SNIPPET_RADIUS = 120
MAX_SNIPPETS_PER_TERM = 5

OWNER_FOLDER = "Sources/GbotUsageBarPlatform/CacheFolderReader.swift"
OWNER_NAMES = "Sources/GbotUsageBarCore/CacheFileName.swift"
OWNER_JSON = "Sources/GbotUsageBarCore/UsageCache.swift"


def file_name(key: str) -> str:
    """The file an entry with `key` is stored in: lowercase base32, no padding, `.blob`."""
    return base64.b32encode(key.encode()).decode().rstrip("=").lower() + ".blob"


def key_of(name: str) -> str | None:
    """The key a `.blob` file name encodes, or None when it is not base32 of UTF-8."""
    if not name.endswith(".blob"):
        return None
    stem = name[: -len(".blob")].upper()
    try:
        return base64.b32decode(stem + "=" * (-len(stem) % 8)).decode()
    except (ValueError, UnicodeDecodeError):
        return None


def weekly_usage_key(slot: str) -> str:
    """The weekly-usage key for `slot`, encoded like JavaScript's encodeURIComponent."""
    encoded = urllib.parse.quote(slot, safe="-_.!~*'()")
    return f"sand.client.slice.account.{encoded}.weekly-usage.cache"


def mask(text: str) -> str:
    """`text` with every run of the account slot's identifying part hidden."""
    if "|" in text:
        provider, _, user = text.partition("|")
        return f"{provider}|{user[:5]}…{user[-2:]}" if len(user) > 7 else f"{provider}|…"
    return text


def mask_key(key: str, slot: str | None) -> str:
    if not slot:
        return key
    encoded = urllib.parse.quote(slot, safe="-_.!~*'()")
    return key.replace(encoded, "<slot>").replace(slot, "<slot>")


def shape(value, prefix: str = "") -> list[str]:
    """Every key path in `value` with its JSON type, values left out."""
    if isinstance(value, dict):
        lines = []
        for k, v in value.items():
            path = f"{prefix}.{k}" if prefix else k
            lines.append(f"{path}: {type_name(v)}")
            lines.extend(shape(v, path))
        return lines
    return []


def type_name(value) -> str:
    if value is None:
        return "null"
    return {bool: "bool", int: "number", float: "number", str: "string",
            list: "array", dict: "object"}.get(type(value), type(value).__name__)


def when(ms) -> str:
    if not isinstance(ms, (int, float)):
        return f"<{type_name(ms)}>"
    stamp = _dt.datetime.fromtimestamp(ms / 1000, tz=_dt.timezone.utc).astimezone()
    return stamp.strftime("%Y-%m-%d %H:%M:%S %Z")


def inspect(folder: Path, list_keys: bool, out) -> bool:
    """Prints the report for `folder`; True when everything the app needs is there."""
    print(f"folder: {folder}", file=out)
    if not folder.is_dir():
        print(f"FAIL folder missing -- has the path moved? Fix: {OWNER_FOLDER}", file=out)
        return False
    names = sorted(p.name for p in folder.iterdir() if p.name.endswith(".blob"))
    keys = {n: key_of(n) for n in names}
    undecodable = [n for n, k in keys.items() if k is None]
    print(f"blobs: {len(names)} ({len(undecodable)} not decodable as base32 keys)", file=out)
    if names and len(undecodable) == len(names):
        print(f"FAIL no file name decodes -- the naming scheme changed. Fix: {OWNER_NAMES}", file=out)

    slot_path = folder / file_name(ACCOUNT_SLOT_KEY)
    slot = None
    if not slot_path.exists():
        print(f"FAIL account slot entry {ACCOUNT_SLOT_KEY} not found. Fix: {OWNER_NAMES}", file=out)
    else:
        try:
            slot_json = json.loads(slot_path.read_bytes())
            raw = slot_json.get("value") if isinstance(slot_json, dict) else None
            slot = raw if isinstance(raw, str) and raw else None
            print(f"account slot: schemaVersion={slot_json.get('schemaVersion') if isinstance(slot_json, dict) else '?'} "
                  f"value={mask(slot) if slot else repr(raw)}", file=out)
            if slot is None:
                print("FAIL account slot has no string value -- signed out, or the shape "
                      f"changed. Fix (if signed in): {OWNER_JSON}", file=out)
        except ValueError:
            print(f"FAIL account slot is not JSON. Fix: {OWNER_JSON}", file=out)

    if list_keys:
        print("keys:", file=out)
        for n in names:
            print(f"  {mask_key(keys[n], slot) if keys[n] else '<undecodable> ' + n}", file=out)
    if slot is None:
        return False

    usage_key = weekly_usage_key(slot)
    usage_path = folder / file_name(usage_key)
    if not usage_path.exists():
        print(f"FAIL weekly usage entry {mask_key(usage_key, slot)} not found. Fix: {OWNER_NAMES}", file=out)
        near = [mask_key(k, slot) for k in keys.values() if k and "usage" in k]
        print("  keys mentioning 'usage': " + (", ".join(near) or "none"), file=out)
        return False
    try:
        entry = json.loads(usage_path.read_bytes())
    except ValueError:
        print(f"FAIL weekly usage entry is not JSON (caught mid-write? rerun). Fix: {OWNER_JSON}", file=out)
        return False
    print("weekly usage shape:", file=out)
    for line in shape(entry):
        print(f"  {line}", file=out)
    value = entry.get("value") if isinstance(entry, dict) else None
    value = value if isinstance(value, dict) else {}
    reading = value.get("reading") if isinstance(value.get("reading"), dict) else {}
    usage = reading.get("usage") if isinstance(reading.get("usage"), dict) else {}
    percent = usage.get("percentUsed")
    print(f"schemaVersion: {entry.get('schemaVersion') if isinstance(entry, dict) else '?'}", file=out)
    print(f"kind: {value.get('kind')!r}", file=out)
    print(f"percentUsed: {percent!r} (badge shows {round_half_up(percent)})", file=out)
    print(f"nextResetMs: {when(usage.get('nextResetMs'))}", file=out)
    print(f"readAtMs: {when(reading.get('readAtMs'))}", file=out)
    print(f"expiresAtMs: {when(value.get('expiresAtMs'))}", file=out)
    ok = (value.get("kind") == "present" and isinstance(percent, (int, float))
          and isinstance(reading.get("readAtMs"), (int, float)))
    if value.get("kind") not in (None, "present") and ok is False:
        print("NOTE kind is not 'present' -- the desktop app holds no reading; open it signed in.", file=out)
    if not ok:
        print(f"FAIL the entry lacks kind 'present', a numeric percentUsed, or readAtMs. Fix: {OWNER_JSON}", file=out)
    else:
        print("OK the app can read this entry", file=out)
    return ok


def round_half_up(value) -> str:
    if not isinstance(value, (int, float)):
        return "--"
    return str(int(max(value, 0) + 0.5))


def search_bundle(bundle: Path, terms: list[str], out) -> bool:
    if not bundle.is_file():
        print(f"bundle not found: {bundle}", file=out)
        return False
    data = bundle.read_bytes()
    for term in terms:
        needle = term.encode()
        start = 0
        found = 0
        print(f"== {term}", file=out)
        while found < MAX_SNIPPETS_PER_TERM:
            at = data.find(needle, start)
            if at < 0:
                break
            snippet = data[max(at - SNIPPET_RADIUS, 0): at + len(needle) + SNIPPET_RADIUS]
            print("  " + snippet.decode("utf-8", "replace").replace("\n", " "), file=out)
            found += 1
            start = at + len(needle)
        if not found:
            print("  (not found)", file=out)
    return True


def main(argv: list[str] | None = None, out=sys.stdout) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--folder", type=Path, default=DEFAULT_FOLDER)
    parser.add_argument("--keys", action="store_true", help="list every decoded key (slot masked)")
    parser.add_argument("--search-bundle", action="store_true",
                        help="print snippets of the desktop app's bundle around TERMs instead")
    parser.add_argument("--bundle", type=Path, default=DEFAULT_BUNDLE)
    parser.add_argument("terms", nargs="*", default=DEFAULT_TERMS)
    args = parser.parse_args(argv)
    if args.search_bundle:
        return 0 if search_bundle(args.bundle, args.terms, out) else 1
    return 0 if inspect(args.folder, args.keys, out) else 1


if __name__ == "__main__":
    sys.exit(main())
