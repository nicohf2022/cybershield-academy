# CyberShield Academy — executive summary

CyberShield is a UCU cloud infrastructure demonstration for an academy that
needs a credible response to loss of its primary cloud region. Its business
question is whether a minimal learning page and its PostgreSQL records can be
recovered without continuously paying for a second running server.

The solution uses pilot light. Region A runs the page and database on one small
VM; hourly logical backups are stored in private encrypted object storage and
replicated to Region B. B normally contains only the recovery data. At a declared
incident, an approved workflow creates a temporary recovery VM, restores a
verified backup and checks a known record before users move to its URL. Failback
fences recovery writes, takes a final backup and restores the primary before
removing recovery compute.

The proposed targets are recovery within 20 minutes and a backup snapshot age
no greater than 75 minutes at incident declaration, assuming successful hourly
backups, completed replication and prompt approval. These are exercise targets,
not guarantees. Full RTO/RPO measurements are still pending. One real primary
backup and its Region B replica have been downloaded and checksum-verified.

The cost objective is a USD 10 monthly alert budget, small synthetic data and
compute only during sessions. Keeping the primary VM and public IP running all
month would exceed that budget before monitoring/storage extras; teardown is
part of the operating procedure. Actual attributable costs must be exported and
reconciled; academic credits must not be assumed.

Main risks are stale/failed backups, asynchronous replication, unavailable state,
external download dependencies, reviewer delay, host replacement losing local
data and human error during failback. Current mitigations include private/versioned
buckets, least-scope roles, pinned/checksummed manifests, approval gates, writer
fencing, restore-before-start and compute teardown preserving data. Remaining
acceptance work includes approved adoption/state migration, cold boot, complete
failover/failback, alarm evidence, cost reporting and a recorded timed demo.
