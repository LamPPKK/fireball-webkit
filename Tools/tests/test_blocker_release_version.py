import unittest

from Tools.blocker_release_version import (
    compare_versions,
    latest_blocker_tag,
    validate_candidate,
)


class BlockerReleaseVersionTests(unittest.TestCase):
    def test_selects_highest_numeric_version_not_most_recent_list_entry(self):
        releases = [
            {"tagName": "blocker-2026.08.18.10"},
            {"tagName": "unrelated"},
            {"tagName": "blocker-2026.08.19.2"},
            {"tagName": "blocker-2026.08.19.1"},
        ]
        self.assertEqual(latest_blocker_tag(releases), "blocker-2026.08.19.2")

    def test_rejects_equal_or_older_candidate(self):
        releases = [{"tagName": "blocker-2026.08.19.2"}]
        with self.assertRaisesRegex(ValueError, "must be newer"):
            validate_candidate("2026.08.19.2", releases)
        with self.assertRaisesRegex(ValueError, "must be newer"):
            validate_candidate("2026.08.18.99", releases)

    def test_accepts_newer_candidate_and_normalizes_trailing_zero(self):
        releases = [{"tagName": "blocker-2026.08.19.2"}]
        validate_candidate("2026.08.19.3", releases)
        self.assertEqual(compare_versions("1.2", "1.2.0"), 0)

    def test_rejects_malformed_blocker_tag(self):
        with self.assertRaisesRegex(ValueError, "invalid blocker version"):
            latest_blocker_tag([{"tagName": "blocker-latest"}])


if __name__ == "__main__":
    unittest.main()
