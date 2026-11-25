# Assignment coverage and evidence status

Deployment status follows the team's November 25, 2026 handoff. The primary app
and PostgreSQL ran on EC2, and a primary instance replacement restored all three
test records from a real backup. The regional failover and failback exercise is
still pending.

| Requirement | Status |
|---|---|
| Minimal app, containers and database-backed page | Existing implementation; primary HTTP/database health verified |
| Hourly backup mechanism and source-to-recovery CRR | November 25 13:00 UTC backup verified: manifest and dump were `COMPLETED` in A and `REPLICA` in B, and the 2,975-byte replica passed SHA-256 verification |
| One region-parameterized application root | Deployed with separate regional inputs and state keys; no-change plans reported with the deployed parameters |
| Remote state, locking, versions and module boundaries | On November 25, 2026 a second Region B plan was blocked by the first plan's S3 lock; the first plan reported no changes and released the lock normally |
| Independent recovery state | Region B state migrated to `us-east-2` on November 25, 2026; nine state entries preserved, no changes in the post-migration plan, both locks released |
| Reproducible startup/recovery and compute flags | Verified primary cold-start restore; recovery cold start remains part of the regional exercise |
| Tags, restricted ingress/egress, scoped IAM | Private, encrypted, versioned buckets and primary HTTP restricted to the approved CIDR; live GitHub OIDC permission checks pending |
| PR checks/scanning and plans/comments | Workflow code and local scanner checks implemented; actual new CI/OIDC runs pending |
| GitHub OIDC bootstrap | Applied four roles and six supporting policy resources with zero updates or deletions; GitHub environment setup and token exchange pending |
| Main deployment, approved apply, manual teardown | Implemented with saved plans, deletion guard and protection checks; environment/role setup and executions pending |
| Failover and failback | Implemented; full exercise, writer fencing and regional marker proof pending |
| Logs, dashboard, alarm | Dashboard and alarms working at baseline; Terraform added two primary SNS email subscriptions with zero other changes; both confirmations and the metric-driven alarm test are pending |
| Budget and recipients | USD 10 budget with two email subscribers at each of the 50%, 80% and 100% thresholds; inbox receipt pending |
| FinOps | Billing `project` tag active; November 1–24 query returned no project-tagged service groups; AWS Calculator EC2/EBS baseline exported at USD 8.55/month, with workload-dependent costs pending |
| Architecture, IAM, responsibility and executive summary | Documents supplied; team review pending |
| RTO/RPO and recording | Targets/instrumentation/runbook provided; actual measurements and recording pending |
| Presentation and destroy evidence | Outline provided; rehearsal and approved teardown/evidence pending |

Teammates with a cached Region B backend must refresh it using the verified
configuration in the [shared-root runbook](runbooks/shared-root.md).
