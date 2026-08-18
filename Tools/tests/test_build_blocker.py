import importlib.util
import pathlib
import unittest


MODULE_PATH = pathlib.Path(__file__).parents[1] / "build_blocker.py"
SPEC = importlib.util.spec_from_file_location("build_blocker", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class BuildBlockerTests(unittest.TestCase):
    def test_translates_domain_rule(self):
        rule, reason = MODULE.translate("||ads.example.com^$script,image")
        self.assertIsNone(reason)
        self.assertEqual(rule["action"], {"type": "block"})
        self.assertEqual(rule["trigger"]["resource-type"], ["image", "script"])
        self.assertIn("ads\\.example\\.com", rule["trigger"]["url-filter"])
        self.assertTrue(rule["trigger"]["url-filter"].endswith("[/:?#]"))
        self.assertNotIn("|", rule["trigger"]["url-filter"])

    def test_rejects_exception_without_approximation(self):
        rule, reason = MODULE.translate("@@||example.com^")
        self.assertIsNone(rule)
        self.assertEqual(reason, "exception")

    def test_rejects_excluded_domain_option(self):
        rule, reason = MODULE.translate("||tracker.example^$domain=example.com|~shop.example")
        self.assertIsNone(rule)
        self.assertEqual(reason, "excluded-domain-option")

    def test_template_repository_path_is_commit_pinned(self):
        calls = []
        original_fetch = MODULE.fetch
        MODULE.fetch = lambda url: calls.append(url) or "%include easylist:easylist/example.txt%"
        try:
            MODULE.expand_template(
                "https://raw.example/easylist.template",
                "https://github.com/easylist/easylist",
                "a" * 40,
            )
        finally:
            MODULE.fetch = original_fetch
        self.assertEqual(
            calls[1],
            f"https://raw.githubusercontent.com/easylist/easylist/{'a' * 40}/easylist/example.txt",
        )


if __name__ == "__main__":
    unittest.main()
