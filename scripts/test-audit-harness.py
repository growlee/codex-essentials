#!/usr/bin/env python3
"""Tests for the read-only Codex harness auditor."""

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("audit-harness.py")
SPEC = importlib.util.spec_from_file_location("audit_harness", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Unable to load audit-harness.py")
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


class AuditHarnessTests(unittest.TestCase):
    def build_fixture(self, root: Path) -> tuple:
        source = root / "source"
        runtime = root / "runtime"
        write(source / "plugins/codex-essentials/skills/analyze/SKILL.md", "same\n")
        write(source / "plugins/codex-essentials/skills/diagnose/SKILL.md", "source\n")
        write(source / "agents/analyst.toml", 'developer_instructions = """Same"""\n')
        write(source / "agents/verifier.toml", 'developer_instructions = """Verify"""\n')
        write(runtime / "skills/analyze/SKILL.md", "same\n")
        write(runtime / "skills/diagnose/SKILL.md", "runtime\n")
        write(runtime / "skills/local-only/SKILL.md", "local\n")
        write(runtime / "skills/.system/builtin/SKILL.md", "system\n")
        write(runtime / "agents/analyst.toml", 'developer_instructions = """Same"""\n')
        write(runtime / "agents/custom.toml", 'developer_instructions = """Custom"""\n')
        write(runtime / "prompts/analyst.md", "---\ndescription: duplicate\n---\nSame\n")
        return source, runtime

    def test_report_detects_drift_inventory_and_duplicate_prompt(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            temporary_root = Path(temporary)
            source, runtime = self.build_fixture(temporary_root)
            before = AUDIT.tree_inventory(temporary_root)
            report = AUDIT.build_report(source, runtime, skip_plugins=True)
            after = AUDIT.tree_inventory(temporary_root)

            skills = {item["name"]: item["status"] for item in report["managedMirrors"]["skills"]}
            agents = {item["name"]: item["status"] for item in report["managedMirrors"]["agents"]}
            self.assertEqual(skills, {"analyze": "match", "diagnose": "changed"})
            self.assertEqual(agents, {"analyst": "match", "verifier": "missing"})
            self.assertEqual(report["unmanaged"]["skills"], ["local-only"])
            self.assertEqual(report["unmanaged"]["agents"], ["custom"])
            self.assertEqual(report["promptDuplicates"], ["analyst.md"])
            self.assertEqual(report["plugins"]["status"], "skipped")
            self.assertEqual(before, after, "audit changed its source or runtime fixture")

    def test_plugin_parser_drops_paths_and_other_runtime_metadata(self) -> None:
        payload = {
            "installed": [
                {
                    "pluginId": "sample@personal",
                    "version": "1.2.3",
                    "enabled": False,
                    "source": {"path": "C:/private/plugin"},
                    "marketplaceSource": {"source": "https://example.invalid/private"},
                }
            ]
        }
        self.assertEqual(
            AUDIT.parse_plugin_inventory(payload),
            [{"id": "sample@personal", "version": "1.2.3", "enabled": False}],
        )

    def test_cli_json_and_strict_exit_are_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source, runtime = self.build_fixture(Path(temporary))
            command = [
                sys.executable,
                str(SCRIPT),
                "--source-root",
                str(source),
                "--runtime-root",
                str(runtime),
                "--skip-plugins",
                "--json",
            ]
            result = subprocess.run(command, check=False, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)["schemaVersion"], 1)

            strict = subprocess.run(command + ["--strict-mirrors"], check=False, capture_output=True, text=True)
            self.assertEqual(strict.returncode, 1, strict.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
