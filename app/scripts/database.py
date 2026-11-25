#!/usr/bin/env python3
"""Logical PostgreSQL backup/restore through the existing Compose db service."""

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import uuid


def now():
    return datetime.now(timezone.utc).isoformat()


def log(event, **fields):
    print(json.dumps({"time": now(), "event": event, **fields}), flush=True)


def run(command, **kwargs):
    return subprocess.run(command, check=True, **kwargs)


def compose(args, *command, **kwargs):
    return run(["docker", "compose", "--project-directory", str(args.app_dir),
                "--project-name", args.project, *command], **kwargs)


def db(args, command, **kwargs):
    # Credentials stay inside the container; do not source the host .env as code.
    return compose(args, "exec", "-T", "db", "sh", "-ec", command, **kwargs)


def digest(path):
    checksum = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            checksum.update(chunk)
    return checksum.hexdigest()


def s3_location(uri):
    match = re.fullmatch(r"s3://([a-z0-9][a-z0-9.-]+)(?:/([^\s]*))?", uri)
    if not match:
        raise ValueError("Use s3://bucket/optional-prefix without whitespace")
    return match.group(1), (match.group(2) or "").rstrip("/")


def s3_copy(source, destination):
    run(["aws", "s3", "cp", str(source), str(destination), "--only-show-errors"])


@contextmanager
def operation_lock(args):
    # Backups and restores on this host/project must never overlap.
    path = args.app_dir / (".database-" + args.project + ".lock")
    with open(path, "a", opener=lambda p, flags: os.open(p, flags, 0o600)) as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError("Another backup or restore is running for this project") from None
        yield


def backup(args):
    if args.s3_prefix:
        s3_location(args.s3_prefix)
    directory = args.output_dir
    # S3-only backups use temporary local space, removed after the operation.
    with tempfile.TemporaryDirectory(prefix="cybershield-backup-") as temporary:
        directory = directory or (Path(temporary) if args.s3_prefix
                                  else args.app_dir / ".backups")
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        started = now()
        stem = "postgres-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        stem += "-" + uuid.uuid4().hex[:8]
        dump = directory / (stem + ".dump")
        manifest = directory / (stem + ".json")
        partial = dump.with_suffix(".partial")
        log("backup_started", snapshot_not_before=started)
        try:
            with partial.open("xb") as stream:
                db(args, 'exec pg_dump --username="$POSTGRES_USER" '
                   '--dbname="$POSTGRES_DB" --format=custom --no-owner --no-acl',
                   stdout=stream)
            # Check the archive table of contents before publishing it.
            with partial.open("rb") as stream:
                db(args, "exec pg_restore --list", stdin=stream, stdout=subprocess.DEVNULL)
            partial.rename(dump)
            metadata = {"format_version": 1, "dump": dump.name,
                        "sha256": digest(dump), "bytes": dump.stat().st_size,
                        "snapshot_not_before": started, "dump_completed_at": now()}
            manifest.write_text(json.dumps(metadata, indent=2) + "\n")
            if args.s3_prefix:
                prefix = args.s3_prefix.rstrip("/")
                s3_copy(dump, prefix + "/" + dump.name)
                # Publish the manifest last: it marks a successful source upload.
                s3_copy(manifest, prefix + "/" + manifest.name)
                log("backup_uploaded", manifest=prefix + "/" + manifest.name,
                    snapshot_not_before=started, bytes=metadata["bytes"])
            else:
                log("backup_saved", manifest=str(manifest), bytes=metadata["bytes"])
        finally:
            partial.unlink(missing_ok=True)


def latest_manifest(prefix):
    bucket, key_prefix = s3_location(prefix)
    result = run(["aws", "s3api", "list-objects-v2", "--bucket", bucket,
                  "--prefix", key_prefix + "/" if key_prefix else "",
                  "--query", "Contents[].Key", "--output", "json"],
                 capture_output=True, text=True)
    keys = json.loads(result.stdout) or []
    # UTC snapshot-start filenames sort chronologically; listing order is irrelevant.
    pattern = re.compile(r"postgres-\d{8}T\d{12}Z-[0-9a-f]{8}\.json")
    candidates = [key for key in keys
                  if pattern.fullmatch(key.removeprefix(key_prefix + "/")
                                       if key_prefix else key)]
    if not candidates:
        raise ValueError("No backup manifests found in the requested S3 prefix")
    return "s3://" + bucket + "/" + max(candidates)


def restore(args):
    if not args.replace:
        raise ValueError("Restore replaces backed-up database objects; pass --replace explicitly")
    source = latest_manifest(args.latest) if args.latest else args.manifest
    log("restore_started", manifest=source, project=args.project)
    with tempfile.TemporaryDirectory(prefix="cybershield-restore-") as temporary:
        directory = Path(temporary)
        if source.startswith("s3://"):
            s3_location(source)
            manifest = directory / "manifest.json"
            s3_copy(source, manifest)
        else:
            manifest = Path(source).resolve()
        metadata = json.loads(manifest.read_text())
        filename = metadata.get("dump", "")
        if (metadata.get("format_version") != 1
                or not re.fullmatch(r"postgres-\d{8}T\d{12}Z-[0-9a-f]{8}\.dump", filename)
                or not re.fullmatch(r"[a-f0-9]{64}", metadata.get("sha256", ""))
                or not isinstance(metadata.get("bytes"), int)
                or metadata["bytes"] <= 0):
            raise ValueError("Invalid backup manifest")
        snapshot = datetime.fromisoformat(metadata["snapshot_not_before"])
        if snapshot.tzinfo is None:
            raise ValueError("Backup timestamp must include timezone")
        if args.max_age_hours is not None:
            age = (datetime.now(timezone.utc) - snapshot).total_seconds()
            if age < 0 or age > args.max_age_hours * 3600:
                raise ValueError("Backup is outside the allowed age window")
        if source.startswith("s3://"):
            dump = directory / filename
            s3_copy(source.rsplit("/", 1)[0] + "/" + filename, dump)
        else:
            dump = manifest.parent / filename
        if dump.stat().st_size != metadata["bytes"] or digest(dump) != metadata["sha256"]:
            raise ValueError("Backup size/checksum mismatch; database has not been changed")
        with dump.open("rb") as stream:
            db(args, "exec pg_restore --list", stdin=stream, stdout=subprocess.DEVNULL)
        log("backup_verified", snapshot_not_before=metadata["snapshot_not_before"])
        # Do not restart the app on failure. PostgreSQL rolls back the restore.
        compose(args, "stop", "app")
        with dump.open("rb") as stream:
            db(args, 'exec pg_restore --username="$POSTGRES_USER" '
               '--dbname="$POSTGRES_DB" --clean --if-exists --no-owner --no-acl '
               '--single-transaction --exit-on-error', stdin=stream)
        result = db(args, 'exec psql --username="$POSTGRES_USER" --dbname="$POSTGRES_DB" '
                    '--no-psqlrc --set=ON_ERROR_STOP=1 --tuples-only --no-align '
                    '--command="SELECT count(*) FROM public.lessons"',
                    capture_output=True, text=True)
        if args.start_app:
            compose(args, "up", "--detach", "--no-deps", "app")
        log("restore_completed", snapshot_not_before=metadata["snapshot_not_before"],
            lessons=int(result.stdout.strip()), app_started=args.start_app)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app-dir", type=Path,
                        default=Path(__file__).resolve().parents[1])
    parser.add_argument("--project", default=os.environ.get("COMPOSE_PROJECT_NAME", "cybershield"))
    commands = parser.add_subparsers(dest="operation", required=True)
    save = commands.add_parser("backup", help="Create a local and/or S3 backup")
    save.add_argument("--output-dir", type=Path)
    save.add_argument("--s3-prefix", help="s3://bucket/prefix; uses normal AWS CLI credentials")
    load = commands.add_parser("restore", help="Restore a trusted backup manifest")
    source = load.add_mutually_exclusive_group(required=True)
    source.add_argument("--manifest", help="Local .json manifest or s3://bucket/key.json")
    source.add_argument("--latest", help="Find latest manifest under s3://bucket/prefix")
    load.add_argument("--replace", action="store_true", help="Explicitly permit overwriting data")
    load.add_argument("--start-app", action="store_true", help="Start app after successful restore")
    load.add_argument("--max-age-hours", type=float, help="Reject backups older than this limit")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", args.project):
        parser.error("project must contain lowercase letters, numbers, hyphens or underscores")
    if getattr(args, "max_age_hours", None) is not None and not (0 < args.max_age_hours < float("inf")):
        parser.error("max-age-hours must be a positive finite number")
    args.app_dir = args.app_dir.resolve()
    os.umask(0o077)
    try:
        with operation_lock(args):
            (backup if args.operation == "backup" else restore)(args)
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        log("operation_failed", operation=args.operation, error=str(error))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
