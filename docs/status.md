# Assignment coverage and evidence status

This records the code changes, not a claim that all acceptance tests have run.
The earlier verified deployment has primary app/DB, one real backup/replica and
protected data buckets. The new shared-root, CI identities, logging/dashboard and
recovery changes have **not** been applied or run end-to-end.

| Requirement | Status |
|---|---|
| Minimal app, containers and database-backed page | Existing implementation; primary HTTP/database health verified |
| Hourly backup mechanism and source-to-recovery CRR | Existing implementation; one manually triggered real backup/replica checksum verified; scheduled-run evidence still required |
| One region-parameterized application root | Implemented with separate inputs/state keys and moved blocks; adoption plan/apply pending |
| Remote state, locking, versions and module boundaries | Existing remote states/locks declared; new root uses same keys; controlled lock test pending |
| Independent recovery state | Opt-in protected bucket configuration and migration instructions implemented; deployment/migration not approved or performed |
| Reproducible startup/recovery and compute flags | Implemented, mock-tested; fresh-boot restore and no-change second apply pending |
| Tags, restricted ingress/egress, scoped IAM | Implemented in new code; real adoption/security review still required |
| PR checks/scanning and plans/comments | Workflow code and local scanner checks implemented; actual new CI/OIDC runs pending |
| Main deployment, approved apply, manual teardown | Implemented with saved plans, deletion guard and protection checks; environment/role setup and executions pending |
| Failover and failback | Implemented; full exercise, writer fencing and regional marker proof pending |
| Logs, dashboard, alarm | New log delivery/dashboard code; existing alarm resources; log ingestion/real triggering/evidence pending |
| Budget and recipients | Existing USD 10 thresholds verified; Terraform adoption and team-recipient evidence pending |
| FinOps | Calculation, export tool and report provided; a provisional account-level Cost Explorer observation recorded; attributable billing/calculator evidence pending |
| Architecture, IAM, responsibility and executive summary | Documents supplied; team review pending |
| RTO/RPO and recording | Targets/instrumentation/runbook provided; actual measurements and recording pending |
| Presentation and destroy evidence | Outline provided; rehearsal and approved teardown/evidence pending |

No new apply, destroy, state migration, push or PR merge was authorized by this
code-editing task. The working tree must be reviewed before choosing deployment
steps. Read-only plans and mock tests do not create infrastructure.
