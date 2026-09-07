#!/usr/bin/env python3
"""Portable integration tests for install-agents.py."""

from __future__ import annotations

from pathlib import Path
import os
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
            runtime_root = Path(root).resolve() / "runtime"

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
        for runtime_root in (REPO_ROOT, REPO_ROOT / "runtime-test", REPO_ROOT.parent):
            with self.subTest(runtime_root=runtime_root):
                result = self.run_installer(runtime_root, "apply")
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertIn(
                    "runtime root overlaps the authoring repository", result.stderr
                )

    @unittest.skipUnless(os.name == "nt", "Windows junction behavior")
    def test_rejects_junction_destination_without_writing_outside(self) -> None:
        with tempfile.TemporaryDirectory(prefix="codex-essentials-junction-") as root:
            base = Path(root).resolve()
            runtime_root = base / "runtime"
            outside = base / "outside"
            runtime_root.mkdir()
            outside.mkdir()
            sentinel = outside / "sentinel.txt"
            sentinel.write_text("unchanged", encoding="utf-8")
            junction = runtime_root / "agents"
            created = subprocess.run(
                ["cmd", "/c", "mklink", "/J", str(junction), str(outside)],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(created.returncode, 0, created.stdout + created.stderr)

            result = self.run_installer(runtime_root, "apply")
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertIn("reparse point", result.stderr)
            self.assertEqual(sentinel.read_text(encoding="utf-8"), "unchanged")
            self.assertEqual(list(outside.iterdir()), [sentinel])

    def test_backup_collision_is_preflighted_before_missing_files_are_written(self) -> None:
        with tempfile.TemporaryDirectory(prefix="codex-essentials-preflight-") as root:
            runtime_root = Path(root).resolve() / "runtime"
            agents_root = runtime_root / "agents"
            agents_root.mkdir(parents=True)
            analyst = agents_root / "analyst.toml"
            analyst.write_text("intentional drift\n", encoding="utf-8")
            backup = analyst.with_suffix(".toml.bak")
            backup.write_text("existing backup\n", encoding="utf-8")

            result = self.run_installer(
                runtime_root, "apply", "--replace-changed"
            )
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertIn("refusing to overwrite existing backup", result.stderr)
            self.assertEqual(analyst.read_text(encoding="utf-8"), "intentional drift\n")
            self.assertEqual(backup.read_text(encoding="utf-8"), "existing backup\n")
            self.assertFalse(
                (agents_root / "architect.toml").exists(),
                "Preflight failure must happen before any missing agent is installed",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
