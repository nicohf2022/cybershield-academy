#!/usr/bin/env python3
"""Summarize Terraform JSON plans and reject unapproved destruction."""
import argparse
import json
from pathlib import Path
import sys


def summarize(plan, allow_ephemeral_deletes=False):
    rows, denied = [], []
    for resource in plan.get("resource_changes", []):
        actions = resource["change"]["actions"]
        if resource.get("mode") != "managed" or actions == ["no-op"]:
            continue
        address = resource["address"]
        rows.append(f"| `{address}` | {', '.join(actions)} |")
        if "delete" in actions:
            ephemeral = any(address.startswith(f"module.{name}[") for name in
                            ("compute", "network", "iam", "monitoring"))
            if not (allow_ephemeral_deletes and ephemeral):
                denied.append(address)
            if address.startswith("module.compute[") and "create" in actions:
                if not plan.get("variables", {}).get("restore_manifest_uri", {}).get("value"):
                    denied.append(address + " (replacement requires a pinned restore manifest)")
    text = "| Resource | Action |\n|---|---|\n" + "\n".join(rows)
    if not rows:
        text += "\nNo resource changes.\n"
    if denied:
        text += "\nBlocked destruction/replacement:\n" + "\n".join("- " + item for item in denied)
    return text, denied


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    parser.add_argument("--allow-ephemeral-deletes", action="store_true")
    args = parser.parse_args()
    text, denied = summarize(json.loads(args.plan.read_text()), args.allow_ephemeral_deletes)
    print(text)
    sys.exit(1 if denied else 0)
