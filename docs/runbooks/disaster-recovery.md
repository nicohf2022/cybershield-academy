# DR exercise: failover, failback and measurement

## Acceptance targets

| Measure | Target | Actual |
|---|---|---|
| Failover RTO, incident declaration through recovered marker/health verification | At most 20 minutes, including provisioning and approval delay | Pending full exercise |
| RPO snapshot-age upper bound at incident declaration | At most 75 minutes with successful hourly backups and replication | Pending full exercise |
| Data integrity | Known pre-incident marker exists in B; B-written failback marker exists in A | Local logical round-trip verified; full regional markers pending |

Targets are proposed course acceptance criteria, not an SLA. The snapshot-start
timestamp is a conservative lower bound on snapshot time. The resulting age is
not an exact count of lost transactions; compare marker records as well. Capture
real incident UTC time rather than omitting it when timing matters.

## Prerequisites

Complete the reviewed [shared-root adoption](shared-root.md), independent recovery
state migration and [OIDC/environment setup](github-actions.md). Confirm a recent
dump AND manifest have replicated, recipients confirm SNS, costs are within
budget, A is healthy and B compute is disabled. Back up any valuable data first.
Use only synthetic records. Do not destroy a region to simulate an outage.

The full simulated outage must prove B provisioning reads no primary-region
state or APIs. Source A being stopped for a demo is only a failure simulation;
document that limitation honestly. Do not claim a real AWS regional outage.

## Prepare the data and incident

1. In A, insert a distinctive synthetic lesson with a slug such as
   `dr-before-incident-20261125`. Use SSM and psql inside the existing db container,
   without exposing `.env`. Save the slug, row timestamp and a minimal query result.
2. Run a fresh database backup. Observe both object statuses as `COMPLETED` in A
   and `REPLICA` in B. Older source backups are not automatically backfilled.
3. Record a UTC timestamp and the URL currently serving A. Fence primary writes
   before using B. For a controlled demo, stop the app or host through an
   explicitly approved action; choose a method that does not delete data.
   Keep it isolated until failback, including across reboots. Record exactly what
   failure was simulated and what AWS services were still reachable.
4. Optionally insert a second marker after the selected backup but before fencing
   to demonstrate the data-loss window. Explain why that row may be absent in B.

## Drill worksheet

Agree before recording who operates AWS and who records UTC timestamps, checks
the markers, and reviews the deployment. Start recording before inserting the
first marker. When switching writers, have the recorder confirm the old writer
is fenced before announcing that the new endpoint is ready.

| Event | UTC time | Evidence to capture |
|---|---|---|
| Marker inserted in A | — | Slug, row timestamp and query result |
| Selected snapshot started | — | Manifest URI, snapshot timestamp, dump size and SHA-256 |
| Both backup objects available in B | — | Source `COMPLETED` and destination `REPLICA` statuses |
| Incident declared and A fenced | — | Declaration timestamp, fencing method and confirmation |
| B healthy with A's marker | — | B endpoint, health and marker results, workflow link |
| B-only marker inserted | — | Slug, row timestamp and query result |
| B fenced and final backup verified | — | Fence confirmation and exact final manifest URI |
| A healthy with B's marker | — | A endpoint, health and marker results, workflow link |
| B compute removed | — | Teardown run and EC2/EBS inventory |

Calculate failover RTO from incident declaration to verified B health and
marker. Calculate the snapshot-age upper bound from the selected snapshot
timestamp to declaration. Report marker presence separately and keep the
recording link with the workflow artifacts.

## Failover

1. Actions → **Failover to recovery region** → main. Confirm primary isolation,
   supply the known marker and actual incident ISO timestamp.
2. The plan job rejects a Region A-dependent B backend, selects the latest trusted
   complete manifest in B, verifies the dump hash/size and rejects backups over
   two hours old. It pins that exact URI; it does not select a different dump
   while applying. Missing/corrupt/partially replicated data fails closed.
3. Review the plan artifact and approve Region B's protected environment. Expect
   B compute/network/IAM/monitoring additions with the existing bucket preserved.
4. Startup creates a host-local password, starts only db, restores the pinned
   logical dump, then starts app and backup scheduling. Failure leaves recovery
   unverified; do not direct users to it.
5. Automated SSM checks wait for cloud-init, require HTTP/database health and
   verify the known marker. Read `deployment-results-region-b/result.json`.
   RTO includes approval delay. The RPO field is explicitly a snapshot-age upper
   bound; failed or future/post-incident snapshot timings are not reported as
   successful RPO measurements.
6. Show Region B's application URL from its Terraform output, verify records
   manually and record when the demo URL was communicated to users. No DNS
   service is required; Route 53 automation is optional.

## Failback

1. While B is active, create a unique B-only marker. Confirm primary remains
   isolated and will not serve writes while recovery is prepared.
2. Trigger **Failback to primary** on main with that marker. Approve fencing B:
   it writes `.writer-fenced`, disables the timer, waits for active backup work,
   stops the web app and takes a final backup. The persistent fence prevents the
   app service starting after a reboot. Stop any other/manual database writers.
3. Verify the final backup selection belongs to this freeze operation and is
   uploaded. Review/approve A's restore plan. A may require replacement for
   corrected user data; the pinned restore URI and explicit ephemeral-delete
   permission are required. Passwords/roles are host-local, not copied from B.
4. Health and the B-only marker must pass in A. Only then move the demo URL back.
5. Review/approve B compute teardown. Bucket B and state remain. Save outputs,
   logs and resource-removal evidence. A remains the sole writer.

If anything fails after fencing B, do not casually remove the fence: A might
already be serving writes. Inspect both sides and select one authoritative writer.
To deliberately abandon failback, ensure A is off/fenced before removing
`/opt/cybershield/.writer-fenced`, starting B's service and re-enabling its timer.
Never merge diverged PostgreSQL databases by blindly replaying both dumps.

## Observability and teardown evidence

CloudWatch contains Docker app/db streams and backup/restore file streams, with
seven-day retention. The dashboard shows CPU, status checks and error/backup logs.
Confirm a subscription, deliberately trigger an alarm in a controlled test and
save its history and received notification. A manual `SetAlarmState` tests the
notification path only; separately demonstrate a real metric-driven transition.
For example, temporarily plan a low CPU threshold/evaluation period or run a
bounded CPU load after approval, then restore the normal configuration. CPU load
can affect the demo and incur T3 credit charges; do not leave it running.

For an alarm rehearsal before the DR drill, recent five-minute CPU averages on
November 25 were about 1.53%–1.88%. After both email subscriptions are confirmed,
check the latest samples, then review a Terraform plan that changes only the
primary high-CPU alarm threshold to 1%. Keep the existing two evaluation periods
if both recent samples exceed 1%. Capture the metric-driven `OK` → `ALARM`
transition and both SNS receipts, then restore the 80% threshold with another
reviewed plan and capture the return to `OK`.

Record the simulator screen and UTC clock from incident declaration through
verified recovery and failback. Retain workflow URLs, plan/apply summaries,
manifest names, checksums, marker queries, result JSON, alarm evidence, cost
export and final compute inventory. Do not include secrets or database dumps in
public evidence. Upload the actual video link to the course deliverables; no
recording or measured DR success exists merely because this runbook is written.

At session end, take a final verified backup, save evidence and use the approved
compute teardown workflow for each active region. Check EC2 and EBS inventories
and the regional plans. Keep state and required backups; deliberate total data
purge is a separate approval. Rehearse early enough to allow cold bootstrap and
approval latency; a successful short video is not a substitute for the timed
results or a failed live run.
