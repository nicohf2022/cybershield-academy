#!/usr/bin/env python3
"""Select verified backups, fence failback writers, and measure recovery."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("database", ROOT / "app/scripts/database.py")
database = importlib.util.module_from_spec(spec)
spec.loader.exec_module(database)


def aws(*args):
    return json.loads(subprocess.check_output(["aws", *args, "--output", "json"], text=True))


def select(uri, max_age_hours):
    manifest_uri = database.latest_manifest(uri) if not uri.endswith(".json") else uri
    bucket, key = database.s3_location(manifest_uri)
    with tempfile.TemporaryDirectory(prefix="cybershield-dr-") as directory:
        manifest = Path(directory) / "manifest.json"
        database.s3_copy(manifest_uri, manifest)
        data = json.loads(manifest.read_text())
        if (data.get("format_version") != 1 or
                not re.fullmatch(r"postgres-\d{8}T\d{12}Z-[a-f0-9]{8}\.dump", data.get("dump", ""))):
            raise ValueError("Invalid project backup manifest")
        dump = Path(directory) / "backup.dump"
        database.s3_copy(f"s3://{bucket}/{key.rsplit('/', 1)[0]}/{data['dump']}", dump)
        if digest := data.get("sha256"):
            if not re.fullmatch(r"[a-f0-9]{64}", digest) or database.digest(dump) != digest:
                raise ValueError("Backup checksum mismatch")
        else:
            raise ValueError("Backup checksum missing")
        if dump.stat().st_size != data["bytes"]:
            raise ValueError("Backup size mismatch")
        snapshot = datetime.fromisoformat(data["snapshot_not_before"])
        if snapshot.tzinfo is None:
            raise ValueError("Snapshot timestamp must include timezone")
        age = (datetime.now(timezone.utc) - snapshot).total_seconds()
        if age < 0 or age > max_age_hours * 3600:
            raise ValueError("Backup exceeds the allowed age window")
        return {"manifest_uri": manifest_uri, "snapshot_not_before": snapshot.isoformat(),
                "sha256": digest, "bytes": data["bytes"]}


def remote(region, instance, commands):
    command = aws("ssm", "send-command", "--region", region, "--instance-ids", instance,
                  "--document-name", "AWS-RunShellScript", "--parameters",
                  json.dumps({"commands": ["set -eu", *commands], "executionTimeout": ["600"]}))
    command_id = command["Command"]["CommandId"]
    deadline = time.monotonic() + 660
    while time.monotonic() < deadline:
        try:
            result = aws("ssm", "get-command-invocation", "--region", region,
                         "--command-id", command_id, "--instance-id", instance)
        except subprocess.CalledProcessError:
            time.sleep(5)
            continue
        if result["Status"] == "Success":
            return result["StandardOutputContent"]
        if result["Status"] not in ("Pending", "InProgress", "Delayed"):
            raise RuntimeError(f"SSM failed: {result['Status']}: {result.get('StandardErrorContent', '')}")
        time.sleep(5)
    raise TimeoutError("SSM operation timed out")


def emit(data, output):
    text = json.dumps(data, indent=2) + "\n"
    if output:
        Path(output).write_text(text)
    print(text, end="")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as stream:
            for key, value in data.items():
                stream.write(f"{key}={value}\n")


def check_backend(path, expected_region):
    match = re.search(r'^region\s*=\s*"([^"]+)"', path.read_text(), re.M)
    if not match or match.group(1) != expected_region:
        raise ValueError("Recovery backend must already be accessible in the recovery region; approve state migration first")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["select", "smoke", "freeze", "backend-check"])
    parser.add_argument("--uri")
    parser.add_argument("--max-age-hours", type=float, default=2)
    parser.add_argument("--region")
    parser.add_argument("--instance")
    parser.add_argument("--expected-slug")
    parser.add_argument("--incident-at")
    parser.add_argument("--selection")
    parser.add_argument("--output")
    parser.add_argument("--backend", type=Path)
    args = parser.parse_args()
    if args.command == "backend-check":
        check_backend(args.backend, args.region)
        return
    if args.command == "select":
        if not (0 < args.max_age_hours < float("inf")):
            raise ValueError("Backup age limit must be positive and finite")
        emit(select(args.uri, args.max_age_hours), args.output)
        return
    if args.command == "freeze":
        # Fence web writes before the final backup. Failure leaves the writer stopped.
        remote(args.region, args.instance, [
            "touch /opt/cybershield/.writer-fenced",
            "systemctl disable --now cybershield-backup.timer",
            "while systemctl is-active --quiet cybershield-backup.service; do sleep 2; done",
            "docker compose --project-directory /opt/cybershield --project-name cybershield stop app",
            "systemctl start cybershield-backup.service",
        ])
        emit({"source_frozen": True, "frozen_at": datetime.now(timezone.utc).isoformat()}, args.output)
        return
    commands = ["cloud-init status --wait", "systemctl is-active --quiet cybershield.service",
                "curl --fail --silent --retry 12 --retry-all-errors --retry-delay 5 --max-time 5 http://127.0.0.1/health"]
    if args.expected_slug:
        if not re.fullmatch(r"[a-z0-9-]{1,80}", args.expected_slug):
            raise ValueError("Expected slug must contain lowercase letters, digits and hyphens")
        sql = "SELECT count(*) FROM lessons WHERE slug='" + args.expected_slug + "'"
        script = 'test "$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -X -Atc ' + shlex.quote(sql) + ')" = 1'
        commands.append("docker compose --project-directory /opt/cybershield --project-name cybershield exec -T db sh -ec " + shlex.quote(script))
    remote(args.region, args.instance, commands)
    finished = datetime.now(timezone.utc)
    result = {"recovered_at": finished.isoformat(), "health": "ok", "instance_id": args.instance}
    if args.incident_at and args.selection:
        incident = datetime.fromisoformat(args.incident_at)
        selection = json.loads(Path(args.selection).read_text())
        snapshot = datetime.fromisoformat(selection["snapshot_not_before"])
        if incident.tzinfo is None or snapshot > incident or incident > finished:
            raise ValueError("Invalid incident/snapshot timing; do not claim an RPO for a post-incident backup")
        result.update({"rto_seconds": (finished - incident).total_seconds(),
                       "rpo_snapshot_age_upper_bound_seconds": (incident - snapshot).total_seconds(),
                       "manifest_uri": selection["manifest_uri"]})
    emit(result, args.output)


if __name__ == "__main__":
    main()
