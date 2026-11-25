# Shared Terraform root and safe adoption

The application has one root: `infra/envs/dr`. `region-a` and `region-b` now
contain only backend settings and non-secret regional inputs. Regions and zones
are inputs rather than validation constants; omitted AZ selects an available AZ
in that provider region. Set `availability_zone` explicitly if preserving a
specific existing subnet. Terraform and AWS provider locks are unchanged.

The default HTTP CIDR is loopback so deployments fail closed. Supply the team's
actual public IPv4 CIDRs privately. A web demo may explicitly permit a wider
audience after reviewing the plan; PostgreSQL and SSH stay unpublished.

```bash
export AWS_PROFILE=cybershield
export TF_VAR_allowed_http_cidrs='["YOUR-PUBLIC-IP/32"]'
bash scripts/tf.sh region-b init
bash scripts/tf.sh region-b plan -out=/tmp/review-b.tfplan
bash scripts/tf.sh region-a init
bash scripts/tf.sh region-a plan -out=/tmp/review-a.tfplan
```

These commands initialize the **same existing** backend keys and generate plans.
They do not migrate state. The wrapper isolates caches under
`.terraform-data/region-a` and `.terraform-data/region-b`; never reuse one cache
for both states. Preserve backend settings until a separately approved migration.
Do not run Terraform from the regional input directories anymore.

## Existing resource addresses

Storage remains `module.storage`, so both existing buckets stay in their own
states. `moved` blocks map existing `module.network`, `module.iam`,
`module.compute`, `module.monitoring` and `module.replication` addresses to their
`[0]` instances. These declarations record address changes on a future approved
apply; they do not manually edit state and do not themselves require recreation.
Do not remove the moved blocks while any teammate still has old state addresses.

The adoption plan will also include real behavior changes: lowercase tags,
shorter retention, restricted HTTPS egress, optional subnet addressing, workload
IAM adjustments, dashboard and updated compressed startup data. The corrected
startup data **still requires EC2 replacement** under the existing lifecycle
setting. Do not claim that address preservation eliminates that replacement.

Before approving a primary replacement: fence writers, take and verify a fresh
backup, select its exact manifest, and plan with
`-var=restore_manifest_uri=s3://BUCKET/postgres/FILE.json`. Restore preserves
database objects and rows, not the old host-generated password. Review all
destruction/replacement and obtain explicit approval before applying a saved
plan. A cold-start test must pass before this change is declared deployed.
The CI plan guard rejects replacement without both explicit ephemeral-change
permission and a pinned restore manifest. Do not add `ignore_changes` to hide
the existing startup drift.

## Routine session teardown

Plan `-var=enable_compute=false` and approve that plan to remove VM, root EBS,
network, workload IAM and monitoring while preserving both backup buckets,
replication and state. PostgreSQL's local volume is deleted with EC2; take a
fresh verified backup first. The `destroy.yml` workflow implements this cost-safe
teardown through a saved, reviewed plan; it does not run an unrestricted destroy.
Logs/dashboard disappear with demo monitoring, so save evidence beforehand.

An unconditional `terraform destroy` includes the backup buckets. They use
`force_destroy=false` and will reject deletion while populated. Final complete
data deletion requires a separate explicit approval to purge object versions,
review disabling replication and destroy the data resources. State buckets and
budget use destruction protection and must remain separate from demo teardown.

## Recovery state independence

Region B migrated to the versioned bucket in `us-east-2` on November 25, 2026.
Terraform reported no changes with the deployed inputs. The original source
object remains in the Region A bucket. The migration procedure below records
how to move the state if a future backend change is needed.

1. Coordinate a maintenance window with both teammates. Pause Terraform
   operations and confirm that the source has no active lock and the
   destination has no state or lock history for this key.
2. Initialize the source using the wrapper from the repository root. Save
   the exact source object version in a restricted directory outside Git.
   Record its version ID and capture the source resource addresses for
   comparison. State backups may contain sensitive values.
3. After explicit migration approval, use the same Region B cache and run
   the interactive migration from the repository root.

   ```bash
   export AWS_PROFILE=cybershield
   export TF_DATA_DIR="$PWD/.terraform-data/region-b"
   # Run this with backend.hcl still configured for the source.
   bash scripts/tf.sh region-b init
   terraform -chdir=infra/envs/dr init -migrate-state -lockfile=readonly \
     -backend-config=../region-b/backend-dr.hcl.example
   ```

4. Compare destination resource addresses, resource data, and outputs with the
   backup. Record the source and destination lineage and serial for audit.
   In the November 25 migration the destination had a new lineage and serial
   1 (source serial 4). All nine addresses, resources and outputs matched.
   Check that Terraform released the locks normally.
   Update `infra/envs/region-b/backend.hcl` to match the destination and run
   a Region B plan with the same inputs used for the deployed configuration.
   Confirm that the plan reports no changes before publishing the backend
   configuration and reopening Region B operations.
5. Teammates with a cached source backend can reinitialize it with
   `bash scripts/tf.sh region-b init -reconfigure` after the new backend
   configuration is available and the destination state is verified.

The failover workflow deliberately refuses to run while its state backend is
outside the recovery region. The primary/root bootstrap state need not be read
during failover once Region B state and automation are independently available.

## Evidence still required

During the migration window a second Region B plan failed with
`Error acquiring the state lock` while the first held the lock. The first
plan reported no changes, and S3 showed that its lock released normally.
Record the regional failover restore and failback, a metric-driven alarm
transition, and the final compute teardown. See
[assignment coverage and evidence status](../status.md) for the remaining work.

Recovery IAM is global readiness infrastructure owned by bootstrap, with no
hourly compute cost. Populate Region B's `precreated_instance_profile_name`
from the approved bootstrap output before disaster. The recovery root does not
manage or refresh that IAM role; it references the existing profile name without
reading bootstrap state. This avoids a new IAM control-plane dependency during
failover. Keep the profile through compute teardown. Regional B normally retains
only S3 storage; the supporting global IAM identities already exist.
