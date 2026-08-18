import tempfile
import unittest
from pathlib import Path

from Tools.create_blocker_manifest import create


class CreateBlockerManifestTests(unittest.TestCase):
    def test_rejects_non_numeric_rules_version_before_signing(self):
        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "missing"
            with self.assertRaisesRegex(ValueError, "dot-separated numeric"):
                create(missing, "https://example.com", "latest", "0.1.0", missing)

    def test_rejects_non_semantic_minimum_app_version_before_signing(self):
        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "missing"
            with self.assertRaisesRegex(ValueError, "major.minor.patch"):
                create(missing, "https://example.com", "2026.08.19.1", "0.1", missing)


if __name__ == "__main__":
    unittest.main()
