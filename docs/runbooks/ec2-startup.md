# Primary EC2 application startup

> Current code uses `infra/envs/dr` and `scripts/tf.sh`; follow
> [shared-root adoption](shared-root.md) and [workflow setup](github-actions.md).
> Earlier root-directory commands and recorded deployment evidence below are
> historical. No existing state is automatically migrated by the refactor.

Region A renders the existing app files into EC2 user data. No GitHub credentials
or runtime Git checkout are required. The x86_64 Amazon Linux 2023 host installs
Docker and pinned Compose/Buildx plugins, verifies their release checksums, and
starts the existing app with systemd. Docker image/package downloads require
outbound Internet access. The Compose plugin installation follows
https://docs.docker.com/compose/install/linux/.
Buildx is required to build the application's Dockerfile with Compose; Amazon
Linux's Docker package does not include it. Its installation follows
https://github.com/docker/buildx#manual-download.

The host generates a random PostgreSQL password in `/opt/cybershield/.env`
(root-only, mode 0600). It is not supplied to Terraform or written in user data.
Root and Docker administrators can access container secrets. The app maps host
port 80 to container port 8000; PostgreSQL has no published port. The app source
and database schema are unchanged. Container logs rotate locally; CloudWatch
ingestion remains separate work. Startup now installs the database backup/restore
script, takes an initial S3 backup and enables the hourly timer; see the
[backup runbook](database-backup-restore.md). Files are gzip-compressed in user data.

## Before deployment

- Coordinate Region A changes with the other student.
- Confirm budget and review EC2, public IPv4, EBS, S3 and monitoring costs.
- Set `allowed_http_cidrs` to the demo participants' public IPv4 CIDRs.
- Resolve the recovery backend's dependency on Region A before the DR exercise.
- Review a Terraform plan and obtain explicit approval before apply.

User data runs at first boot. The existing compute module replaces the instance
when user data changes, including embedded application files. The root volume is
deleted on termination: Docker persistence survives container/host restarts,
but not instance replacement. Do not replace an instance with valuable data
until a recent backup and its restoration have been verified. The primary password is host-local;
recovery must use logical dumps and deliberately handle database ownership.

## Verify after an approved deployment

Retrieve `instance_id` and `instance_public_ip` from the regional outputs. Use
AWS Systems Manager Session Manager (no SSH ingress is required):

```bash
aws ssm start-session --profile cybershield --region us-east-1 --target INSTANCE_ID
```

On the host:

```bash
sudo cloud-init status --wait
sudo systemctl status cybershield --no-pager
sudo journalctl -u cybershield --no-pager -n 100
sudo docker compose --project-directory /opt/cybershield --project-name cybershield ps
curl --fail http://127.0.0.1/health
```

From an allowed client, check `http://PUBLIC_IP/health` and open
`http://PUBLIC_IP/`. Expect HTTP 200 and the seeded database records. Verify a
test record survives a host reboot and the service starts automatically.
SSM requires a functioning agent, outbound connectivity, an authorized caller,
and the local Session Manager plugin. Do not display `.env` or full container
inspection output when collecting evidence.

For installation errors inspect `/var/log/cloud-init-output.log`. The systemd
service retries application startup failures; failures earlier in user data
must be diagnosed before manually rerunning the script. No live EC2 startup
has been verified merely by Terraform validation.

## Repairing failed first boot without replacing EC2

Two installation failures were identified on the primary instance:

- Compose's checksum names `docker-compose-linux-x86_64`. Download under that
  exact name, verify it, then rename the executable to `docker-compose`.
- Compose image builds need Buildx. Install and verify that plugin before
  starting `cybershield.service`.

The corrected startup template can be rendered and run through an explicitly
authorized SSM command after inspecting existing containers and volumes. It
preserves an existing `.env` and does not delete database volumes. Do not enable
shell tracing or include secret values in diagnostic output. Do not blindly
rerun startup over an unrelated or divergent app installation.

An in-place repair does not update EC2's originally stored user data or Terraform
state. With `user_data_replace_on_change=true`, a future plan can propose
instance replacement for this source correction. Review that plan and protect
the database before approving replacement; do not hide the difference with
`ignore_changes` or edit Terraform state to suppress it. Historical cloud-init
failure status can remain after a successful SSM repair; check the application
service, health endpoint and backup service directly for current runtime status.

### Live verification: 2026-11-25 UTC

An authorized in-place SSM repair completed on the existing primary instance
`i-0aabe1d8be3ce01e1`, without Terraform apply or EC2 replacement. The health
check now retries transient empty responses while Gunicorn starts.

- Public and localhost `/health` returned HTTP 200 with `status=ok`.
- The app container was running and PostgreSQL reported healthy.
- `cybershield.service` reported `Result=success` and was enabled at boot.
- The initial backup uploaded at 02:35:15 UTC. Its manifest is
  `postgres/postgres-20261125T023512762761Z-4d5ef830.json` in the primary backup
  bucket. A separate local download verified the dump's SHA-256 and 2,975-byte size.
- `cybershield-backup.service` reported `Result=success`; being inactive after
  completion is normal for this oneshot service.
- The hourly timer was enabled and active, with its next run scheduled for
  03:00:26 UTC. A scheduled run and reboot persistence have not yet been observed.

This verifies the repaired running host and one real S3 backup. It does not
prove a fresh first boot, cross-region replication or restoration of this actual
backup. Region B deployment remains a separate explicitly approved step.
