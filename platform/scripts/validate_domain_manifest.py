#!/usr/bin/env python3
"""Validate domains/*/domain.yaml manifests (Phase 2 contract; used by
.github/workflows/ci-terraform.yml and the local pre-commit hook).

Usage:
    python validate_domain_manifest.py domains/

Checks each domain.yaml has the required shape, that `consumes` entries
point at a topic some other domain actually `produces`, and that topic
names are globally unique. Exits non-zero with every error listed so CI
fails fast with an actionable message.
"""
from __future__ import annotations

import sys
from pathlib import Path

import yaml

REQUIRED_PRODUCT_KEYS = {"name", "dataset", "table", "topic"}
REQUIRED_CONSUMED_KEYS = {"domain", "product", "topic"}


def load_manifests(domains_dir: Path) -> dict[str, tuple[Path, dict]]:
    manifests: dict[str, tuple[Path, dict]] = {}
    for manifest_path in sorted(domains_dir.glob("*/domain.yaml")):
        with manifest_path.open() as f:
            data = yaml.safe_load(f) or {}
        manifests[manifest_path.parent.name] = (manifest_path, data)
    return manifests


def validate(domains_dir: Path) -> list[str]:
    errors: list[str] = []
    manifests = load_manifests(domains_dir)

    if not manifests:
        return [f"No domains/*/domain.yaml manifests found under {domains_dir}"]

    topic_owners: dict[str, str] = {}

    for folder_name, (path, data) in manifests.items():
        domain = data.get("domain")
        if domain != folder_name:
            errors.append(f"{path}: `domain: {domain!r}` must match its folder name {folder_name!r}")

        if "produces" not in data or not isinstance(data.get("produces"), list):
            errors.append(f"{path}: `produces` must be a list (use [] if this domain publishes nothing)")
        else:
            for i, product in enumerate(data["produces"]):
                missing = REQUIRED_PRODUCT_KEYS - product.keys()
                if missing:
                    errors.append(f"{path}: produces[{i}] missing required keys: {sorted(missing)}")
                    continue
                topic = product["topic"]
                if topic in topic_owners:
                    errors.append(
                        f"{path}: topic {topic!r} is already produced by domain "
                        f"{topic_owners[topic]!r} — topic names must be globally unique"
                    )
                topic_owners[topic] = folder_name

        consumes = data.get("consumes") or []
        if not isinstance(consumes, list):
            errors.append(f"{path}: `consumes` must be a list (omit it, or use [], if there are none)")
            consumes = []
        for i, consumed in enumerate(consumes):
            missing = REQUIRED_CONSUMED_KEYS - consumed.keys()
            if missing:
                errors.append(f"{path}: consumes[{i}] missing required keys: {sorted(missing)}")
                continue
            if consumed["domain"] == folder_name:
                errors.append(
                    f"{path}: consumes[{i}] a domain cannot consume its own product ({consumed['topic']!r})"
                )
            if consumed["domain"] not in manifests:
                errors.append(
                    f"{path}: consumes[{i}] references unknown domain {consumed['domain']!r} "
                    f"(no domains/{consumed['domain']}/domain.yaml)"
                )

    # Second pass: every consumed topic must actually be produced by the domain it names.
    for folder_name, (path, data) in manifests.items():
        for i, consumed in enumerate(data.get("consumes") or []):
            topic = consumed.get("topic")
            owner = topic_owners.get(topic) if topic else None
            if topic and owner and owner != consumed.get("domain"):
                errors.append(
                    f"{path}: consumes[{i}] topic {topic!r} is produced by "
                    f"{owner!r}, not {consumed.get('domain')!r} as declared"
                )
            elif topic and not owner:
                errors.append(f"{path}: consumes[{i}] topic {topic!r} is not produced by any domain")

    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_domain_manifest.py <domains-dir>", file=sys.stderr)
        return 2

    domains_dir = Path(sys.argv[1])
    errors = validate(domains_dir)

    if errors:
        print(f"domain.yaml validation failed with {len(errors)} error(s):\n", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    print(f"All domain.yaml manifests under {domains_dir} are valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
