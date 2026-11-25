"""Run: python3 -m unittest discover -s app/scripts -p 'test_*.py' -v.

Set RUN_DOCKER_TESTS=1 to also create two temporary PostgreSQL Compose projects.
"""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import uuid


SCRIPT = Path(__file__).with_name("database.py").resolve()
APP = SCRIPT.parents[1]
spec = importlib.util.spec_from_file_location("database", SCRIPT)
database = importlib.util.module_from_spec(spec)
spec.loader.exec_module(database)


class SafetyTests(unittest.TestCase):
    def test_latest_uses_snapshot_name_and_ignores_other_objects(self):
        older = "postgres-20261124T120000000000Z-aaaaaaaa.json"
        newer = "postgres-20261124T130000000000Z-bbbbbbbb.json"
        objects = ["db/" + newer, "db/not-a-backup.json", "db/" + older,
                   "db/subdir/" + newer, "db/" + newer.replace("json", "dump")]
        result = subprocess.CompletedProcess([], 0, json.dumps(objects))
        with patch.object(database, "run", return_value=result):
            self.assertEqual(database.latest_manifest("s3://example-bucket/db/"),
                             "s3://example-bucket/db/" + newer)

    def test_empty_bucket_fails_explicitly(self):
        with patch.object(database, "run", return_value=subprocess.CompletedProcess([], 0, "null")):
            with self.assertRaisesRegex(ValueError, "No backup manifests"):
                database.latest_manifest("s3://example-bucket/db")

    def test_restore_requires_explicit_replacement_before_fetching(self):
        args = type("Args", (), {"replace": False})()
        with patch.object(database, "s3_copy") as copy:
            with self.assertRaisesRegex(ValueError, "--replace"):
                database.restore(args)
            copy.assert_not_called()

    def test_lock_rejects_overlapping_operations(self):
        with tempfile.TemporaryDirectory() as directory:
            args = type("Args", (), {"app_dir": Path(directory), "project": "test"})()
            with database.operation_lock(args):
                with self.assertRaisesRegex(ValueError, "Another backup or restore"):
                    with database.operation_lock(args):
                        self.fail("Concurrent operation was accepted")

    def test_s3_backup_uploads_manifest_only_after_dump(self):
        with tempfile.TemporaryDirectory() as directory:
            args = type("Args", (), {"app_dir": Path(directory), "output_dir": None,
                                     "s3_prefix": "s3://example-bucket/postgres"})()
            uploads = []

            def fake_db(args, command, **kwargs):
                if "pg_dump" in command:
                    kwargs["stdout"].write(b"test archive")

            def fake_upload(source, destination):
                uploads.append(destination)
                if destination.endswith(".json"):
                    metadata = json.loads(source.read_text())
                    self.assertEqual(metadata["sha256"], database.digest(source.parent / metadata["dump"]))

            with patch.object(database, "db", side_effect=fake_db), \
                    patch.object(database, "s3_copy", side_effect=fake_upload):
                database.backup(args)
            self.assertTrue(uploads[0].endswith(".dump"))
            self.assertTrue(uploads[1].endswith(".json"))

    def test_missing_replicated_dump_never_stops_app(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            metadata = {"format_version": 1,
                        "dump": "postgres-20261124T120000000000Z-aaaaaaaa.dump",
                        "sha256": "a" * 64, "bytes": 100,
                        "snapshot_not_before": "2026-11-24T12:00:00+00:00"}

            def download(source, destination):
                if source.endswith(".json"):
                    destination.write_text(json.dumps(metadata))
                else:
                    raise subprocess.CalledProcessError(1, ["aws", "s3", "cp"])

            args = type("Args", (), {"replace": True, "latest": None, "project": "test",
                                     "manifest": "s3://example-bucket/backup.json",
                                     "max_age_hours": None})()
            with patch.object(database, "s3_copy", side_effect=download), \
                    patch.object(database, "compose") as compose:
                with self.assertRaises(subprocess.CalledProcessError):
                    database.restore(args)
                compose.assert_not_called()


@unittest.skipUnless(os.environ.get("RUN_DOCKER_TESTS") == "1", "opt-in Docker integration")
class DockerRoundTripTests(unittest.TestCase):
    def test_restore_to_another_database_owner_and_reject_corruption(self):
        with tempfile.TemporaryDirectory(prefix="cybershield-db-test-") as directory:
            root = Path(directory)
            projects = []

            def command(argv, **kwargs):
                return subprocess.run(argv, check=True, capture_output=True, text=True, **kwargs)

            def dc(folder, project, *arguments):
                return command(["docker", "compose", "--project-directory", str(folder),
                                "--project-name", project, *arguments])

            def sql(folder, project, statement):
                return dc(folder, project, "exec", "-T", "db", "sh", "-ec",
                          'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" '
                          '-X -v ON_ERROR_STOP=1 -Atc "$1"', "sh", statement).stdout.strip()

            def tool(folder, project, *arguments, success=True):
                result = subprocess.run(["python3", str(SCRIPT), "--app-dir", str(folder),
                                         "--project", project, *arguments],
                                        capture_output=True, text=True)
                if success:
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                else:
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                return result

            try:
                for label in ["source", "target"]:
                    folder = root / label
                    folder.mkdir()
                    shutil.copy(APP / "compose.yaml", folder)
                    shutil.copytree(APP / "database", folder / "database")
                    (folder / ".env").write_text(
                        "POSTGRES_DB=cybershield\nPOSTGRES_USER=" + label + "_owner\n"
                        "POSTGRES_PASSWORD=" + uuid.uuid4().hex + "\n")
                    project = "cs-db-test-" + label + "-" + uuid.uuid4().hex[:8]
                    projects.append((folder, project))
                    dc(folder, project, "up", "--detach", "--wait", "--wait-timeout", "120", "db")
                source, target = projects
                sql(*source, "INSERT INTO lessons(slug,title,description) "
                    "VALUES ('dr-marker','DR marker','Must survive restore')")
                output = root / "backups"
                tool(*source, "backup", "--output-dir", str(output))
                manifest = next(output.glob("*.json"))
                metadata = json.loads(manifest.read_text())
                self.assertEqual(metadata["sha256"], database.digest(output / metadata["dump"]))
                self.assertEqual(manifest.stat().st_mode & 0o777, 0o600)
                sql(*target, "INSERT INTO lessons(slug,title,description) "
                    "VALUES ('target-only','Target only','Must disappear')")
                # Missing --replace must preserve the target.
                tool(*target, "restore", "--manifest", str(manifest), success=False)
                self.assertEqual(sql(*target, "SELECT count(*) FROM lessons WHERE slug='target-only'"), "1")
                tool(*target, "restore", "--manifest", str(manifest), "--replace")
                self.assertEqual(sql(*target, "SELECT count(*) FROM lessons WHERE slug='dr-marker'"), "1")
                self.assertEqual(sql(*target, "SELECT count(*) FROM lessons WHERE slug='target-only'"), "0")
                self.assertEqual(sql(*target, "SELECT count(*) FROM lessons"), "4")
                # Identity sequence must also survive restoration.
                self.assertEqual(sql(*target, "INSERT INTO lessons(slug,title,description) "
                                     "VALUES ('after-restore','After','Sequence check') RETURNING id").splitlines()[0], "5")
                # A destination-only dependency forces a SQL error. Data must roll back.
                sql(*target, "CREATE VIEW restore_blocker AS SELECT * FROM lessons")
                tool(*target, "restore", "--manifest", str(manifest), "--replace", success=False)
                self.assertEqual(sql(*target, "SELECT count(*) FROM restore_blocker"), "5")
                sql(*target, "DROP VIEW restore_blocker")
                dump = output / metadata["dump"]
                with dump.open("ab") as stream:
                    stream.write(b"corruption")
                rejected = tool(*target, "restore", "--manifest", str(manifest), "--replace", success=False)
                self.assertIn("checksum mismatch", rejected.stdout)
                self.assertEqual(sql(*target, "SELECT count(*) FROM lessons"), "5")
            finally:
                # Only remove disposable projects/volumes created by this test.
                for folder, project in projects:
                    dc(folder, project, "down", "--volumes", "--remove-orphans")


if __name__ == "__main__":
    unittest.main()
