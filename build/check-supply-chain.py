#!/usr/bin/env python3
"""Static supply-chain policy checks for HomeOS release inputs."""

from __future__ import annotations

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXPECTED_DEBIAN_CD_FPR = "DF9B9C49EAA9298432589D76DA87E80D6294BE9B"
KEYRING = ROOT / "build" / "debian-cd-signing-key.gpg"
DOWNLOADER = ROOT / "build" / "download-base-iso.sh"
CASAOS_TASKS = ROOT / "bootstrap" / "roles" / "casaos" / "tasks" / "main.yml"
VARS = ROOT / "bootstrap" / "vars" / "main.yml"

errors: list[str] = []

if not KEYRING.is_file() or KEYRING.stat().st_size == 0:
    errors.append(f"missing Debian CD keyring: {KEYRING.relative_to(ROOT)}")
else:
    try:
        result = subprocess.run(
            ["gpg", "--show-keys", "--with-colons", str(KEYRING)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        fingerprints = [
            line.split(":")[9]
            for line in result.stdout.splitlines()
            if line.startswith("fpr:")
        ]
        if EXPECTED_DEBIAN_CD_FPR not in fingerprints:
            errors.append(
                "Debian CD keyring missing expected fingerprint "
                + EXPECTED_DEBIAN_CD_FPR
            )
    except Exception as exc:  # noqa: BLE001 - static checker should report concise failure
        errors.append(f"Debian CD keyring is not parseable by gpg: {exc}")

text = DOWNLOADER.read_text(encoding="utf-8")
for needle in ["SHA256SUMS.sign", "gpgv --keyring", "debian-cd-signing-key.gpg"]:
    if needle not in text:
        errors.append(
            f"download-base-iso.sh missing required signed-manifest check: {needle}"
        )

vars_text = VARS.read_text(encoding="utf-8")
for needle in [
    "casaos_installer_url",
    "casaos_installer_sha256",
    "casaos_allow_unverified_installer",
]:
    if needle not in vars_text:
        errors.append(f"vars/main.yml missing CasaOS trust policy variable: {needle}")

tasks_text = CASAOS_TASKS.read_text(encoding="utf-8")
for needle in [
    "ansible.builtin.get_url",
    "checksum:",
    "casaos_allow_unverified_installer",
]:
    if needle not in tasks_text:
        errors.append(f"CasaOS role missing installer trust control: {needle}")

if errors:
    for error in errors:
        print(f"[supply-chain] {error}", file=sys.stderr)
    sys.exit(1)

print("[supply-chain] OK")
