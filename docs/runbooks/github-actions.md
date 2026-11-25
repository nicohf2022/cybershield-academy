# GitHub Actions deployment setup

All cloud resources are declared in Terraform. Local AWS credentials and
GitHub OIDC are independent; no permanent access key belongs in Actions secrets.
The existing identity-only role still cannot deploy. New automation roles are
opt-in bootstrap resources, not silently attached administrator permissions.

1. Review `infra/bootstrap/automation.tfvars.example`. Supply both regions, their
   name prefixes and correct regional state buckets. The recovery state bucket
   must exist and migration must be verified before DR automation is enabled.
2. Supply real budget recipient addresses privately if adopting the existing
   budget through the conditional import. Do not create a second budget. Review
   the import, permissions boundary and policies before explicitly approving any
   bootstrap apply. Existing workload roles need the project boundary during
   the reviewed adoption before handing deployment to CI.
3. Create GitHub environments `plan-region-a`, `plan-region-b`, `region-a`, and
   `region-b`. Deployment environments must require a reviewer and use a custom
   branch policy permitting **only `main`**. Prevent self-review where available.
   Protect main with reviews and required CI. Plan environments can allow trusted
   same-repository PR branches; fork PRs get static checks without AWS credentials.
4. Per plan environment set `AWS_PLAN_ROLE_ARN` and `AWS_REGION`. Per deployment
   environment set `AWS_DEPLOY_ROLE_ARN`, `AWS_REGION` and `BACKUP_S3_PREFIX` from
   approved Terraform outputs. The roles trust exact immutable repository IDs
   plus the corresponding environment subject, not wildcard branches or forks.
5. Repository variables: `AWS_WORKLOAD_BOUNDARY_ARN`, `ALLOWED_HTTP_CIDRS` as a
   JSON list and `RECOVERY_BACKUP_S3_PREFIX`. Values are configuration, not secrets.
   Set allowed CIDRs for the intended demo clients. Do not commit real passwords.

Missing roles, unset inputs or missing reviewer/main-only protection fail closed.
GitHub environment capabilities depend on repository visibility/account plan;
verify reviewer support before enabling automated apply. If protection is not
available, use explicitly reviewed local saved-plan applies instead; do not
remove the workflow protection check to make deployment run.

## Workflows

- `ci.yml`: format all Terraform, TFLint, Trivy high/critical checks, actionlint,
  mock Terraform tests, disposable Docker database tests and plan-guard tests.
  Trusted PRs also get OIDC-authenticated plans and resource-only PR comments.
  The summary deliberately excludes values and startup payloads. Plan roles can
  read their regional state, project backups and configuration and can write
  only transient lock objects; they cannot deploy infrastructure or change state.
- `deploy.yml`: on main merge, plans storage B then primary A. Each apply requires
  its environment approval. Manual deployment can pin a restore manifest and
  permit ephemeral replacement; push deployment refuses destructive changes.
- `terraform-operation.yml`: reusable plan/apply pipeline. It uploads the saved
  plan, digest and summary; apply verifies the digest and uses that exact plan.
  Another state update invalidates a stale plan. A plan artifact is sensitive:
  restrict repository access and retain it only one day. No `-target` is used.
- `destroy.yml`: manually plans compute teardown for one chosen region while
  preserving backups, replication and state. Save a final backup before approving.
- `failover.yml`: verifies declared isolation of primary writes, recovery-backend
  independence and a fresh checksum-verified recovery backup, then restores B and
  runs SSM health/marker checks. Explicit reviewer approval is still required.
- `failback.yml`: protected approval to fence B's writer and disable its timer,
  take a final backup, plan/approve restoring A, verify the B marker in A, then
  plan/approve removing B compute. Bucket B stays. If restoration fails, B stays
  fenced; do not unfreeze it while A could accept writes.

All Terraform operations share a per-region concurrency group and state locking.
Environment approval time counts toward measured failover RTO. Saved plans can
become stale while waiting; regenerate and review rather than bypass locks.
The deployment role is limited to named project IAM roles/policies, project
storage, logs, dashboards/alarms, regional EC2 operations and project SSM targets.
Workload boundaries prevent those roles gaining IAM/state access through inline
policy changes. Some EC2 creation/read APIs require wildcard resources; review
the explicit action list and region/tag conditions before live use. Initial
legacy uppercase-tag adoption must use the approved local owner session; do not
broaden CI mutation rights to unrelated old lab resources.

After bootstrap review, validate generated policies with IAM Access Analyzer
`validate-policy` as well as Terraform. Mock tests check schema, size and trust,
but do not prove every AWS authorization path or OIDC token exchange. Actual
workflow runs, approvals, cold boot and teardown evidence are still required.

Recovery IAM is global readiness infrastructure owned by bootstrap, with no
hourly compute cost. Populate Region B's `precreated_instance_profile_name`
from the approved bootstrap output before disaster. The recovery root does not
manage or refresh that IAM role; it references the existing profile name without
reading bootstrap state. This avoids a new IAM control-plane dependency during
failover. Keep the profile through compute teardown. Regional B normally retains
only S3 storage; the supporting global IAM identities already exist.

Bootstrap is deliberately staged: with `enable_workflow_roles=false`, provision
only reviewed prerequisites such as the boundary, recovery profile and state
storage. Use the authorized owner session to adopt primary workload boundaries,
lowercase tags and the pinned-restore replacement. Only then explicitly approve
`enable_workflow_roles=true` to create CI trust roles. This avoids giving CI
inline-policy mutation access to a legacy project role without its boundary.
CI tagging cannot relabel unrelated EC2 resources into the project: tag-on-create
uses `ec2:CreateAction`, and subsequent tagging requires an existing project tag.
