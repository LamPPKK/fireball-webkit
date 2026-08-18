import base64
import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path

from Tools.verify_ipa import verify_ipa


class VerifyIPATests(unittest.TestCase):
    def make_ipa(self, info_overrides=None, include_privacy=True):
        directory = tempfile.TemporaryDirectory()
        ipa = Path(directory.name) / "Fireball.ipa"
        info = {
            "CFBundleIdentifier": "com.fireball.browser",
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "42",
            "MinimumOSVersion": "18.0",
        }
        info.update(info_overrides or {})
        with zipfile.ZipFile(ipa, "w") as archive:
            archive.writestr("Payload/FireballWebKit.app/Info.plist", plistlib.dumps(info))
            archive.writestr(
                "Payload/FireballWebKit.app/blocker-public-key.txt",
                base64.b64encode(bytes(32)).decode(),
            )
            if include_privacy:
                archive.writestr(
                    "Payload/FireballWebKit.app/PrivacyInfo.xcprivacy",
                    plistlib.dumps({"NSPrivacyTracking": False}),
                )
        return directory, ipa

    def test_accepts_expected_release_metadata(self):
        directory, ipa = self.make_ipa()
        self.addCleanup(directory.cleanup)
        self.assertEqual(verify_ipa(ipa, "com.fireball.browser", "0.1.0", "42"), [])

    def test_rejects_wrong_bundle_and_missing_privacy_manifest(self):
        directory, ipa = self.make_ipa(
            {"CFBundleIdentifier": "com.example.other"},
            include_privacy=False,
        )
        self.addCleanup(directory.cleanup)
        errors = verify_ipa(ipa, "com.fireball.browser", "0.1.0", "42")
        self.assertTrue(any("CFBundleIdentifier" in error for error in errors))
        self.assertTrue(any("PrivacyInfo.xcprivacy" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
