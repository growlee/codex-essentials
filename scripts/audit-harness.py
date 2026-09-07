#!/usr/bin/env python3
"""Read-only inventory and drift report for a local Codex harness."""

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


SCHEMA_VERSION = 1
SKIP_NAMES = {".git", "__pycache__"}
FILE_ATTRIBUTE_REPARSE_POINT = 0x400
SAFE_CACHE_COMPONENT = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+-]*$")


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


def absolute_path(path: Path) -> Path:
    """Return an absolute path without resolving symlinks or junctions."""
    return Path(os.path.abspath(str(path.expanduser())))


def is_link_like(path: Path) -> bool:
    """Return whether an existing path is a symlink or Windows reparse point."""
    try:
        status = path.lstat()
    except FileNotFoundError:
        return False
    return stat.S_ISLNK(status.st_mode) or bool(
        getattr(status, "st_file_attributes", 0) & FILE_ATTRIBUTE_REPARSE_POINT
    )


def linked_path_issue(path: Path, leaf_kind: str) -> Optional[Dict[str, str]]:
    """Describe the first linked ancestor or leaf without resolving through it."""
    candidate = absolute_path(path)
    chain = list(reversed((candidate, *candidate.parents)))
    for item in chain:
        if is_link_like(item):
            return {
                "kind": leaf_kind if item == candidate else "linked-ancestor",
                "path": str(item),
            }
    return None


def scan_tree(root: Path) -> Tuple[Dict[str, str], List[Dict[str, str]]]:
    """Hash regular files in a bounded tree and report links without following them."""
    inventory: Dict[str, str] = {}
    unsafe: List[Dict[str, str]] = []

    def record_walk_error(error: OSError) -> None:
        location = getattr(error, "filename", None)
        display = "."
        if location:
            try:
                display = absolute_path(Path(location)).relative_to(root).as_posix()
            except ValueError:
                display = str(absolute_path(Path(location)))
        unsafe.append({"kind": "unreadable-entry", "path": display})

    for current, directories, files in os.walk(
        str(root), followlinks=False, onerror=record_walk_error
    ):
        current_path = Path(current)
        relative_dir = current_path.relative_to(root)
        if any(part in SKIP_NAMES for part in relative_dir.parts):
            directories[:] = []
            continue
        kept_directories: List[str] = []
        for name in sorted(directories):
            path = current_path / name
            relative = path.relative_to(root)
            if name in SKIP_NAMES:
                continue
            if is_link_like(path):
                unsafe.append({"kind": "linked-entry", "path": relative.as_posix()})
            else:
                kept_directories.append(name)
        directories[:] = kept_directories
        for name in sorted(files):
            path = current_path / name
            relative = path.relative_to(root)
            if any(part in SKIP_NAMES for part in relative.parts):
                continue
            key = relative.as_posix()
            if is_link_like(path):
                unsafe.append({"kind": "linked-file", "path": key})
            elif path.is_file():
                inventory[key] = "sha256:" + digest_file(path)
    return inventory, unsafe


def tree_inventory(root: Path) -> Dict[str, str]:
    """Hash a bounded tree without following symlinks."""
    root = absolute_path(root)
    issue = linked_path_issue(root, "linked-root")
    if issue or not root.exists():
        return {}
    inventory, unsafe = scan_tree(root)
    for item in unsafe:
        inventory[item["path"]] = "unsafe:" + item["kind"]
    return inventory


def compare_tree(source: Path, runtime: Path) -> Dict[str, Any]:
    source = absolute_path(source)
    runtime = absolute_path(runtime)
    source_issue = linked_path_issue(source, "linked-root")
    runtime_issue = linked_path_issue(runtime, "linked-root")
    if source_issue or runtime_issue:
        unsafe = []
        if source_issue:
            unsafe.append(dict(side="source", **source_issue))
        if runtime_issue:
            unsafe.append(dict(side="runtime", **runtime_issue))
        return {"status": "unsafe", "missing": [], "changed": [], "extra": [], "unsafe": unsafe}
    if not source.is_dir():
        return {
            "status": "unsafe",
            "missing": [],
            "changed": [],
            "extra": [],
            "unsafe": [{"side": "source", "kind": "not-directory", "path": str(source)}],
        }
    if not runtime.exists():
        return {"status": "missing", "missing": [], "changed": [], "extra": []}
    if not runtime.is_dir():
        return {
            "status": "unsafe",
            "missing": [],
            "changed": [],
            "extra": [],
            "unsafe": [{"side": "runtime", "kind": "not-directory", "path": str(runtime)}],
        }
    source_files, source_unsafe = scan_tree(source)
    runtime_files, runtime_unsafe = scan_tree(runtime)
    if source_unsafe or runtime_unsafe:
        unsafe = [dict(side="source", **item) for item in source_unsafe]
        unsafe.extend(dict(side="runtime", **item) for item in runtime_unsafe)
        return {"status": "unsafe", "missing": [], "changed": [], "extra": [], "unsafe": unsafe}
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
    source_issue = linked_path_issue(source, "linked-file")
    runtime_issue = linked_path_issue(runtime, "linked-file")
    if source_issue or runtime_issue:
        unsafe = []
        if source_issue:
            unsafe.append(dict(side="source", **source_issue))
        if runtime_issue:
            unsafe.append(dict(side="runtime", **runtime_issue))
        return {"status": "unsafe", "unsafe": unsafe}
    if not runtime.exists():
        return {"status": "missing"}
    if not runtime.is_file():
        return {"status": "unsafe", "unsafe": [{"side": "runtime", "kind": "not-regular-file", "path": str(runtime)}]}
    return {"status": "match" if digest_file(source) == digest_file(runtime) else "changed"}


def managed_skill_report(source_root: Path, runtime_root: Path) -> List[Dict[str, Any]]:
    skills_root = source_root / "plugins" / "codex-essentials" / "skills"
    runtime_skills = runtime_root / "skills"
    source_issue = linked_path_issue(skills_root, "linked-root")
    if source_issue:
        raise ValueError("unsafe Codex Essentials skill source: {}".format(source_issue))
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
    source_issue = linked_path_issue(agents_root, "linked-root")
    if source_issue:
        raise ValueError("unsafe Codex Essentials agent source: {}".format(source_issue))
    if not agents_root.is_dir():
        raise ValueError("Codex Essentials agent source is missing: {}".format(agents_root))
    return [
        dict(name=agent.stem, **compare_file(agent, runtime_agents / agent.name))
        for agent in sorted(agents_root.glob("*.toml"), key=lambda item: item.name)
    ]


def unmanaged_names(runtime_dir: Path, managed: Iterable[str], suffix: Optional[str] = None) -> List[str]:
    if linked_path_issue(runtime_dir, "linked-root"):
        return []
    if not runtime_dir.is_dir():
        return []
    managed_set = set(managed)
    names: List[str] = []
    for item in runtime_dir.iterdir():
        if item.name.startswith("."):
            continue
        if is_link_like(item):
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
    if (
        linked_path_issue(prompts_root, "linked-root")
        or linked_path_issue(agents_root, "linked-root")
        or not prompts_root.is_dir()
        or not agents_root.is_dir()
    ):
        return duplicates
    for prompt in sorted(prompts_root.glob("*.md"), key=lambda item: item.name):
        agent = agents_root / (prompt.stem + ".toml")
        if linked_path_issue(prompt, "linked-file") or linked_path_issue(agent, "linked-file"):
            continue
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


def managed_plugin_identity(source_root: Path) -> Tuple[str, str]:
    plugin_manifest = source_root / "plugins" / "codex-essentials" / ".codex-plugin" / "plugin.json"
    marketplace_manifest = source_root / ".agents" / "plugins" / "marketplace.json"
    for manifest in (plugin_manifest, marketplace_manifest):
        issue = linked_path_issue(manifest, "linked-file")
        if issue:
            raise ValueError("unsafe plugin registry source: {}".format(issue))
    plugin_payload = json.loads(plugin_manifest.read_text(encoding="utf-8"))
    marketplace_payload = json.loads(marketplace_manifest.read_text(encoding="utf-8"))
    plugin_name = plugin_payload.get("name")
    marketplace_name = marketplace_payload.get("name")
    if not isinstance(plugin_name, str) or not plugin_name:
        raise ValueError("plugin manifest name is missing")
    if not isinstance(marketplace_name, str) or not marketplace_name:
        raise ValueError("marketplace manifest name is missing")
    return marketplace_name, plugin_name


def managed_plugin_cache_report(
    payload: Dict[str, Any], source_root: Path, runtime_root: Path
) -> Dict[str, Any]:
    marketplace_name, plugin_name = managed_plugin_identity(source_root)
    matching = [
        item
        for item in payload.get("installed", [])
        if item.get("name") == plugin_name
        and item.get("marketplaceName") == marketplace_name
        and item.get("installed", True) is not False
    ]
    if not matching:
        return {
            "name": plugin_name,
            "marketplace": marketplace_name,
            "registryStatus": "missing",
            "cache": {"status": "not-applicable", "missing": [], "changed": [], "extra": []},
        }
    if len(matching) != 1:
        return {
            "name": plugin_name,
            "marketplace": marketplace_name,
            "registryStatus": "invalid",
            "cache": {"status": "not-checked", "missing": [], "changed": [], "extra": []},
        }
    item = matching[0]
    version = str(item.get("version", ""))
    components = (marketplace_name, plugin_name, version)
    if not all(SAFE_CACHE_COMPONENT.fullmatch(component) for component in components):
        return {
            "name": plugin_name,
            "marketplace": marketplace_name,
            "version": version,
            "registryStatus": "invalid",
            "cache": {"status": "not-checked", "missing": [], "changed": [], "extra": []},
        }
    source_plugin = source_root / "plugins" / "codex-essentials"
    cache = runtime_root / "plugins" / "cache" / marketplace_name / plugin_name / version
    return {
        "name": plugin_name,
        "marketplace": marketplace_name,
        "version": version,
        "registryStatus": "enabled" if bool(item.get("enabled", False)) else "disabled",
        "cache": compare_tree(source_plugin, cache),
    }


def plugin_report(skip: bool, source_root: Path, runtime_root: Path) -> Dict[str, Any]:
    if skip:
        return {"status": "skipped", "installed": [], "managedPackage": {"registryStatus": "skipped", "cache": {"status": "not-checked"}}}
    try:
        environment = os.environ.copy()
        environment["CODEX_HOME"] = str(runtime_root)
        result = subprocess.run(
            ["codex", "plugin", "list", "--json"],
            check=False,
            capture_output=True,
            env=environment,
            text=True,
            timeout=20,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as error:
        return {"status": "unavailable", "message": type(error).__name__, "installed": [], "managedPackage": {"registryStatus": "unknown", "cache": {"status": "not-checked"}}}
    if result.returncode != 0:
        return {"status": "error", "message": "codex plugin list failed", "installed": [], "managedPackage": {"registryStatus": "unknown", "cache": {"status": "not-checked"}}}
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {"status": "error", "message": "codex plugin list returned invalid JSON", "installed": [], "managedPackage": {"registryStatus": "unknown", "cache": {"status": "not-checked"}}}
    return {
        "status": "ok",
        "installed": parse_plugin_inventory(payload),
        "managedPackage": managed_plugin_cache_report(payload, source_root, runtime_root),
    }


def status_counts(items: Iterable[Dict[str, Any]]) -> Dict[str, int]:
    counts = {"match": 0, "changed": 0, "missing": 0, "unsafe": 0}
    for item in items:
        status = item["status"]
        counts[status] = counts.get(status, 0) + 1
    return counts


def build_report(source_root: Path, runtime_root: Path, skip_plugins: bool = False) -> Dict[str, Any]:
    source_root = absolute_path(source_root)
    runtime_root = absolute_path(runtime_root)
    skills = managed_skill_report(source_root, runtime_root)
    agents = managed_agent_report(source_root, runtime_root)
    managed_skill_names = [item["name"] for item in skills]
    managed_agent_names = [item["name"] for item in agents]
    plugins = plugin_report(skip_plugins, source_root, runtime_root)
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
            "managedPluginRegistry": plugins["managedPackage"]["registryStatus"],
            "managedPluginCache": plugins["managedPackage"]["cache"]["status"],
        },
    }


def render_text(report: Dict[str, Any]) -> str:
    summary = report["summary"]
    lines = [
        "Codex harness audit (read-only)",
        "source: {}".format(report["sourceRoot"]),
        "runtime: {}".format(report["runtimeRoot"]),
        "skills (direct mirrors): {match} match, {changed} changed, {missing} missing, {unsafe} unsafe".format(**summary["skills"]),
        "agents (direct mirrors): {match} match, {changed} changed, {missing} missing, {unsafe} unsafe".format(**summary["agents"]),
        "duplicate prompts: {}".format(summary["promptDuplicates"]),
        "plugins: {} installed, {} disabled ({})".format(
            summary["pluginsInstalled"], summary["pluginsDisabled"], report["plugins"]["status"]
        ),
        "managed plugin: {}; cache {}".format(
            summary["managedPluginRegistry"], summary["managedPluginCache"]
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
        help="Exit 1 when a directly mirrored managed skill or agent is changed, missing, or unsafe; plugin cache status is reported separately.",
    )
    return parser.parse_args(argv)


def direct_mirrors_have_drift(report: Dict[str, Any]) -> bool:
    """Return strict-mode status for direct mirrors only, never plugin caches."""
    items = report["managedMirrors"]["skills"] + report["managedMirrors"]["agents"]
    return any(item["status"] != "match" for item in items)


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
    if args.strict_mirrors and direct_mirrors_have_drift(report):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
