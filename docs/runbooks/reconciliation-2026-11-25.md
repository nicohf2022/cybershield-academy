# Approved reconciliation — 2026-11-25 UTC

The user explicitly approved the three infrastructure adoption stages. No state
migration or GitHub workflow-role activation was included.

## Applied and verified

- Bootstrap: 14 resources created, none changed/deleted. The independent recovery
  state bucket, workload boundary and precreated recovery profile now exist.
  `automation_role_arns` remains empty: workflow roles are deliberately disabled.
- Region B: existing backup storage tags/retention updated (two actual resource
  changes after the computed policy resolved unchanged). No compute created.
- Primary: four resources added, sixteen actually changed, three removed. The
  three removals were the old EC2, unrestricted HTTP rule and broad CloudWatch
  managed-policy attachment. VPC/subnet/buckets were preserved. Resource address
  moves were recorded by Terraform, not manually edited in state.

Before replacement, primary writes and automatic startup were disabled. A final
backup uploaded at 04:21:57 UTC, with manifest:
`postgres/postgres-20261125T042155638858Z-5f9a4282.json`.
Its dump was downloaded and checksum-verified from both regions before the old
instance was deleted. The source had three lessons, with a deterministic
whole-table fingerprint `5a65c0e73eb9fa6a8981e3dbd200bd0d`.

The new primary is `i-0befa5567aeba9bcf`, replacing `i-0aabe1d8be3ce01e1`.
Its public address at verification was `44.195.85.85`; access is limited to the
approved development IP `186.50.122.117/32`. Do not assume this address survives
future stop/start or replacement.

Cloud-init finished successfully at 04:27:58 UTC (about 125 seconds after boot).
The pinned backup restored before app start. The restored three-row fingerprint
exactly matched the source. Both localhost and public `/health` returned HTTP
200. The app, CloudWatch Agent and hourly timer are active; the initial backup
service completed successfully. The new host produced backup
`postgres/postgres-20261125T042755954807Z-5ae8d346.json`.
Its dump reported `COMPLETED` in A; both dump and manifest reported `REPLICA`
in B, verifying that replication still works with the new role boundaries.
CloudWatch received app, database, backup and restore streams. The dashboard
`cybershield-primary-overview` exists, and log retention is seven days.

This was approved maintenance/adoption, not a timed regional-outage exercise.
It proves a fresh primary bootstrap and restoration of a real S3 backup; it does
not establish full regional failover/failback or measured DR RTO/RPO.

## Reproduce the no-change plans

After deployment, bootstrap and both regional configurations returned detailed
plan exit code 0 (no changes), using their applied input values.

Bootstrap stage-one settings were saved locally in ignored
`infra/bootstrap/terraform.tfvars` if that file did not already exist. Preserve
that configuration and use the canonical bootstrap backend. Do not omit its
region definitions or enable workflow roles without the next explicit review.

Primary deployment values, including the restore manifest, boundary ARN and
allowlist, are in ignored local file
`.terraform-data/deployment-inputs/region-a.tfvars.json`. These are deployment
inputs, not database passwords. Keep a private team copy; this file is not
available in a fresh checkout. Use the same values for a meaningful drift check:

```bash
export AWS_PROFILE=cybershield
bash scripts/tf.sh region-a init
bash scripts/tf.sh region-a plan \
  -var-file="$PWD/.terraform-data/deployment-inputs/region-a.tfvars.json"
bash scripts/tf.sh region-b init
bash scripts/tf.sh region-b plan
```

Do not accidentally omit the primary restore input on later plans: it is part
of the deployed startup payload, so changing it can propose replacement.
Likewise, changing CIDRs or dropping the boundary is a real configuration change,
not drift to suppress. Configure corresponding workflow variables/manifest inputs
during the separately reviewed GitHub setup.

## Still separate

Region B state still uses its original bucket/key in Region A. The new recovery
state bucket exists but is not active. Migration requires a coordinated window
with the teammate and separate explicit approval. Workflow-role activation,
GitHub environment/reviewer configuration, budget recipient adoption, actual
regional DR, alarm-trigger evidence and final compute teardown remain pending.
