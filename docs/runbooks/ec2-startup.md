# Primary EC2 application startup

Region A renders the existing app files into EC2 user data. No GitHub credentials
or runtime Git checkout are required. The x86_64 Amazon Linux 2023 host installs
Docker and the pinned Compose plugin, verifies the plugin release checksum, and
starts the existing app with systemd. Docker image/package downloads require
outbound Internet access. The Compose plugin installation follows
https://docs.docker.com/compose/install/linux/.

The host generates a random PostgreSQL password in `/opt/cybershield/.env`
(root-only, mode 0600). It is not supplied to Terraform or written in user data.
Root and Docker administrators can access container secrets. The app maps host
port 80 to container port 8000; PostgreSQL has no published port. The app source
and database schema are unchanged. Container logs rotate locally; CloudWatch
ingestion and scheduled database backups are separate work.

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
until verified backup/restore exists. The primary password is host-local;
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
