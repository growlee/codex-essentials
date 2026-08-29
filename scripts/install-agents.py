#!/usr/bin/env python3
"""Verify or install the manifest-listed Codex native agents."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
from typing import Optional


REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = REPO_ROOT / "package-manifest.json"
AGENT_NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify or install Codex Essentials native agents."
    )
    parser.add_argument(
        "--mode",
        choices=("verify", "apply"),
        default="verify",
        help="verify reports drift; apply copies only manifest-listed agents",
    )
    parser.add_argument(
        "--runtime-root",
        type=Path,
        help="Codex home; defaults to CODEX_HOME or ~/.codex",
    )
    parser.add_argument(
        "--replace-changed",
        action="store_true",
        help="replace changed managed agents after preserving each original as .bak",
    )
    return parser.parse_args()


def load_agent_names() -> list[str]:
    payload = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    agents = payload.get("agents")
    if not isinstance(agents, list) or not agents:
        raise ValueError("package-manifest.json must contain a non-empty agents list")
    if len(agents) != len(set(agents)):
        raise ValueError("package-manifest.json contains duplicate agent names")
    for name in agents:
        if not isinstance(name, str) or not AGENT_NAME_RE.fullmatch(name):
            raise ValueError(f"invalid agent name in package manifest: {name!r}")
        if not (REPO_ROOT / "agents" / f"{name}.toml").is_file():
            raise ValueError(f"missing agent source: agents/{name}.toml")
    return agents


def resolve_runtime_root(requested: Optional[Path]) -> Path:
    raw = requested
    if raw is None:
        configured = os.environ.get("CODEX_HOME")
        raw = Path(configured) if configured else Path.home() / ".codex"

    runtime_root = raw.expanduser().resolve()
    filesystem_root = Path(runtime_root.anchor)
    if runtime_root == filesystem_root:
        raise ValueError(f"unsafe runtime root: {runtime_root}")

    repo_root = REPO_ROOT.resolve()
    if (
        runtime_root == repo_root
        or runtime_root in repo_root.parents
        or repo_root in runtime_root.parents
    ):
        raise ValueError(f"runtime root overlaps the authoring repository: {runtime_root}")
    return runtime_root


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def find_drift(agent_names: list[str], runtime_root: Path) -> list[str]:
    drift: list[str] = []
    destination_root = runtime_root / "agents"
    if destination_root.is_symlink():
        raise ValueError(f"agent destination must not be a symlink: {destination_root}")
    for name in agent_names:
        source = REPO_ROOT / "agents" / f"{name}.toml"
        destination = destination_root / f"{name}.toml"
        if destination.is_symlink():
            raise ValueError(f"agent destination must not be a symlink: {destination}")
        if not destination.is_file():
            drift.append(f"MISSING agent/{name}.toml")
        elif digest(source) != digest(destination):
            drift.append(f"CHANGED agent/{name}.toml")
    return drift


def atomic_copy(source: Path, destination: Path) -> None:
    temporary = destination.with_name(
        f".{destination.name}.codex-essentials-{os.getpid()}.tmp"
    )
    if temporary.exists() or temporary.is_symlink():
        raise ValueError(f"temporary destination already exists: {temporary}")
    try:
        shutil.copy2(source, temporary)
        os.replace(temporary, destination)
    finally:
        if temporary.exists():
            temporary.unlink()


def copy_agents(
    agent_names: list[str], runtime_root: Path, replace_changed: bool
) -> None:
    destination_root = runtime_root / "agents"
    destination_root.mkdir(parents=True, exist_ok=True)
    for name in agent_names:
        source = REPO_ROOT / "agents" / f"{name}.toml"
        destination = destination_root / f"{name}.toml"
        if not destination.exists():
            atomic_copy(source, destination)
            continue
        if digest(source) == digest(destination) or not replace_changed:
            continue

        backup = destination.with_suffix(destination.suffix + ".bak")
        if backup.exists() or backup.is_symlink():
            raise ValueError(f"refusing to overwrite existing backup: {backup}")
        shutil.copy2(destination, backup)
        atomic_copy(source, destination)


def main() -> int:
    try:
        args = parse_args()
        agent_names = load_agent_names()
        runtime_root = resolve_runtime_root(args.runtime_root)
        drift = find_drift(agent_names, runtime_root)
        if not drift:
            print(f"VERIFIED runtime mirrors: {len(agent_names)} agents")
            return 0

        for item in drift:
            print(f"DRIFT {item}")
        if args.mode == "verify":
            print(f"Runtime drift detected: {len(drift)} difference(s)", file=sys.stderr)
            return 1

        copy_agents(agent_names, runtime_root, args.replace_changed)
        remaining = find_drift(agent_names, runtime_root)
        if remaining:
            for item in remaining:
                print(f"DRIFT {item}")
            if not args.replace_changed and any(
                item.startswith("CHANGED ") for item in remaining
            ):
                print(
                    "Changed agents were preserved; inspect them and rerun with "
                    "--replace-changed to create .bak files and replace them.",
                    file=sys.stderr,
                )
            print(
                f"Runtime drift detected after apply: {len(remaining)} difference(s)",
                file=sys.stderr,
            )
            return 1
        print(f"SYNCHRONIZED runtime mirrors: {len(agent_names)} agents")
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
