# Security decisions and scanner exceptions

The VM uses IMDSv2, an encrypted gp3 root disk and SSM rather than public SSH.
PostgreSQL is reachable only inside the Compose network. The app runs as an
unprivileged container user; the image build excludes runtime `.env`. Passwords
are generated on the host, root-readable only, and do not enter Terraform state.
Root/Docker administrators can inspect container credentials; this is part of
the project's self-managed VM responsibility. Never collect full container
inspection or `.env` in public evidence.

S3 buckets are versioned, encrypted, block public access, enforce bucket-owner
ownership and reject non-HTTPS requests. The new recovery state bucket is also
protected against Terraform destroy. Backups and state use separate buckets.
New role boundaries exclude state and IAM mutation from workloads. Deployment
trust is tied to an exact repository/environment and protected main, with
separate read/lock and deployment identities.

The default HTTP allowlist is loopback. Set real demo client CIDRs before apply.
Port 80 is explicitly accepted for this non-sensitive minimal demonstration;
there is no login or real student data. A production deployment requires TLS,
an appropriate domain/certificate and authentication review, not real records
over public HTTP. Subnets no longer auto-assign public IPs: only the demo VM
explicitly requests one. Internet egress is limited to TCP 443; the VPC resolver
handles DNS. No unrestricted all-protocol egress remains.

## Narrow Trivy exceptions

The CI scanner still fails all other HIGH/CRITICAL findings. Exceptions are
inline on the relevant resources, not a blanket ignore file:

| Check | Accepted design and consequence |
|---|---|
| AWS-0132 | AES256/SSE-S3 encryption is retained instead of customer-managed KMS. This meets encrypted-storage requirements without per-key cost and cross-region KMS policies. It lacks customer-managed key revocation/auditing controls. |
| AWS-0104 | HTTPS egress to dynamic AWS/GitHub/container-registry addresses is required for a reproducible VM bootstrap without NAT/proxy infrastructure. Egress is TCP 443 only. This does not prevent HTTPS data exfiltration if the host is compromised. |
| AWS-0095 | SNS contains non-sensitive operational alarm metadata only; no student records or credentials. Customer-managed KMS would add cost and require CloudWatch-to-SNS key policies. Sensitive messages would require changing this decision. |

Review these as deliberate tradeoffs, not proof that all risks were eliminated.
Seven-day CloudWatch retention and bounded local log rotation limit retained
test information. Current backups expire after seven days in A and fourteen in
B; noncurrent retention is separate. Lifecycle expiration is asynchronous and
versioned bytes can remain until the noncurrent period ends. The plan must be
reviewed before shortening existing retention.

Only restore trusted archives. A checksum detects corruption, not an attacker
who can rewrite both dump and manifest. The app is fenced during restore and a
transaction rolls back SQL failures. Failback creates a persistent writer-fence
marker before stopping B, so a reboot does not reopen writes accidentally.
If abandoning failback, verify A is fenced/off before deliberately removing that
marker and restarting B; never let both copies accept divergent writes.

The existing demo Compose app uses the PostgreSQL initialization/maintenance
user for its constant read queries. It is not a production least-privilege DB
account design; a production service should separate a read-only application
role from backup/restore administration. There is no arbitrary SQL or student
input endpoint in the minimal demonstration. IAM least-privilege changes do not
magically reduce SQL privileges inside PostgreSQL.
