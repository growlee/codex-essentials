#!/usr/bin/env python3
"""Portable integration tests for install-agents.py."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parent.parent
INSTALLER = REPO_ROOT / "scripts" / "install-agents.py"


class InstallAgentsTests(unittest.TestCase):
    def run_installer(
        self, runtime_root: Path, mode: str, *extra_args: str
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(INSTALLER),
                "--mode",
                mode,
                "--runtime-root",
                str(runtime_root),
                *extra_args,
            ],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

    def test_verify_apply_repair_and_no_prune(self) -> None:
        with tempfile.TemporaryDirectory(prefix="codex-essentials-agents-") as root:
            runtime_root = Path(root) / "runtime"

            missing = self.run_installer(runtime_root, "verify")
            self.assertEqual(missing.returncode, 1, missing.stdout + missing.stderr)
            self.assertIn("DRIFT MISSING agent/analyst.toml", missing.stdout)

            applied = self.run_installer(runtime_root, "apply")
            self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
            self.assertIn("SYNCHRONIZED runtime mirrors: 16 agents", applied.stdout)
            self.assertFalse((runtime_root / "skills").exists())

            verified = self.run_installer(runtime_root, "verify")
            self.assertEqual(verified.returncode, 0, verified.stdout + verified.stderr)
            self.assertIn("VERIFIED runtime mirrors: 16 agents", verified.stdout)

            analyst = runtime_root / "agents" / "analyst.toml"
            analyst.write_text(
                analyst.read_text(encoding="utf-8") + "\n# intentional drift\n",
                encoding="utf-8",
            )
            extra = runtime_root / "agents" / "runtime-only.toml"
            extra.write_text("unmanaged = true\n", encoding="utf-8")

            changed = self.run_installer(runtime_root, "verify")
            self.assertEqual(changed.returncode, 1, changed.stdout + changed.stderr)
            self.assertIn("DRIFT CHANGED agent/analyst.toml", changed.stdout)

            preserved = self.run_installer(runtime_root, "apply")
            self.assertEqual(preserved.returncode, 1, preserved.stdout + preserved.stderr)
            self.assertIn("Changed agents were preserved", preserved.stderr)
            self.assertIn("intentional drift", analyst.read_text(encoding="utf-8"))
            self.assertFalse(analyst.with_suffix(".toml.bak").exists())
            self.assertTrue(extra.is_file(), "Apply must not prune unmanaged runtime files")

            repaired = self.run_installer(
                runtime_root, "apply", "--replace-changed"
            )
            self.assertEqual(repaired.returncode, 0, repaired.stdout + repaired.stderr)
            backup = analyst.with_suffix(".toml.bak")
            self.assertTrue(backup.is_file(), "Replacement must preserve a backup")
            self.assertIn("intentional drift", backup.read_text(encoding="utf-8"))
            self.assertTrue(extra.is_file(), "Apply must not prune unmanaged runtime files")

    def test_rejects_repository_overlap(self) -> None:
        result = self.run_installer(REPO_ROOT, "apply")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("runtime root overlaps the authoring repository", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
