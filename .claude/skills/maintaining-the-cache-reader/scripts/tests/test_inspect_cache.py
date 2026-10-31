#!/usr/bin/env python3
"""Tests for inspect_cache.py. Stdlib-only (unittest).

Run: python3 -m unittest discover -s scripts/tests -p 'test_*.py'
     (from the maintaining-the-cache-reader skill directory)
"""
from __future__ import annotations

import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import inspect_cache as ic  # noqa: E402

SLOT = "provider|user_ABCDEFGH"
USAGE = {
    "schemaVersion": 2,
    "value": {
        "kind": "present",
        "reading": {"usage": {"percentUsed": 2.77, "nextResetMs": 1794052800000},
                    "readAtMs": 1794040200000},
        "expiresAtMs": 1794126600000,
    },
}


class NamingTests(unittest.TestCase):
    def test_file_name_matches_the_name_observed_on_disk(self):
        self.assertEqual(
            ic.file_name(ic.ACCOUNT_SLOT_KEY),
            "onqw4zbomnwgszlooqxhg3djmnss4y3mnfsw45bnnvsxiyjomfrwg33vnz2c243mn52a.blob",
        )

    def test_key_of_round_trips_and_refuses_other_names(self):
        self.assertEqual(ic.key_of(ic.file_name("a.b-c")), "a.b-c")
        self.assertIsNone(ic.key_of("not base32!.blob"))
        self.assertIsNone(ic.key_of("notes.txt"))

    def test_weekly_usage_key_percent_encodes_the_slot(self):
        self.assertEqual(
            ic.weekly_usage_key("p|u"), "sand.client.slice.account.p%7Cu.weekly-usage.cache")

    def test_mask_hides_most_of_the_user_id(self):
        self.assertEqual(ic.mask(SLOT), "provider|user_…GH")
        self.assertEqual(ic.mask("p|short"), "p|…")


class InspectTests(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.folder = Path(self._dir.name)

    def tearDown(self):
        self._dir.cleanup()

    def write(self, key, value):
        (self.folder / ic.file_name(key)).write_text(
            value if isinstance(value, str) else json.dumps(value))

    def run_inspect(self, list_keys=False):
        out = io.StringIO()
        ok = ic.inspect(self.folder, list_keys, out)
        return ok, out.getvalue()

    def test_a_good_cache_passes_and_never_prints_the_slot(self):
        self.write(ic.ACCOUNT_SLOT_KEY, {"schemaVersion": 1, "value": SLOT})
        self.write(ic.weekly_usage_key(SLOT), USAGE)
        self.write("sand.client.slice.secret.transcript", {"text": "private words"})
        ok, text = self.run_inspect(list_keys=True)
        self.assertTrue(ok, text)
        self.assertIn("OK the app can read this entry", text)
        self.assertIn("badge shows 3", text)
        self.assertNotIn("ABCDEFGH", text)
        self.assertNotIn("private words", text)
        self.assertIn("sand.client.slice.account.<slot>.weekly-usage.cache", text)

    def test_a_missing_folder_points_at_the_folder_reader(self):
        out = io.StringIO()
        self.assertFalse(ic.inspect(self.folder / "absent", False, out))
        self.assertIn(ic.OWNER_FOLDER, out.getvalue())

    def test_a_missing_slot_points_at_the_key_names(self):
        ok, text = self.run_inspect()
        self.assertFalse(ok)
        self.assertIn(ic.OWNER_NAMES, text)

    def test_a_renamed_usage_key_lists_the_candidates(self):
        self.write(ic.ACCOUNT_SLOT_KEY, {"value": SLOT})
        self.write("sand.client.slice.account.provider%7Cuser_ABCDEFGH.usage-v2.cache", USAGE)
        ok, text = self.run_inspect()
        self.assertFalse(ok)
        self.assertIn("usage-v2", text)
        self.assertNotIn("ABCDEFGH", text)

    def test_a_changed_shape_points_at_the_json_decoder(self):
        self.write(ic.ACCOUNT_SLOT_KEY, {"value": SLOT})
        self.write(ic.weekly_usage_key(SLOT), {"value": {"kind": "present", "reading": {"pct": 3}}})
        ok, text = self.run_inspect()
        self.assertFalse(ok)
        self.assertIn(ic.OWNER_JSON, text)
        self.assertIn("value.reading.pct: number", text)

    def test_an_absent_reading_is_explained(self):
        self.write(ic.ACCOUNT_SLOT_KEY, {"value": SLOT})
        self.write(ic.weekly_usage_key(SLOT), {"value": {"kind": "absent"}})
        ok, text = self.run_inspect()
        self.assertFalse(ok)
        self.assertIn("NOTE kind is not 'present'", text)

    def test_a_signed_out_slot_fails(self):
        self.write(ic.ACCOUNT_SLOT_KEY, {"value": None})
        ok, text = self.run_inspect()
        self.assertFalse(ok)
        self.assertIn("no string value", text)


class BundleSearchTests(unittest.TestCase):
    def test_snippets_are_printed_around_each_term(self):
        with tempfile.TemporaryDirectory() as d:
            bundle = Path(d) / "app.asar"
            bundle.write_bytes(b"xx return{percentUsed:Math.max(e,0)} yy")
            out = io.StringIO()
            self.assertEqual(ic.main(["--search-bundle", "--bundle", str(bundle),
                                      "percentUsed", "missingTerm"], out), 0)
            self.assertIn("percentUsed:Math.max", out.getvalue())
            self.assertIn("(not found)", out.getvalue())

    def test_a_missing_bundle_fails(self):
        out = io.StringIO()
        self.assertEqual(ic.main(["--search-bundle", "--bundle", "/nonexistent/app.asar"], out), 1)


if __name__ == "__main__":
    unittest.main()
