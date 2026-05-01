#!/usr/bin/env python3
"""Parse project YAML files used by Ansible and GitHub Actions."""

from __future__ import annotations

import pathlib
import sys

try:
    import yaml
except ImportError:
    print("PyYAML is required for YAML parse checks", file=sys.stderr)
    sys.exit(1)

paths = [
    pathlib.Path(".github/workflows/build-iso.yml"),
    pathlib.Path("bootstrap/install.yml"),
    pathlib.Path("bootstrap/requirements.yml"),
]
paths += sorted(pathlib.Path("bootstrap/vars").glob("*.yml"))
paths += sorted(pathlib.Path("bootstrap/roles").glob("*/tasks/main.yml"))
paths += sorted(pathlib.Path("bootstrap/roles").glob("*/handlers/main.yml"))

for path in paths:
    with path.open() as fh:
        yaml.safe_load(fh)
    print(f"OK {path}")
