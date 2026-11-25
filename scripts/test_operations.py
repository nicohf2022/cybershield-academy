import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import dr
from plan_summary import summarize


def plan(address, actions, manifest=None):
    return {"variables": {"restore_manifest_uri": {"value": manifest}},
            "resource_changes": [{"address": address, "mode": "managed",
                                  "change": {"actions": actions}}]}


class PlanGuardTests(unittest.TestCase):
    def test_backup_deletion_always_blocked(self):
        _, denied = summarize(plan("module.storage.aws_s3_bucket.backups", ["delete"]), True)
        self.assertTrue(denied)

    def test_state_or_bootstrap_deletion_always_blocked(self):
        _, denied = summarize(plan("aws_s3_bucket.terraform_state", ["delete"]), True)
        self.assertTrue(denied)

    def test_vm_replacement_needs_both_permission_and_restore(self):
        address = "module.compute[0].aws_instance.app"
        self.assertTrue(summarize(plan(address, ["delete", "create"]), True)[1])
        self.assertTrue(summarize(plan(address, ["delete", "create"], "s3://backup/manifest.json"))[1])
        self.assertFalse(summarize(plan(address, ["delete", "create"], "s3://backup/manifest.json"), True)[1])

    def test_compute_teardown_allowed_without_bucket_destruction(self):
        self.assertFalse(summarize(plan("module.network[0].aws_vpc.this", ["delete"]), True)[1])
        self.assertTrue(summarize(plan("module.replication[0].aws_iam_role.replication", ["delete"]), True)[1])

    def test_plan_comment_does_not_expose_values(self):
        data = plan("module.compute[0].aws_instance.app", ["create"])
        data["resource_changes"][0]["change"]["after"] = {"password": "never-print-this"}
        self.assertNotIn("never-print-this", summarize(data)[0])


class BackupSelectionTests(unittest.TestCase):
    def test_checksum_validation_before_returning_pinned_uri(self):
        content = b"test-backup"
        manifest = {"format_version": 1, "dump": "postgres-20261125T000000000000Z-12345678.dump",
                    "sha256": hashlib.sha256(content).hexdigest(), "bytes": len(content),
                    "snapshot_not_before": "2026-11-25T00:00:00+00:00"}

        def copy(source, target):
            target.write_bytes(json.dumps(manifest).encode() if source.endswith(".json") else content)

        with patch.object(dr.database, "s3_copy", side_effect=copy):
            self.assertEqual(dr.select("s3://test-bucket/postgres/manifest.json", 1e9)["sha256"], manifest["sha256"])
            manifest["sha256"] = "0" * 64
            with self.assertRaisesRegex(ValueError, "checksum"):
                dr.select("s3://test-bucket/postgres/manifest.json", 1e9)

    def test_recovery_backend_must_not_depend_on_primary_region(self):
        with tempfile.TemporaryDirectory() as directory:
            backend = Path(directory) / "backend.hcl"
            backend.write_text('region = "eu-west-1"\n')
            dr.check_backend(backend, "eu-west-1")
            with self.assertRaisesRegex(ValueError, "approve state migration"):
                dr.check_backend(backend, "eu-west-2")



if __name__ == "__main__":
    unittest.main()
