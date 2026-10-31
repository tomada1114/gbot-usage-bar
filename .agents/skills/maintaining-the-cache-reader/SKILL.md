---
name: maintaining-the-cache-reader
description: >
  Covers diagnosing and fixing GbotUsageBar when it stops showing the right weekly
  usage because the desktop app it reads from changed: the menu says "No saved
  usage", "Unexpected usage cache format", "Couldn't read the desktop app's usage
  cache", or "Usage may be out of date"; the badge stays at "--"; the number disagrees
  with the desktop app's Usage page; or the desktop app was updated. Also covers
  CacheFolderReader's folder path, CacheFileName's key and base32 file naming,
  UsageCache's JSON decoding, scripts/inspect_cache.py, and reading the desktop app's
  app.asar bundle to see how it now stores the usage.
---

# Maintaining the Cache Reader

**Owns:** finding out what changed in the desktop app's cache and where in this app that
assumption lives, and the order to fix it in. **Does not own:** error enums and their
mapping (`designing-errors`), the menu's wording (`localizing-the-app`), test-first
mechanics (`tdd`), seeing the fix in the running app (`running-the-app`).

## What the app assumes

The app has no API to lean on. It reads files the desktop app writes for itself, so
every one of these is an observation (first made 2026-10-31, desktop app 0.78.1) that a
desktop app update can break without notice:

| Assumption | Owner |
|---|---|
| The cache folder is `~/Library/Application Support/Grok Bot/sand-client-persistence/` | `Sources/GbotUsageBarPlatform/CacheFolderReader.swift` (`defaultFolder`) |
| One file per entry, named lowercase RFC 4648 base32 of the key, no `=` padding, plus `.blob` | `Sources/GbotUsageBarCore/CacheFileName.swift` (`forKey`, `base32`) |
| The signed-in account is in `sand.client.slice.client-meta.account-slot` as `{"value":"<provider>\|user_…"}` | `CacheFileName.accountSlotKey`, `UsageCache.accountSlot(from:)` |
| The weekly entry's key is `sand.client.slice.account.<slot, encodeURIComponent>.weekly-usage.cache` | `CacheFileName.weeklyUsageKey(forSlot:)` |
| That entry is `{"value":{"kind":"present","reading":{"usage":{"percentUsed","nextResetMs"},"readAtMs"},"expiresAtMs"}}`, times in epoch milliseconds | `Sources/GbotUsageBarCore/UsageCache.swift` (`usage(from:)` and the private `Decodable` structs) |
| The desktop app rounds `percentUsed` half up for its own Usage page | `Sources/GbotUsageBarCore/UsageWindow.swift` (`percent`) |
| The files are plain JSON, not encrypted or compressed | `UsageCache` |

`schemaVersion` is deliberately not checked: a bump that keeps the fields keeps working,
and one that moves them surfaces as `unexpectedFormat`.

## Diagnose first

1. **Read the symptom off the menu** — each line maps to one `UsageError` case:

   | Menu line | Case | Usually means |
   |---|---|---|
   | No saved usage — open the desktop app and sign in | `noCachedUsage` | signed out, never opened, or a key / folder renamed |
   | Couldn't read the desktop app's usage cache | `cacheUnreadable` | permissions, or the folder became protected |
   | Unexpected usage cache format | `unexpectedFormat` | the JSON shape changed, or encryption was added |
   | Usage may be out of date — … | `outOfDate` | not a bug: the desktop app has not refetched in a day, or the week reset |

   `just logs` shows the same case per refresh (`refresh failed: <case>`).

2. **Rule out "it is just stale".** Open the desktop app's Usage page, wait a minute,
   and check whether the menu's "Updated" time moved. If it moved and the numbers
   agree, nothing is broken.

3. **Run the inspector** (read-only; masks the account slot; never opens transcripts):

   ```bash
   python3 .agents/skills/maintaining-the-cache-reader/scripts/inspect_cache.py
   python3 .agents/skills/maintaining-the-cache-reader/scripts/inspect_cache.py --keys
   ```

   Every `FAIL` line names the Swift file that owns the broken assumption. The
   `weekly usage shape` list shows field paths and types without values, so a renamed
   field is visible at a glance. `--keys` lists every decoded key, for a renamed entry.

4. **Ask the desktop app how it does it now.** Its UI is bundled JavaScript; the
   inspector prints snippets around the terms this app depends on:

   ```bash
   python3 .agents/skills/maintaining-the-cache-reader/scripts/inspect_cache.py --search-bundle
   python3 .agents/skills/maintaining-the-cache-reader/scripts/inspect_cache.py --search-bundle usagePercent weekly
   ```

   Look for the key string it persists under, the object it writes (`percentUsed:`,
   `readAtMs:`), and how its Usage page formats the percent (`Math.round`,
   `toFixed`, `Math.floor`).

Never print, paste, or commit a real blob, the account slot, or anything from another
entry: the folder also holds the owner's conversations, and this repository is public.
Fixtures use a made-up slot such as `provider|user_1`.

## Fix

1. Write the failing Core test first (`tdd`) with a fixture of the *new* shape, built by
   hand from the inspector's shape list: `UsageCacheTests` for a JSON change,
   `CacheFileNameTests` for a naming change, `UsageWindowTests` for rounding.
2. Change the owner from the table above. Keep the decoder lenient — optional fields,
   a missing one decided in `UsageCache`, not a `DecodingError` — and keep
   `CacheFolderReader` translation-only.
3. A folder move changes `CacheFolderReader.defaultFolder` only; confirm it with
   `just test-local` (`CacheFolderReaderTests` reads the real cache).
4. If the desktop app starts encrypting the cache or stops writing it, there is no
   local fix: record it in the README's caveat and stop.
5. Update the table above, the README's "How it gets the numbers", and the inspector's
   constants (`ACCOUNT_SLOT_KEY`, `weekly_usage_key`, `DEFAULT_FOLDER`) in the same
   change, so the next diagnosis starts from the truth.
6. `just test`, `just test-local`, `just test-scripts`, then `just run` and compare with
   the desktop app (`running-the-app`).
