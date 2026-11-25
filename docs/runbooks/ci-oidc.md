# CI and GitHub OIDC foundation

> Current code uses `infra/envs/dr` and `scripts/tf.sh`; follow
> [shared-root adoption](shared-root.md) and [workflow setup](github-actions.md).
> Earlier root-directory commands and recorded deployment evidence below are
> historical. No existing state is automatically migrated by the refactor.

## Current scope

CI checks formatting, initializes providers without a backend, and validates
bootstrap and both regional roots. Terraform is pinned to 1.17.2 in CI; the
existing Terraform/provider constraints and committed lock files are retained.
No plan or apply runs in Pull Requests. No AWS credentials are needed for CI.

Bootstrap currently defines only the GitHub OIDC provider and identity-only role.
It does not create the state bucket or paid application infrastructure. Bootstrap
uses local state temporarily: never commit it, keep a secure copy, and migrate
it to the future S3 backend. Regional S3 backends and use_lockfile are still pending.

## 1. Test CI

Push these changes to a branch and open a PR targeting main. Expect three
successful Terraform validation jobs. After merge, Actions > Terraform CI >
Run workflow also works. Manual workflows must exist on the default branch
before GitHub displays the Run workflow button.

Local equivalent, for each of infra/bootstrap, infra/envs/region-a and
infra/envs/region-b:

```bash
terraform -chdir=infra/bootstrap fmt -check -recursive
terraform -chdir=infra/bootstrap init -backend=false -input=false -lockfile=readonly
terraform -chdir=infra/bootstrap validate
```

## 2. Refresh your local AWS session

```bash
aws login --profile cybershield
aws sts get-caller-identity --profile cybershield
export AWS_PROFILE=cybershield
```

Check the returned account privately. Local login and GitHub OIDC are separate
sessions. The project session was expired during local inspection; neither the
AWS budget nor existing account resources could be verified.
Before paid infrastructure, verify the USD 10 monthly budget and its 50%, 80%,
and 100% notifications in AWS Budgets.

## 3. Review the identity bootstrap

The provider and role have no hourly infrastructure charge. No EC2, storage,
or database is created by this configuration.
Use an authorized local identity that can manage the project's IAM resources.
Check for existing resources first:

```bash
aws iam list-open-id-connect-providers --profile cybershield
aws iam get-role --role-name CyberShieldGitHubActionsRole --profile cybershield
terraform -chdir=infra/bootstrap init -input=false -lockfile=readonly
terraform -chdir=infra/bootstrap plan
```

An existing GitHub provider is account-wide: do not create a duplicate. If it
exists, review ownership and its audiences/tags before deciding whether to import
it or reference it as existing infrastructure. Apply is deliberately not automated.
Review the plan with the team and explicitly approve it before applying.
The expected new-resource plan contains exactly one OIDC provider and one IAM
role. No permission policies are attached. STS GetCallerIdentity requires no
identity policy, so AdministratorAccess and ReadOnlyAccess are unnecessary.

After an approved apply, retrieve the role ARN:

```bash
terraform -chdir=infra/bootstrap output -raw github_actions_role_arn
```

## 4. Configure GitHub repository variables

A teammate with repository administration access should open Settings > Secrets
and variables > Actions > Variables and create:

| Variable | Value |
| --- | --- |
| AWS_ROLE_ARN | ARN from the Terraform output |
| AWS_REGION | us-east-1 |

The ARN is not a secret. Do not add AWS access keys to GitHub.
Merge aws-auth.yml into main, then open Actions > AWS OIDC authentication >
Run workflow and select main. Expect Account and an assumed-role ARN containing
CyberShieldGitHubActionsRole. This is the end-to-end authentication proof;
local Terraform validation cannot exercise GitHub's token exchange.

## Trust boundary and troubleshooting

The trust policy uses exact StringEquals conditions for audience sts.amazonaws.com
and subject repo:nicohf2022@104432397/cybershield-academy@1458857174:ref:refs/heads/main.
PR tokens, forks and other branches do not match. The main branch should be
protected with reviews. Any workflow on main granted id-token permission can
request this role; this is currently acceptable because it has no resource
permissions. Deployments will need separate roles and approval boundaries.

If OIDC fails, check repository variables, role trust policy, the main branch,
and id-token: write. If the repository uses a customized OIDC subject template,
match the actual configured subject rather than broadening the trust wildcard.
If a GitHub Environment is added later, its subject becomes
repo:OWNER@OWNER_ID/REPO@REPO_ID:environment:ENVIRONMENT; update the trust and environment
protections together before testing it.

References:
- [GitHub OIDC with AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)
- [AWS credentials action](https://github.com/aws-actions/configure-aws-credentials)
- [GetCallerIdentity permissions](https://docs.aws.amazon.com/STS/latest/APIReference/API_GetCallerIdentity.html)

## Remaining foundation work

After identity authentication succeeds: create the S3 state backend with
versioning, encryption, public access blocking and deletion protection; enable
use_lockfile and separate regional state keys. Then add TFLint, security scans,
read-only PR plans with comments, least-privilege deployment roles, approved
apply and manual destroy. Failover/failback remain later milestones.

Existing regional tags use Project/Team/Environment/Owner rather than the
required lowercase project/team/env/owner, and region validations currently fix
the two provisional regions. Address these before infrastructure deployment.

## Immutable subject diagnosis

The repository API reports `use_immutable_subject: true`. Confirm its exact prefix:

```bash
gh api repos/nicohf2022/cybershield-academy/actions/oidc/customization/sub
```

Terraform uses `github_oidc_subject_prefix` from `sub_claim_prefix` and appends
`:ref:refs/heads/main`. The former name-only trust policy rejected these tokens.
Review a fresh Terraform plan, approve and apply the role trust update, then
rerun the authentication workflow. No workflow or GitHub variable change is needed.

See [GitHub immutable subject documentation](https://docs.github.com/en/actions/reference/security/oidc).
