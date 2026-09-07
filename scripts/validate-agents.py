#!/usr/bin/env python3
"""Validate standalone agent TOML with Python 3.11+ (no third-party parser)."""

import argparse
from pathlib import Path
import re
import sys


def main() -> int:
    try:
        import tomllib
    except ImportError:
        print("Agent schema validation requires Python 3.11+ (tomllib).", file=sys.stderr)
        return 2

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--agents-root", type=Path, required=True)
    args = parser.parse_args()
    files = sorted(args.agents_root.glob("*.toml"))
    if not files:
        print("No agent TOML files found.", file=sys.stderr)
        return 1
    for path in files:
        try:
            with path.open("rb") as source:
                agent = tomllib.load(source)
            for field in ("name", "description", "developer_instructions", "model"):
                if not isinstance(agent.get(field), str) or not agent[field].strip():
                    raise ValueError(f"Missing or invalid {field} in {path.name}")
            if agent["name"] != path.stem:
                raise ValueError(f"Agent name mismatch in {path.name}")
            if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", agent["name"]):
                raise ValueError(f"Invalid agent name in {path.name}")
        except (OSError, ValueError) as error:
            print(f"Invalid agent TOML {path.name}: {error}", file=sys.stderr)
            return 1
        print(f"VALID agent {path.stem}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
