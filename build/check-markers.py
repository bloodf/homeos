#!/usr/bin/env python3
"""Fail if project files contain disallowed inline marker or attribution strings."""

from __future__ import annotations

import subprocess
import sys

terms = [
    "TO" + "DO",
    "FIX" + "ME",
    "XX" + "X",
    "Co-Authored" + "-By:",
    "Generated" + " with",
    "Generated" + " by",
    "AI-" + "generated",
    "AI " + "generated",
    "\N{ROBOT FACE}",
]
pattern = "|".join(terms)
result = subprocess.run(
    [
        "git",
        "grep",
        "--untracked",
        "-n",
        "-E",
        pattern,
        "--",
        ":!ROADMAP-TO-0.9.md",
        ":!.pi/**",
        ":!.omc/**",
    ],
    text=True,
    capture_output=True,
)
if result.returncode == 1:
    sys.exit(0)
if result.stdout:
    print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
sys.exit(result.returncode or 1)
