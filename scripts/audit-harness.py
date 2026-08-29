#!/usr/bin/env python3
"""Read-only inventory and drift report for a local Codex harness."""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


SCHEMA_VERSION = 1
SKIP_NAMES = {".git", "__pycache__"}


def default_runtime_root() -> Path:
    configured = os.environ.get("CODEX_HOME")
    return Path(configured).expanduser() if configured else Path.home() / ".codex"


def default_source_root() -> Path:
    return Path(__file__).resolve().parent.parent


def digest_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tree_inventory(root: Path) -> Dict[str, str]:
    """Hash a bounded tree without following symlinks."""
    inventory: Dict[str, str] = {}
    if not root.exists():
        return inventory
    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix()):
        relative = path.relative_to(root)
        if any(part in SKIP_NAMES for part in relative.parts):
            continue
        key = relative.as_posix()
        if path.is_symlink():
            inventory[key] = "symlink:" + os.readlink(str(path))
        elif path.is_file():
            inventory[key] = "sha256:" + digest_file(path)
    return inventory


def compare_tree(source: Path, runtime: Path) -> Dict[str, Any]:
    if not runtime.exists():
        return {"status": "missing", "missing": [], "changed": [], "extra": []}
    source_files = tree_inventory(source)
    runtime_files = tree_inventory(runtime)
    missing = sorted(set(source_files) - set(runtime_files))
    extra = sorted(set(runtime_files) - set(source_files))
    changed = sorted(
        name
        for name in set(source_files) & set(runtime_files)
        if source_files[name] != runtime_files[name]
    )
    status = "match" if not missing and not extra and not changed else "changed"
    return {"status": status, "missing": missing, "changed": changed, "extra": extra}


def compare_file(source: Path, runtime: Path) -> Dict[str, Any]:
    if not runtime.exists():
        return {"status": "missing"}
    return {"status": "match" if digest_file(source) == digest_file(runtime) else "changed"}


def managed_skill_report(source_root: Path, runtime_root: Path) -> List[Dict[str, Any]]:
    skills_root = source_root / "plugins" / "codex-essentials" / "skills"
    runtime_skills = runtime_root / "skills"
    if not skills_root.is_dir():
        raise ValueError("Codex Essentials skill source is missing: {}".format(skills_root))
    return [
        dict(name=skill.name, **compare_tree(skill, runtime_skills / skill.name))
        for skill in sorted(skills_root.iterdir(), key=lambda item: item.name)
        if skill.is_dir()
    ]


def managed_agent_report(source_root: Path, runtime_root: Path) -> List[Dict[str, Any]]:
    agents_root = source_root / "agents"
    runtime_agents = runtime_root / "agents"
    if not agents_root.is_dir():
        raise ValueError("Codex Essentials agent source is missing: {}".format(agents_root))
    return [
        dict(name=agent.stem, **compare_file(agent, runtime_agents / agent.name))
        for agent in sorted(agents_root.glob("*.toml"), key=lambda item: item.name)
    ]


def unmanaged_names(runtime_dir: Path, managed: Iterable[str], suffix: Optional[str] = None) -> List[str]:
    if not runtime_dir.is_dir():
        return []
    managed_set = set(managed)
    names: List[str] = []
    for item in runtime_dir.iterdir():
        if item.name.startswith("."):
            continue
        if suffix is None and item.is_dir() and item.name not in managed_set:
            names.append(item.name)
        elif suffix and item.is_file() and item.suffix == suffix and item.stem not in managed_set:
            names.append(item.stem)
    return sorted(names)


def prompt_body(text: str) -> str:
    return re.sub(r"^---\s*\r?\n.*?\r?\n---\s*\r?\n", "", text, flags=re.DOTALL).strip()


def agent_instructions(text: str) -> Optional[str]:
    match = re.search(r'developer_instructions\s*=\s*"""(.*?)"""', text, flags=re.DOTALL)
    return match.group(1).strip() if match else None


def duplicate_prompts(runtime_root: Path) -> List[str]:
    prompts_root = runtime_root / "prompts"
    agents_root = runtime_root / "agents"
    duplicates: List[str] = []
    if not prompts_root.is_dir() or not agents_root.is_dir():
        return duplicates
    for prompt in sorted(prompts_root.glob("*.md"), key=lambda item: item.name):
        agent = agents_root / (prompt.stem + ".toml")
        if not agent.is_file():
            continue
        prompt_text = prompt.read_text(encoding="utf-8")
        instructions = agent_instructions(agent.read_text(encoding="utf-8"))
        if instructions is not None and prompt_body(prompt_text) == instructions:
            duplicates.append(prompt.name)
    return duplicates


def parse_plugin_inventory(payload: Dict[str, Any]) -> List[Dict[str, Any]]:
    plugins: List[Dict[str, Any]] = []
    for item in payload.get("installed", []):
        plugins.append(
            {
                "id": str(item.get("pluginId", "")),
                "version": str(item.get("version", "")),
                "enabled": bool(item.get("enabled", False)),
            }
        )
    return sorted(plugins, key=lambda item: item["id"])


def plugin_report(skip: bool) -> Dict[str, Any]:
    if skip:
        return {"status": "skipped", "installed": []}
    try:
        result = subprocess.run(
            ["codex", "plugin", "list", "--json"],
            check=False,
            capture_output=True,
            text=True,
            timeout=20,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as error:
        return {"status": "unavailable", "message": type(error).__name__, "installed": []}
    if result.returncode != 0:
        return {"status": "error", "message": "codex plugin list failed", "installed": []}
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {"status": "error", "message": "codex plugin list returned invalid JSON", "installed": []}
    return {"status": "ok", "installed": parse_plugin_inventory(payload)}


def status_counts(items: Iterable[Dict[str, Any]]) -> Dict[str, int]:
    counts = {"match": 0, "changed": 0, "missing": 0}
    for item in items:
        status = item["status"]
        counts[status] = counts.get(status, 0) + 1
    return counts


def build_report(source_root: Path, runtime_root: Path, skip_plugins: bool = False) -> Dict[str, Any]:
    source_root = source_root.expanduser().resolve()
    runtime_root = runtime_root.expanduser().resolve()
    skills = managed_skill_report(source_root, runtime_root)
    agents = managed_agent_report(source_root, runtime_root)
    managed_skill_names = [item["name"] for item in skills]
    managed_agent_names = [item["name"] for item in agents]
    plugins = plugin_report(skip_plugins)
    duplicates = duplicate_prompts(runtime_root)
    installed_plugins = plugins.get("installed", [])
    return {
        "schemaVersion": SCHEMA_VERSION,
        "sourceRoot": str(source_root),
        "runtimeRoot": str(runtime_root),
        "scope": ["skills", "agents", "prompts", "codex plugin list --json"],
        "managedMirrors": {"skills": skills, "agents": agents},
        "unmanaged": {
            "skills": unmanaged_names(runtime_root / "skills", managed_skill_names),
            "agents": unmanaged_names(runtime_root / "agents", managed_agent_names, ".toml"),
        },
        "promptDuplicates": duplicates,
        "plugins": plugins,
        "summary": {
            "skills": status_counts(skills),
            "agents": status_counts(agents),
            "promptDuplicates": len(duplicates),
            "pluginsInstalled": len(installed_plugins),
            "pluginsDisabled": sum(1 for item in installed_plugins if not item["enabled"]),
        },
    }


def render_text(report: Dict[str, Any]) -> str:
    summary = report["summary"]
    lines = [
        "Codex harness audit (read-only)",
        "source: {}".format(report["sourceRoot"]),
        "runtime: {}".format(report["runtimeRoot"]),
        "skills: {match} match, {changed} changed, {missing} missing".format(**summary["skills"]),
        "agents: {match} match, {changed} changed, {missing} missing".format(**summary["agents"]),
        "duplicate prompts: {}".format(summary["promptDuplicates"]),
        "plugins: {} installed, {} disabled ({})".format(
            summary["pluginsInstalled"], summary["pluginsDisabled"], report["plugins"]["status"]
        ),
    ]
    for kind in ("skills", "agents"):
        for item in report["managedMirrors"][kind]:
            if item["status"] != "match":
                lines.append("{} {}: {}".format(kind[:-1], item["name"], item["status"]))
    if report["promptDuplicates"]:
        lines.append("exact prompt duplicates: {}".format(", ".join(report["promptDuplicates"])))
    if report["unmanaged"]["skills"]:
        lines.append("unmanaged skills (inventory only): {}".format(", ".join(report["unmanaged"]["skills"])))
    if report["unmanaged"]["agents"]:
        lines.append("unmanaged agents (inventory only): {}".format(", ".join(report["unmanaged"]["agents"])))
    return "\n".join(lines)


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=default_source_root())
    parser.add_argument("--runtime-root", type=Path, default=default_runtime_root())
    parser.add_argument("--json", action="store_true", dest="as_json")
    parser.add_argument("--skip-plugins", action="store_true")
    parser.add_argument(
        "--strict-mirrors",
        action="store_true",
        help="Exit 1 when a managed skill or agent mirror is changed or missing.",
    )
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    try:
        report = build_report(args.source_root, args.runtime_root, args.skip_plugins)
    except (OSError, ValueError) as error:
        print("ERROR {}".format(error), file=sys.stderr)
        return 2
    if args.as_json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print(render_text(report))
    if args.strict_mirrors:
        items = report["managedMirrors"]["skills"] + report["managedMirrors"]["agents"]
        if any(item["status"] != "match" for item in items):
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
