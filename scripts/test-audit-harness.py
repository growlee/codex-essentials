#!/usr/bin/env python3
"""Tests for the read-only Codex harness auditor."""

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


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
    def add_plugin_manifests(self, source: Path) -> None:
        write(
            source / "plugins/codex-essentials/.codex-plugin/plugin.json",
            json.dumps({"name": "codex-essentials", "version": "1.2.3"}),
        )
        write(
            source / ".agents/plugins/marketplace.json",
            json.dumps({"name": "codex-essentials"}),
        )

    def plugin_payload(self, enabled: bool = True, version: str = "1.2.3") -> dict:
        return {
            "installed": [
                {
                    "pluginId": "codex-essentials@codex-essentials",
                    "name": "codex-essentials",
                    "marketplaceName": "codex-essentials",
                    "version": version,
                    "enabled": enabled,
                    "installed": True,
                    "source": {"path": "C:/private/plugin", "token": "never-report-me"},
                }
            ]
        }

    def populate_plugin_cache(self, source: Path, runtime: Path, version: str = "1.2.3") -> Path:
        cache = runtime / "plugins/cache/codex-essentials/codex-essentials" / version
        shutil.copytree(source / "plugins/codex-essentials", cache)
        return cache

    def build_fixture(self, root: Path) -> tuple:
        # System temp paths can have OS-owned aliases (for example /var on macOS).
        # Start fixtures from a canonical parent; links under test are added later.
        root = root.resolve()
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
            temporary_root = Path(temporary).resolve()
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

    def test_full_plugin_cache_is_separate_from_missing_direct_skills(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source, runtime = self.build_fixture(Path(temporary))
            self.add_plugin_manifests(source)
            shutil.rmtree(runtime / "skills")
            self.populate_plugin_cache(source, runtime)

            direct = AUDIT.managed_skill_report(source, runtime)
            managed = AUDIT.managed_plugin_cache_report(
                self.plugin_payload(), source, runtime
            )

            self.assertTrue(all(item["status"] == "missing" for item in direct))
            self.assertEqual(managed["registryStatus"], "enabled")
            self.assertEqual(managed["cache"]["status"], "match")

    def test_plugin_registry_and_cache_states_are_independent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source, runtime = self.build_fixture(Path(temporary))
            self.add_plugin_manifests(source)

            disabled_cache = self.populate_plugin_cache(source, runtime)
            disabled = AUDIT.managed_plugin_cache_report(
                self.plugin_payload(enabled=False), source, runtime
            )
            self.assertEqual(disabled["registryStatus"], "disabled")
            self.assertEqual(disabled["cache"]["status"], "match")

            shutil.rmtree(disabled_cache)
            missing_cache = AUDIT.managed_plugin_cache_report(
                self.plugin_payload(), source, runtime
            )
            self.assertEqual(missing_cache["registryStatus"], "enabled")
            self.assertEqual(missing_cache["cache"]["status"], "missing")

            drift_cache = self.populate_plugin_cache(source, runtime)
            write(drift_cache / "skills/analyze/SKILL.md", "drift\n")
            drift = AUDIT.managed_plugin_cache_report(
                self.plugin_payload(), source, runtime
            )
            self.assertEqual(drift["registryStatus"], "enabled")
            self.assertEqual(drift["cache"]["status"], "changed")

            absent = AUDIT.managed_plugin_cache_report(
                {"installed": []}, source, runtime
            )
            self.assertEqual(absent["registryStatus"], "missing")
            self.assertEqual(absent["cache"]["status"], "not-applicable")

    def test_plugin_command_is_bound_to_requested_runtime_root(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source, runtime = self.build_fixture(Path(temporary))
            self.add_plugin_manifests(source)
            self.populate_plugin_cache(source, runtime)
            completed = subprocess.CompletedProcess(
                ["codex", "plugin", "list", "--json"],
                0,
                stdout=json.dumps(self.plugin_payload()),
                stderr="",
            )
            with mock.patch.object(AUDIT.subprocess, "run", return_value=completed) as run:
                report = AUDIT.plugin_report(False, source, runtime)

            self.assertEqual(report["managedPackage"]["cache"]["status"], "match")
            self.assertEqual(run.call_args.kwargs["env"]["CODEX_HOME"], str(runtime))

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

    def test_linked_runtime_root_and_agent_file_are_unsafe(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            source, runtime = self.build_fixture(root)
            linked_runtime = root / "runtime-link"
            try:
                os.symlink(runtime, linked_runtime, target_is_directory=True)
            except OSError as error:
                self.skipTest("directory symlinks unavailable: {}".format(error))

            linked_report = AUDIT.build_report(source, linked_runtime, skip_plugins=True)
            self.assertTrue(
                all(
                    item["status"] == "unsafe"
                    for item in linked_report["managedMirrors"]["skills"]
                    + linked_report["managedMirrors"]["agents"]
                )
            )
            kinds = {
                issue["kind"]
                for item in linked_report["managedMirrors"]["agents"]
                for issue in item["unsafe"]
            }
            self.assertEqual(kinds, {"linked-ancestor"})

            linked_runtime.unlink()
            analyze = runtime / "skills/analyze"
            shutil.rmtree(analyze)
            skill_target = root / "linked-skill-target"
            write(skill_target / "SKILL.md", "same\n")
            try:
                os.symlink(skill_target, analyze, target_is_directory=True)
            except OSError as error:
                self.skipTest("directory symlinks unavailable: {}".format(error))
            skill = next(
                item
                for item in AUDIT.managed_skill_report(source, runtime)
                if item["name"] == "analyze"
            )
            self.assertEqual(skill["status"], "unsafe")
            self.assertEqual(skill["unsafe"][0]["kind"], "linked-root")

            analyst = runtime / "agents/analyst.toml"
            analyst.unlink()
            target = root / "linked-agent-target.toml"
            write(target, 'developer_instructions = """Same"""\n')
            try:
                os.symlink(target, analyst)
            except OSError as error:
                self.skipTest("file symlinks unavailable: {}".format(error))
            agent = next(
                item
                for item in AUDIT.managed_agent_report(source, runtime)
                if item["name"] == "analyst"
            )
            self.assertEqual(agent["status"], "unsafe")
            self.assertEqual(agent["unsafe"][0]["kind"], "linked-file")

    @unittest.skipUnless(os.name == "nt", "Windows junction behavior")
    def test_windows_junction_tree_root_is_unsafe(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            source = root / "source-skill"
            target = root / "runtime-target"
            junction = root / "runtime-junction"
            write(source / "SKILL.md", "same\n")
            write(target / "SKILL.md", "same\n")
            created = subprocess.run(
                ["cmd.exe", "/d", "/c", "mklink", "/J", str(junction), str(target)],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(created.returncode, 0, created.stderr or created.stdout)
            try:
                comparison = AUDIT.compare_tree(source, junction)
                self.assertEqual(comparison["status"], "unsafe")
                self.assertEqual(comparison["unsafe"][0]["kind"], "linked-root")
            finally:
                if junction.exists() or AUDIT.is_link_like(junction):
                    os.rmdir(junction)

    def test_tree_comparison_fails_closed_for_wrong_type_and_walk_error(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            source = root / "source"
            runtime = root / "runtime"
            write(source / "file.txt", "same\n")
            write(runtime, "not a directory\n")
            wrong_type = AUDIT.compare_tree(source, runtime)
            self.assertEqual(wrong_type["status"], "unsafe")
            self.assertEqual(wrong_type["unsafe"][0]["kind"], "not-directory")

            runtime.unlink()
            write(runtime / "file.txt", "same\n")

            def unreadable_walk(path, followlinks, onerror):
                onerror(PermissionError(13, "denied", str(Path(path) / "blocked")))
                return iter(())

            with mock.patch.object(AUDIT.os, "walk", side_effect=unreadable_walk):
                unreadable = AUDIT.compare_tree(source, runtime)
            self.assertEqual(unreadable["status"], "unsafe")
            self.assertEqual(unreadable["unsafe"][0]["kind"], "unreadable-entry")

    def test_managed_plugin_report_does_not_expose_registry_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source, runtime = self.build_fixture(Path(temporary))
            self.add_plugin_manifests(source)
            self.populate_plugin_cache(source, runtime)
            report = AUDIT.managed_plugin_cache_report(
                self.plugin_payload(), source, runtime
            )
            serialized = json.dumps(report)
            self.assertNotIn("never-report-me", serialized)
            self.assertNotIn("C:/private/plugin", serialized)

    def test_strict_mirrors_ignores_plugin_cache_status(self) -> None:
        report = {
            "managedMirrors": {
                "skills": [{"name": "analyze", "status": "match"}],
                "agents": [{"name": "analyst", "status": "match"}],
            },
            "plugins": {"managedPackage": {"cache": {"status": "changed"}}},
        }
        self.assertFalse(AUDIT.direct_mirrors_have_drift(report))
        report["managedMirrors"]["skills"][0]["status"] = "missing"
        self.assertTrue(AUDIT.direct_mirrors_have_drift(report))

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
            self.assertIn("skills (direct mirrors)", AUDIT.render_text(json.loads(result.stdout)))

            strict = subprocess.run(command + ["--strict-mirrors"], check=False, capture_output=True, text=True)
            self.assertEqual(strict.returncode, 1, strict.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
