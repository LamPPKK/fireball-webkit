import unittest

from Tools.select_simulator import runtime_version, select_device


class SelectSimulatorTests(unittest.TestCase):
    def test_runtime_version_accepts_ios_identifiers(self):
        self.assertEqual(runtime_version("com.apple.CoreSimulator.SimRuntime.iOS-18-6"), (18, 6, 0))
        self.assertIsNone(runtime_version("com.apple.CoreSimulator.SimRuntime.tvOS-18-0"))

    def test_selects_oldest_supported_runtime_for_requested_family(self):
        payload = {
            "devices": {
                "com.apple.CoreSimulator.SimRuntime.iOS-17-5": [
                    {"name": "iPhone 15", "udid": "old", "isAvailable": True}
                ],
                "com.apple.CoreSimulator.SimRuntime.iOS-26-1": [
                    {"name": "iPhone 17", "udid": "future", "isAvailable": True}
                ],
                "com.apple.CoreSimulator.SimRuntime.iOS-18-6": [
                    {"name": "iPad Air", "udid": "tablet", "isAvailable": True},
                    {"name": "iPhone 16 Pro", "udid": "phone", "isAvailable": True},
                ],
            }
        }

        self.assertEqual(select_device(payload, "iphone")["udid"], "phone")
        self.assertEqual(select_device(payload, "ipad")["udid"], "tablet")

    def test_rejects_missing_supported_device(self):
        with self.assertRaisesRegex(RuntimeError, "No available iphone simulator"):
            select_device({"devices": {}}, "iphone")


if __name__ == "__main__":
    unittest.main()
