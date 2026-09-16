import json
import subprocess
import unittest
from unittest.mock import patch

from scripts import bump


class EarthdateBumpTests(unittest.TestCase):
    cask = "daegalus/tap/edge-kanban-gnome-extension"

    def livecheck(self, current="26U30.427", latest="26S11.500"):
        return json.dumps([{
            "cask": self.cask,
            "version": {
                "current": current,
                "latest": latest,
                "outdated": False,
                "newer_than_upstream": True,
            },
        }])

    @patch("scripts.bump.subprocess.run")
    @patch("scripts.bump.subprocess.check_output")
    def test_uses_earthdate_order_despite_livecheck_flags(self, output, run):
        output.side_effect = [self.livecheck(), "-1\n", "[]"]
        bump.bump_earthdate(self.cask, "earthdate", open_pr=True, no_fork=True)
        self.assertEqual(output.call_args_list[1].args[0], [
            "earthdate", "compare", "26U30.427", "26S11.500",
        ])
        run.assert_called_once_with([
            "brew", "bump-cask-pr", self.cask, "--version=26S11.500",
            "--no-browse", "--no-fork",
        ], check=True)

    @patch("scripts.bump.subprocess.run")
    @patch("scripts.bump.subprocess.check_output")
    def test_equal_and_older_releases_do_not_open_prs(self, output, run):
        for comparison in ("0\n", "1\n"):
            with self.subTest(comparison=comparison):
                output.side_effect = [self.livecheck(), comparison]
                bump.bump_earthdate(self.cask, "earthdate", open_pr=True)
        run.assert_not_called()

    @patch("scripts.bump.subprocess.run")
    @patch("scripts.bump.subprocess.check_output")
    def test_default_mode_is_read_only(self, output, run):
        output.side_effect = [self.livecheck(), "-1\n"]
        bump.bump_earthdate(self.cask, "earthdate")
        run.assert_not_called()

    @patch("scripts.bump.subprocess.run")
    @patch("scripts.bump.subprocess.check_output")
    def test_existing_update_prs_are_skipped(self, output, run):
        for state, title in [
            ("OPEN", "edge-kanban-gnome-extension 26S10.500"),
            ("CLOSED", "edge-kanban-gnome-extension 26S11.500"),
            ("MERGED", "edge-kanban-gnome-extension 26S11.500"),
        ]:
            with self.subTest(state=state):
                output.side_effect = [self.livecheck(), "-1\n", json.dumps([{
                    "state": state, "title": title, "url": "https://example.org/pr/1",
                }])]
                bump.bump_earthdate(self.cask, "earthdate", open_pr=True)
        run.assert_not_called()

    @patch("scripts.bump.subprocess.run")
    @patch("scripts.bump.subprocess.check_output")
    def test_old_closed_update_does_not_block_new_release(self, output, run):
        output.side_effect = [self.livecheck(), "-1\n", json.dumps([{
            "state": "MERGED", "title": "edge-kanban-gnome-extension 26U30.427",
            "url": "https://example.org/pr/1",
        }])]
        bump.bump_earthdate(self.cask, "earthdate", open_pr=True)
        self.assertEqual(run.call_count, 1)

    @patch("scripts.bump.subprocess.run")
    @patch("scripts.bump.subprocess.check_output")
    def test_comparison_errors_cannot_trigger_update(self, output, run):
        for result in ("unexpected\n", subprocess.CalledProcessError(2, "earthdate")):
            with self.subTest(result=result):
                output.side_effect = [self.livecheck(), result]
                with self.assertRaises((RuntimeError, subprocess.CalledProcessError)):
                    bump.bump_earthdate(self.cask, "earthdate", open_pr=True)
        run.assert_not_called()

    @patch("scripts.bump.subprocess.run")
    @patch("scripts.bump.subprocess.check_output")
    def test_livecheck_errors_cannot_trigger_update(self, output, run):
        output.return_value = json.dumps([{
            "cask": self.cask, "status": "error", "messages": ["API unavailable"],
        }])
        with self.assertRaisesRegex(RuntimeError, "API unavailable"):
            bump.bump_earthdate(self.cask, "earthdate", open_pr=True)
        run.assert_not_called()

    @patch("scripts.bump.subprocess.run")
    @patch("scripts.bump.subprocess.check_output")
    def test_failed_livecheck_command_preserves_diagnostics(self, output, run):
        output.side_effect = subprocess.CalledProcessError(
            1, "brew", output='[{"status": "error", "messages": ["API unavailable"]}]',
        )
        with self.assertRaisesRegex(RuntimeError, "API unavailable"):
            bump.bump_earthdate(self.cask, "earthdate", open_pr=True)
        run.assert_not_called()

    @patch("scripts.bump.bump_earthdate")
    @patch("scripts.bump.subprocess.run")
    def test_standard_updater_excludes_earthdate_casks(self, run, earthdate):
        bump.main(["--earthdate=/custom/earthdate", "--open-pr", "--no-fork"])
        args = run.call_args.args[0]
        self.assertNotIn(self.cask, args)
        self.assertIn("daegalus/tap/netbird-ui-linux", args)
        self.assertIn("--open-pr", args)
        self.assertIn("--no-fork", args)
        earthdate.assert_called_once_with(
            self.cask, "/custom/earthdate", open_pr=True, no_fork=True,
        )


if __name__ == "__main__":
    unittest.main()
