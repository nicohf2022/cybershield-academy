# IAM permissions matrix

| Identity | Trust and scope | Permissions and justification |
|---|---|---|
| Local authorized bootstrap owner | Human-authenticated temporary AWS session | Adopt existing resources, provision state/IAM/budget. Not used by application or PR code. Review every bootstrap change. |
| Existing identity-only GitHub role | Exact immutable repository subject on main | STS identity proof only. Kept separate from deployment. |
| Regional plan roles | Exact repository plus `plan-region-a`/`plan-region-b` environment | Read regional state/project configuration and trusted backup data; create/delete only the regional lock object. EC2 discovery is region-scoped. No state-file writes or infrastructure mutation. |
| Regional deployment roles | Exact repository plus protected main-only `region-a`/`region-b` environment | Write its regional state; specific EC2/network/IAM/S3/log/SNS/CloudWatch lifecycle actions. Project names, region and resource tags constrain mutations. Cannot mutate its own automation role, workload boundary policy, budget or state-bucket infrastructure. Cannot delete backup buckets. |
| EC2 role (B preprovisioned in bootstrap) | EC2 service principal, named instance profile | SSM agent channels; write logs only to project log group; upload/read `postgres/` objects in its backup bucket. Optional read-only restore-source bucket access. No state access. |
| S3 replication role | S3 service principal | Read source replication metadata and `postgres/` object versions/ACLs/tags; replicate objects/tags only to destination prefix. No replica deletion, compute or state access. |
| Workload permissions boundary | Applied to EC2 and replication roles by reviewed deployment | Maximum project backup/log/SSM permissions; no IAM, state or infrastructure mutation. Actual policies must also allow an operation. |
| SNS recipients | Explicit email subscription confirmation | Receive operational alarm metadata; not application records. |

Discovery APIs such as EC2 Describe and Logs DescribeLogGroups need wildcard
resources. These are limited to read actions, with region conditions where
supported. Creation APIs have AWS multi-resource authorization requirements;
review the explicit action lists in `infra/bootstrap/automation.tf`. Initial
legacy-tag adoption is performed by the approved owner, not by relaxing CI to
control unrelated lab resources. Plan roles can read sensitive backup/state data;
only trusted team PRs may obtain them. Fork PRs receive static checks only.

Generated policies are tested for AWS size limits and exact OIDC environment
trust. Live IAM Access Analyzer validation and deployment/SSM authorization tests
remain required before calling the new roles operational. The existing local
IAM users and any unrelated lab resources are not silently imported or changed.
