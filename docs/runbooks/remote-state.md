# Remote Terraform state bootstrap

Trello: [Crear bootstrap del state remoto](https://trello.com/c/v5rMJJaj)

## What this step does

Terraform state maps configuration addresses to AWS resources. A shared S3
backend lets teammates use the same state. S3 versioning retains older copies;
`use_lockfile = true` prevents concurrent Terraform operations on a state key.
The lock is a temporary `.tflock` object, separate from `.terraform.lock.hcl`,
which pins provider packages. No DynamoDB table is needed.

Read-only inspection on 2026-11-19 found that
`cybershield-tfstate-079754672968` already exists in `us-east-1`, is empty,
has versioning enabled, blocks all public access and uses AES256 encryption.
It was not tracked by the current bootstrap state. Explicit Terraform imports
adopt the bucket and its three settings. Its existing lowercase tags are preserved.
`prevent_destroy = true` blocks Terraform deletion while the resource block
remains present; `force_destroy = false` also prevents automatic object cleanup.
This is not protection against deletion outside Terraform or removal of its code.

The reviewed plan showed **4 imports, 0 additions, 0 changes, 0 deletions**.
No new paid resources are planned. S3 charges for stored data, versions and API
requests still apply; tiny state files and light use should cost pennies monthly
(an estimate, not a spending cap). Do not place database backups in this bucket.

## 1. Review and adopt the existing bucket

Run from the repository root using the machine that holds the existing bootstrap
state for the OIDC provider and IAM role. Do not start bootstrap from an empty
state on another machine.

```bash
export AWS_PROFILE=cybershield
aws sts get-caller-identity
terraform -chdir=infra/bootstrap init -lockfile=readonly
terraform -chdir=infra/bootstrap plan -out=remote-state.tfplan
```

Inspect the plan and obtain explicit approval before applying:

```bash
terraform -chdir=infra/bootstrap apply remote-state.tfplan
terraform -chdir=infra/bootstrap state list
terraform -chdir=infra/bootstrap plan -detailed-exitcode
```

Expect six managed resources (two existing IAM resources and four S3 resources),
and an unchanged second plan (exit code 0). A saved plan must be regenerated if
configuration or state changes. Keep local state and plan files private.

## 2. Initialize the regional backends

The committed `backend.hcl` files use separate keys:

| Root | S3 object key |
| --- | --- |
| Region A | region-a/terraform.tfstate |
| Region B | region-b/terraform.tfstate |

Both backend regions are `us-east-1`, because that is the bucket's location.
The application provider for Region B still uses `us-east-2`. Backend settings
cannot reference Terraform variables, so non-secret bucket/key/region values
are supplied via a small HCL file. Never add credentials to these files.

After the bucket adoption is approved and completed:

```bash
terraform -chdir=infra/envs/region-a init -migrate-state -backend-config=backend.hcl
terraform -chdir=infra/envs/region-b init -migrate-state -backend-config=backend.hcl
terraform -chdir=infra/envs/region-a plan
terraform -chdir=infra/envs/region-b plan
```

Review any migration prompt before answering yes. If a root has no local state,
initialization simply selects the backend; an S3 state object may not exist until
Terraform first persists state. The regional roots currently define no resources.
Do not run apply merely to create an empty state file. On a fresh checkout,
normal `init -backend-config=backend.hcl` is sufficient.

CI deliberately uses `init -backend=false`, so PR validation remains independent
of AWS credentials and remote state access. The identity-only GitHub role still
has no S3 permissions; do not use it for backend initialization yet.

## 3. Move bootstrap state to S3 as a separate approved step

Once adoption succeeds, securely back up the bootstrap state outside Git. The
prepared `infra/bootstrap/backend.tf` contains:

```hcl
terraform {
  backend "s3" {}
}
```

Then migrate using the prepared bootstrap settings:

```bash
terraform -chdir=infra/bootstrap init -migrate-state -backend-config=backend.hcl
terraform -chdir=infra/bootstrap state list
terraform -chdir=infra/bootstrap plan -detailed-exitcode
```

Confirm the copy prompt only after reviewing the destination. Never use
`-reconfigure` instead of `-migrate-state` to move existing local state.
Bootstrap uses `bootstrap/terraform.tfstate`; do not reuse a regional key.
Keep the bucket when destroying application environments.

## Permissions and evidence

Backend access requires `s3:ListBucket` on the state bucket,
`s3:GetObject`/`s3:PutObject` on each authorized state key, and
`s3:GetObject`/`s3:PutObject`/`s3:DeleteObject` on its `.tflock` key.
DeleteObject is not required on the state file itself. Future CI roles should
be scoped to their intended keys. Backend permissions do not grant permission
to deploy AWS resources.

Save the PR link, adoption plan/apply summary, successful migration output,
and unchanged plan as evidence. The acceptance criteria are not fully verified
until the approved imports, state migrations and a controlled concurrent-operation
lock check have run. Never delete a lock object or force-unlock an active run.

The state bucket is intentionally in the primary region per the project plan.
It is not replicated by this change. A complete regional failure can therefore
also affect access to state; resolve and document this limitation before the DR
exercise rather than claiming state is already disaster resilient.

References:
- [HashiCorp S3 backend and lock permissions](https://developer.hashicorp.com/terraform/language/backend/s3)
- [S3 pricing](https://aws.amazon.com/s3/pricing/)

## Controlled lock verification after bootstrap migration

In terminal 1, from the repository root:

```bash
export AWS_PROFILE=cybershield
terraform -chdir=infra/bootstrap console
```

Leave the console open at its prompt. It holds the state lock. In terminal 2:

```bash
export AWS_PROFILE=cybershield
terraform -chdir=infra/bootstrap plan -lock-timeout=5s
```

Expect an error acquiring the state lock. Save that output as evidence, then
type `exit` in terminal 1 so Terraform releases the lock normally. Rerun the
plan in terminal 2; it must succeed and report no changes. Do not use
`-lock=false`, force-unlock or manually delete the lock object.
