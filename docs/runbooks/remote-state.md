# Remote Terraform state

> Current code uses `infra/envs/dr` and `scripts/tf.sh`; follow
> [shared-root adoption](shared-root.md) and [workflow setup](github-actions.md).
> Earlier root-directory commands and recorded deployment evidence below are
> historical. No existing state is automatically migrated by the refactor.

Trello: [Crear bootstrap del state remoto](https://trello.com/c/v5rMJJaj)

## What this step does

Terraform state maps configuration addresses to AWS resources. A shared S3
backend lets teammates use the same state. S3 versioning retains older copies;
`use_lockfile = true` prevents concurrent Terraform operations on a state key.
The lock is a temporary `.tflock` object, separate from `.terraform.lock.hcl`,
which pins provider packages. No DynamoDB table is needed.

Read-only inspection found that `cybershield-tfstate-079754672968` already
exists in `us-east-1`, has versioning enabled, blocks all public access and uses
AES256 encryption. There are currently no objects under the `region-a/` and
`region-b/` prefixes. This is expected before Terraform first persists each
regional state. The bucket bootstrap state is managed separately from the
regional roots and must only be operated from the machine that holds its
canonical local state.

## Current regional state status

The Region A and Region B S3 backends are configured with independent object
keys. Both roots have been initialized successfully with `-reconfigure` and
their committed `backend.hcl` files, and both Terraform configurations validate.
The Region A root defines the primary infrastructure stack. The Region B root
currently contains its backend and provider configuration and will be completed
as the recovery environment in a later step.

This verifies the backend configuration, not the complete runtime behavior of
two physical states. Neither regional `terraform.tfstate` object exists yet.
`use_lockfile = true` is configured for both roots, but concurrent lock behavior
has not been tested. The controlled lock test remains pending for the later card
that validates `apply`, idempotence and `destroy`.

The bucket's existing lowercase tags are preserved.
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
export AWS_PROFILE=<your-aws-profile>
aws sts get-caller-identity
terraform -chdir=infra/bootstrap init -lockfile=readonly
terraform -chdir=infra/bootstrap plan -out=remote-state.tfplan
```

The profile used in the current local environment is `cybershield-dev`. Profile
names are machine-specific and must not be stored in backend configuration.

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
The application provider for Region A uses `us-east-1`, while the application
provider for Region B uses `us-east-2`. Backend settings cannot reference
Terraform variables, so non-secret bucket/key/region values are supplied via a
small HCL file. Never add credentials to these files.

Initialize or reconfigure each regional backend with a local AWS profile:

```bash
export AWS_PROFILE=<your-aws-profile>
terraform -chdir=infra/envs/region-a init -reconfigure -backend-config=backend.hcl
terraform -chdir=infra/envs/region-b init -reconfigure -backend-config=backend.hcl
terraform -chdir=infra/envs/region-a validate
terraform -chdir=infra/envs/region-b validate
```

If a root has no local state, initialization simply selects the backend. Its S3
`terraform.tfstate` object may not appear until Terraform persists state for the
first time, normally during the first `apply`. Do not create an empty state file
manually and do not run `apply` merely to make the object appear. On a fresh
checkout, normal `init -backend-config=backend.hcl` is sufficient.

The successful initialization and validation establish that each root targets
its intended independent key. Full separation remains operationally unproven
until both physical state objects exist and the controlled lock test succeeds.

CI deliberately uses `init -backend=false`, so PR validation remains independent
of AWS credentials and remote state access. The identity-only GitHub role still
has no S3 permissions; do not use it for backend initialization yet.

## 3. Move bootstrap state to S3 as a separate approved step

This regional-state workflow does not initialize or migrate bootstrap state.
That process depends on canonical local state managed by another team member and
must remain a separate, explicitly approved operation on the machine that owns
that state. When its owner performs that future step, the prepared
`infra/bootstrap/backend.tf` contains:

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

Save the PR link, initialization output and validation output as configuration
evidence. The regional backends are configured and validated, but physical state
separation is not fully verified until both states have been persisted and a
controlled concurrent-operation lock check has run. Never delete a lock object
or force-unlock an active run.

The state bucket is intentionally in the primary region per the project plan.
It is not replicated by this change. A complete regional failure can therefore
also affect access to state; resolve and document this limitation before the DR
exercise rather than claiming state is already disaster resilient.

References:
- [HashiCorp S3 backend and lock permissions](https://developer.hashicorp.com/terraform/language/backend/s3)
- [S3 pricing](https://aws.amazon.com/s3/pricing/)

## Controlled regional lock verification after the first apply

Run this only during the later `apply`, idempotence and `destroy` validation
card, after the selected regional state exists. The Region A commands below are
an example; repeat the controlled check for Region B with its own root and state
key.

In terminal 1, from the repository root:

```bash
export AWS_PROFILE=<your-aws-profile>
terraform -chdir=infra/envs/region-a console
```

Leave the console open at its prompt. It holds the state lock. In terminal 2:

```bash
export AWS_PROFILE=<your-aws-profile>
terraform -chdir=infra/envs/region-a plan -lock-timeout=5s
```

Expect an error acquiring the state lock. Save that output as evidence, then
type `exit` in terminal 1 so Terraform releases the lock normally. Rerun the
plan in terminal 2; it must succeed and report no changes. Do not use
`-lock=false`, force-unlock or manually delete the lock object.
