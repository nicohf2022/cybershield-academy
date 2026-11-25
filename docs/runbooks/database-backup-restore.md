# PostgreSQL backups and restoration

The Python 3.9+ script `app/scripts/database.py` uses the existing Docker Compose
`db` service. PostgreSQL clients run inside that container, so no host PostgreSQL
installation or Python packages are needed. AWS CLI is required only for S3.
This change creates no AWS resources and does not change Terraform state.

## Compose project selection

Every command must target the same Compose project that started the database.
The script defaults to `cybershield`, matching the EC2 startup service. The local
app README uses Compose's default directory name, normally `app`; use
`--project app` for that existing local environment. Do not start a new stack
with a different project name expecting to see the old volume's data.

The database must already be running and healthy. Passwords are read from the
container environment and never supplied as host command-line arguments. Do not
source `.env` as a shell script. Normal AWS CLI credential selection applies:
use `AWS_PROFILE=cybershield` locally and the instance role on EC2.

## Local backup

From the repository root, for a local stack started from the `app` directory:

```bash
python3 app/scripts/database.py --project app backup
```

The default output directory is `app/.backups/` (ignored by Git and Docker).
Alternatively pass `--output-dir /private/backup/directory` after `backup`.
The JSON log prints the manifest path. Each backup consists of:

- A compressed custom-format `.dump`, containing schema, rows and sequences.
- A `.json` manifest with SHA-256, byte count, UTC dump-start lower bound and
  dump completion timestamp. A unique timestamp/ID prevents overwrites.

Files created by the script are private (0600), new directories use 0700.
The source application's writes can continue during `pg_dump`.
The script verifies the archive table of contents before publishing a manifest.
Local backups are retained until deliberately removed; monitor disk space.

## S3 backup

Use an existing private backup bucket, never the Terraform state bucket:

```bash
AWS_PROFILE=cybershield python3 app/scripts/database.py --project app backup \
  --s3-prefix s3://YOUR-PRIMARY-BACKUP-BUCKET/postgres
```

The dump uploads first, then its manifest. A failure returns a nonzero exit code.
S3-only backups use temporary disk space that is removed afterward. Add
`--output-dir` if you also want to retain a local copy, including on upload
failure. A killed process may leave temporary files or orphan dump objects.
Bucket encryption, public access blocking, lifecycle and replication remain
Terraform responsibilities. Backups add storage, request and replication costs;
this script does not create or configure buckets or replication.

## Restore (explicit replacement)

Restore only trusted project backups. First stop external/manual writers and
make a fresh safety backup of any valuable destination data. The script stops
the Compose app after verifying the archive, but cannot fence other hosts or
manual database clients. Run only one recovery operation across the team.

```bash
python3 app/scripts/database.py --project app restore \
  --manifest /absolute/path/postgres-TIMESTAMP-ID.json --replace
```

For the latest backup replicated to Region B:

```bash
AWS_PROFILE=cybershield python3 app/scripts/database.py --project app restore \
  --latest s3://YOUR-RECOVERY-BACKUP-BUCKET/postgres \
  --replace --max-age-hours 2
```

You can also supply a specific S3 `.json` URI to `--manifest`. Download and
checksum verification happen before the app is stopped or data is changed.
Latest selection uses the UTC snapshot-start filename, not S3 modification time.
Cross-region replication may deliver the manifest before its dump: a missing or
corrupt dump fails closed; the script does not silently select an older backup.
Retry after replication completes or deliberately select a reviewed older one.

Restore uses `pg_restore --clean --if-exists --single-transaction --exit-on-error`.
An SQL restoration error rolls back the database changes and leaves the app
stopped. Object ownership and grants are not restored, allowing a destination
with a different database user/password. Restore replaces objects present in the
archive; it does not delete unrelated tables absent from it. Use a fresh
destination for DR rather than mixing divergent databases.

The script checks that `public.lessons` is readable and logs its row count.
Compare unique test records/content as well: a count alone is not proof of
business-data integrity. Add `--start-app` to start the app after a successful
restore, or start it manually after inspecting the recovered records:

```bash
docker compose --project-directory app --project-name app up -d --no-deps app
curl --fail http://localhost:8000/health
```

`--start-app` starts containers; verify `/health` separately before declaring
recovery complete. Omit the flag when only the destination database is ready.
No Docker volume is deleted by backup or restore. A shared per-project file
lock prevents overlapping script operations on the same host; it is not a
distributed lock. SHA-256 detects accidental corruption, not malicious changes
by someone who can replace both dump and manifest.

## Hourly EC2 scheduling

Region A's startup template now installs the script, Python, AWS CLI and units,
configures the primary backup prefix, runs an initial backup and enables the
timer after it succeeds. This still requires a reviewed plan and explicitly
approved deployment; local tests do not prove EC2 execution. Files are embedded
with gzip compression to stay within EC2's user-data size limit.

For an existing host, install only after the EC2 app and its backup bucket are
available. Copy `database.py` to `/opt/cybershield/scripts/` and both files under
`app/systemd/` to `/etc/systemd/system/`. The instance needs Python 3.9+, Docker
Compose and AWS CLI available to root; verify these first.

Create `/etc/cybershield-backup.env` with mode 0600:

```dotenv
BACKUP_S3_PREFIX=s3://YOUR-PRIMARY-BACKUP-BUCKET/postgres
AWS_DEFAULT_REGION=us-east-1
```

Do not put AWS access keys in this file. Use the EC2 IAM role. It needs
`s3:PutObject` on the backup prefix. Restore additionally needs `s3:GetObject`
and bucket `s3:ListBucket` for latest selection (and version actions if later
implementing version-specific recovery). Existing bucket-wide permissions can
be narrowed in the separate IAM workstream.

On the EC2 host, run a manual backup successfully before enabling scheduling:

```bash
sudo systemctl daemon-reload
sudo systemctl start cybershield-backup.service
sudo journalctl -u cybershield-backup.service --no-pager
sudo systemctl enable --now cybershield-backup.timer
sudo systemctl list-timers cybershield-backup.timer
```

The timer runs hourly with up to 30 seconds' jitter and catches up once after
downtime. It does not retry every failed upload automatically. Logs go to the
system journal; CloudWatch collection and backup-failure/staleness alerts remain
separate work. Disable the timer before a planned primary restore/failback:
`sudo systemctl stop cybershield-backup.timer` and wait for any active backup
service to finish. Re-enable only after the primary is healthy again.

## Evidence and limitations

`snapshot_not_before` is captured just before invoking `pg_dump`, so it is a
conservative snapshot-time bound, not the last committed transaction timestamp.
Hourly dumps imply a data-loss window around one hour plus dump/upload and
replication delay; missed runs increase it. Record the simulated incident time,
restored manifest and successful application verification separately for RPO/RTO.
This is logical database recovery, not continuous WAL/PITR recovery.

Tests:

```bash
python3 -m unittest discover -s app/scripts -p 'test_*.py' -v
RUN_DOCKER_TESTS=1 python3 -m unittest discover -s app/scripts -p 'test_*.py' -v
```

The Docker test creates two disposable Compose projects, verifies a marker row
and identity sequence restore under a different database owner, rejects corrupt
backups and removes only its own containers/volumes. Real S3 upload/replication
and EC2 timer execution require separate AWS verification.

References: [pg_dump](https://www.postgresql.org/docs/17/app-pgdump.html),
[pg_restore](https://www.postgresql.org/docs/17/app-pgrestore.html).
