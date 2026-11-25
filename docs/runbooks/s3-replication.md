# Replicated PostgreSQL backups

> Current code uses `infra/envs/dr` and `scripts/tf.sh`; follow
> [shared-root adoption](shared-root.md) and [workflow setup](github-actions.md).
> Earlier root-directory commands and recorded deployment evidence below are
> historical. No existing state is automatically migrated by the refactor.

Region B now declares a permanent backup bucket using the existing storage
module. It has versioning, SSE-S3 encryption, blocked public access,
bucket-owner-enforced ownership and an HTTPS-only policy. There is no recovery
EC2, VPC or other compute declared by this step.

Region A uses the new `replication` module to copy `postgres/` objects to Region B.
The S3 service role can read source backup versions and write replicas only in
the destination backup prefix. It has no EC2 permissions, no state bucket access,
and no replica deletion permission. Delete-marker replication is disabled so
deleting a source object does not hide its recovery copy.

This is same-account, one-way, asynchronous replication. It uses STANDARD
storage and the existing SSE-S3 encryption; KMS, Batch Replication and paid
Replication Time Control are not configured. Replica storage, replication PUT
requests and cross-region data transfer incur charges. Review the expected
backup size, frequency and retention against the budget before apply. No
resources were deployed just by adding this code.

## Ownership and dependencies

- Region B state owns the destination bucket and its settings.
- Region A state owns the source bucket, replication role and replication rule.
- No `terraform_remote_state` data source is needed. Roots agree on a bucket
  name derived from account ID and recovery region, or explicit name overrides.
- Backend files are unchanged. The separate state-resilience work must still be
  completed before claiming recovery from a full primary-region outage.
- Both buckets must have versioning enabled before creating the rule. Region A
  waits for its source bucket module; the destination is a cross-root dependency
  that must be deployed first.

## Deployment sequence (approval required)

1. Coordinate backend readiness with the teammate working on state.
2. Verify the AWS account with `aws sts get-caller-identity --profile cybershield`.
3. Initialize Region B using the backend configuration agreed with that teammate,
   then review `AWS_PROFILE=cybershield terraform -chdir=infra/envs/region-b plan`.
   Expect only backup storage resources; no compute.
4. Obtain explicit approval for applying Region B. After its approved deployment,
   retrieve `backup_bucket_name` and `backup_s3_prefix` from its outputs.
5. If the recovery name was overridden, set Region A's
   `recovery_backup_bucket_name` to that exact output through private/local
   configuration. Region A's `recovery_region` must match Region B's `aws_region`
   when relying on derived names. Bucket names are configuration, not secrets.
6. Review Region A's plan separately, then obtain explicit approval before apply.
   Its EC2 startup depends on replication setup so the initial database backup
   is uploaded only after the rule is installed.

Do not apply Region A first and assume Terraform will create the destination:
the separate regional states cannot order each other's operations.

## Verify after approved deployment

Generate a new backup with the existing script, using your actual source bucket:

```bash
AWS_PROFILE=cybershield python3 app/scripts/database.py --project app backup \
  --s3-prefix s3://PRIMARY-BACKUP-BUCKET/postgres
```

Use the manifest filename printed by that command and its corresponding dump
filename. For each source object, inspect its status:

```bash
aws s3api head-object --profile cybershield --region us-east-1 \
  --bucket PRIMARY-BACKUP-BUCKET --key postgres/OBJECT-NAME \
  --query '{ReplicationStatus:ReplicationStatus,Bytes:ContentLength}'
```

Wait for `COMPLETED` on **both** objects. Then inspect each destination object:

```bash
aws s3api head-object --profile cybershield --region us-east-2 \
  --bucket RECOVERY-BACKUP-BUCKET --key postgres/OBJECT-NAME \
  --query '{ReplicationStatus:ReplicationStatus,Bytes:ContentLength}'
```

Expect `REPLICA` and the same object sizes. Download/restore into a disposable
destination using the [database runbook](database-backup-restore.md), then compare
a unique marker record and the manifest checksum. Do not test restoration against
the only live primary database. Save status outputs, timestamps and restore logs
as evidence; do not include credentials or raw database contents in public logs.

## Important behavior

- Live replication covers new eligible objects written after the rule exists.
  Existing backups are not automatically backfilled. Create a fresh database
  backup after enabling replication; do not assume earlier copies exist in B.
- Dump and manifest replication are independent. The restore script fails closed
  if the latest manifest arrives before its dump. Retry after both complete.
- Replication is asynchronous and no completion-time guarantee is configured.
  Measure actual lag; an hourly scheduler alone does not prove a one-hour RPO.
- A failed replication status needs investigation of IAM, bucket versioning,
  encryption and object permissions. Do not broaden the role to AdministratorAccess.
- Current timestamped backups are still retained indefinitely. The existing
  lifecycle rule expires only noncurrent versions after 90 days. Add an explicit
  current-object retention policy as a separately reviewed change before long-term
  operation; current costs will otherwise grow with backup volume.
- `force_destroy=false` intentionally prevents deleting populated backup buckets.
  Routine compute shutdown must preserve them and the separate Terraform state.
- During failback, newly written Region B database data needs its own backup and
  transfer back to A. This one-way replication does not implement failback.

## Local checks

Run backend-free initialization in a fresh checkout (or a dedicated temporary
`TF_DATA_DIR` if your working directory already caches a live backend):

```bash
terraform fmt -check -recursive
terraform -chdir=infra/envs/region-a init -backend=false -lockfile=readonly
terraform -chdir=infra/envs/region-a validate
terraform -chdir=infra/envs/region-a test
terraform -chdir=infra/envs/region-b init -backend=false -lockfile=readonly
terraform -chdir=infra/envs/region-b validate
terraform -chdir=infra/envs/region-b test
```

The Terraform tests mock AWS; they neither create resources nor prove live
replication. CI runs them after validation.

## Live deployment evidence: 2026-11-25 UTC

After explicit approval, the saved Region B plan created seven resources: the
recovery bucket and its six storage/security settings. The subsequent plan
reported no changes. Versioning, AES256 encryption and all public-access blocks
were verified on `cybershield-backups-079754672968-us-east-2`.

The approved Region A plan was scoped exceptionally to `module.replication`:
three resources were added, with none changed or destroyed. This scope preserved
the repaired primary EC2 while adding the S3 service role, inline policy and
replication rule. The rule is enabled for `postgres/`, targets the recovery
bucket and disables delete-marker replication.

A fresh backup was generated on the existing primary EC2 after enabling the
rule. It uploaded at 02:58:01 UTC. Its manifest key is
`postgres/postgres-20261125T025759884147Z-47aeb5e5.json`; the corresponding dump
is 2,975 bytes and the manifest is 302 bytes. Both source objects reported
`COMPLETED`, and both destination objects reported `REPLICA`. A download from
Region B verified the dump size and SHA-256 against its manifest at
02:59:05 UTC. These observations do not establish the exact replication latency
or constitute a measured full DR exercise.

The existing primary instance `i-0aabe1d8be3ce01e1` was not replaced; its public
health endpoint still returned HTTP 200. A full Region A plan was reviewed after
the targeted apply: it still proposes replacement due to corrected user data,
plus updates to the two instance-dependent alarms. Those changes were not
approved or applied. Do not interpret the scoped apply as complete regional
idempotence or routinely use targeting to bypass review.

Recovery compute, restoration from this actual replicated backup, failover and
failback remain separate milestones. Older source backups created before the
replication rule were not backfilled by this deployment.

References:
- [AWS replication permissions](https://docs.aws.amazon.com/AmazonS3/latest/userguide/setting-repl-config-perm-overview.html)
- [What S3 replicates](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-what-is-isnot-replicated.html)
- [S3 pricing](https://aws.amazon.com/s3/pricing/)
