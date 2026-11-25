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

## Recovery state independence — not yet migrated

The current Region B backend still points to Region A. `infra/bootstrap` now
offers opt-in `recovery_state_region` to create a private, encrypted, versioned,
protected state bucket in Region B. It adds S3 storage/request cost, not compute.
Review that bootstrap plan from the team's canonical bootstrap backend and
approve its apply separately. Do not initialize bootstrap from a new empty state.

After creation, the **owner of the canonical Region B state** must coordinate a
maintenance window, save a secure backup, verify no active locks and explicitly
approve migration. First initialize the existing backend using the wrapper.
Then, in that same Region B `TF_DATA_DIR`, run an explicitly approved
`terraform init -migrate-state` with the proposed backend settings from
`region-b/backend-dr.hcl.example`. Do not use `-reconfigure` to move state and
never create an empty replacement state. Verify resource addresses, backend
location, a no-recreation plan and normal lock release before committing the
new `backend.hcl`. Secure backups must stay outside Git.

The failover workflow deliberately refuses to run while its state backend is
outside the recovery region. The primary/root bootstrap state need not be read
during failover once Region B state and automation are independently available.

## Evidence still required

Approved adoption, cold boot, independent-state migration, concurrent-lock
verification, a no-change second plan, scheduled backup observation, actual DR
restore, alarm activation and final teardown are deployment/test actions. This
code change does not fabricate those results or authorize running them.

Recovery IAM is global readiness infrastructure owned by bootstrap, with no
hourly compute cost. Populate Region B's `precreated_instance_profile_name`
from the approved bootstrap output before disaster. The recovery root does not
manage or refresh that IAM role; it references the existing profile name without
reading bootstrap state. This avoids a new IAM control-plane dependency during
failover. Keep the profile through compute teardown. Regional B normally retains
only S3 storage; the supporting global IAM identities already exist.
