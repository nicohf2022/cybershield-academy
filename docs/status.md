# Assignment coverage and evidence status

The shared-root adoption and approved stage-one prerequisites are now deployed.
The replacement primary cold-booted, restored a real backup with an exact data
fingerprint match, and sends logs to CloudWatch. All three applied configurations
have no-change plans with their deployment inputs. See the
[dated reconciliation evidence](runbooks/reconciliation-2026-11-25.md).
This does not claim that all acceptance tests or regional DR have run.

| Requirement | Status |
|---|---|
| Minimal app, containers and database-backed page | Existing implementation; primary HTTP/database health verified |
| Hourly backup mechanism and source-to-recovery CRR | Existing implementation; one manually triggered real backup/replica checksum verified; scheduled-run evidence still required |
| One region-parameterized application root | Deployed with separate inputs/state keys and moved addresses; bucket/VPC/subnet preserved |
| Remote state, locking, versions and module boundaries | Existing remote states/locks declared; new root uses same keys; controlled lock test pending |
| Independent recovery state | Recovery bucket deployed; state migration is not approved/performed and B still depends on A state |
| Reproducible startup/recovery and compute flags | Primary cold boot and real backup restore verified; no-change post-apply plans verified; regional recovery compute still untested |
| Tags, restricted ingress/egress, scoped IAM | Approved adoption applied; workload boundaries and precreated recovery profile deployed; CI trust roles remain disabled |
| PR checks/scanning and plans/comments | Workflow code and local scanner checks implemented; actual new CI/OIDC runs pending |
| Main deployment, approved apply, manual teardown | Implemented with saved plans, deletion guard and protection checks; environment/role setup and executions pending |
| Failover and failback | Implemented; full exercise, writer fencing and regional marker proof pending |
| Logs, dashboard, alarm | Dashboard and app/db/backup/restore log ingestion verified; existing alarms retargeted; real alarm-trigger evidence pending |
| Budget and recipients | Existing USD 10 thresholds verified; Terraform adoption and team-recipient evidence pending |
| FinOps | Calculation, export tool and report provided; a provisional account-level Cost Explorer observation recorded; attributable billing/calculator evidence pending |
| Architecture, IAM, responsibility and executive summary | Documents supplied; team review pending |
| RTO/RPO and recording | Targets/instrumentation/runbook provided; actual measurements and recording pending |
| Presentation and destroy evidence | Outline provided; rehearsal and approved teardown/evidence pending |

The user separately approved bootstrap, Region B storage and primary replacement
after the code-editing task. Those three applies are complete. State migration,
workflow-role activation, Git push/merge and unbounded destruction were not part
of that approval. No-change plans and runtime evidence above were verified after
the real applies; mock tests alone are not deployment proof.
