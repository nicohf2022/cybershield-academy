# FinOps report and measurement method

Status: budget and alerts verified; project-attributable billing evidence and
calculator export still pending. Do not present the assignment's USD 1–5 example
as a measured bill or assume free-tier/academic credit eligibility.

## Budget and operations

The existing `CyberShield-Monthly-USD10` budget is USD 10/month, with actual-spend
notifications at 50%, 80% and 100%. Confirm both team recipients and current
credit eligibility in the account. Conditional bootstrap import lets Terraform
adopt this budget after real recipient addresses are supplied privately and the
plan is approved. It does not create a duplicate or impose an automatic cutoff.

Keep B compute disabled outside an exercise. At each session end, take a final
verified backup and apply the reviewed `enable_compute=false` plan for any active
region. Merely stopping EC2 retains billable EBS. The teardown workflow preserves
state and backup data and removes the hourly VM/root disk. Save evidence first.
Current backups expire after 7 days in A and 14 in B; noncurrent versions remain
for their configured period. Versioning is not a storage-cost cap.

## Estimate assumptions (reviewed 2026-11-25)

For illustrative US East Linux t3.micro pricing, published rates are $0.0104/hour
for EC2 and $0.005/hour per public IPv4. Twelve GiB gp3 at an assumed regional
$0.08/GiB-month adds $0.96 for a full month. For 730 hours:

- EC2: `730 × 0.0104 = $7.592`.
- IPv4: `730 × 0.005 = $3.65`.
- Assumed gp3: `12 × 0.08 = $0.96`.
- Base total: **about $12.20/month**, excluding CPU-credit surcharges, S3,
  replication, data transfer, monitoring, notifications, taxes and credits.

For 20 aggregate VM-hours of demonstration, EC2 plus IPv4 is about $0.31 before
prorated EBS and other services. A second VM during recovery adds its own hours.
These are calculations under stated assumptions, not actual cost or an AWS quote.
Recheck selected regions, credits and price calculator before presenting them.

Production projection should specify 730 primary VM-hours, measured average dump
size × backups/day × retention in each region (plus noncurrent versions), measured
replication volume, expected egress, logs/alarms/dashboard charges and demand-driven
compute sizing. A larger production database may outgrow t3.micro; measure memory,
CPU credits and restore time rather than projecting a demo VM as a production SLA.

## Actual cost collection

```bash
AWS_PROFILE=cybershield python3 scripts/finops.py \
  --start 2026-11-01 --end 2026-11-25 --output artifacts/account-costs.json
```

Use an end date appropriate to available billing data; end is exclusive. Cost
Explorer may require enablement/permissions and charges per API request. The
export is explicitly account-wide because unrelated lab resources exist. Activate
project cost-allocation tags and reconcile resource IDs/launch hours; historical
uppercase tags and billing delay limit attribution. Export the billing console
or calculator evidence and record the observation date. Do not label unrelated
lab costs as CyberShield or commit sensitive billing exports by default.

| Required evidence | Current status |
|---|---|
| Budget, thresholds and team recipients | Budget/thresholds verified; recipient evidence to collect |
| Session compute hours and actual attributable bill | Pending billing/resource reconciliation |
| Production calculator estimate | Method and base calculation above; calculator export pending |
| Post-session compute/root disk removal | Workflow implemented; approved execution/evidence pending |
| Backup/log retention | Declared in code; adoption apply pending |

Sources: [EC2 T3](https://aws.amazon.com/ec2/instance-types/t3/),
[public IPv4](https://aws.amazon.com/vpc/pricing/),
[gp3 assumptions](https://aws.amazon.com/ebs/pricing/),
[S3](https://aws.amazon.com/s3/pricing/),
[CloudWatch](https://aws.amazon.com/cloudwatch/pricing/).

## Actual export observation

On 2026-11-25, Cost Explorer returned 24 daily estimated periods for
2026-11-01 through 2026-11-24 UTC (end date 2026-11-25 exclusive), with 26
service groups and an account-level UnblendedCost sum of USD 0.00. This is
provisional API data, not a finalized invoice or a project-attributed total.
Most CyberShield deployment happened on 2026-11-25 UTC and is outside that
closed-date export; billing delay and credits must be reconciled. Re-export
after usage is available and separate unrelated lab resources. The private raw
export was kept under `/tmp`, not committed to the repository.
