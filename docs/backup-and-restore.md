# Backup and Restore

Backups run automatically — no user interaction needed. Works with both Docker Compose and Kubernetes deployments using the same shared scripts.

## How It Works

- A scheduled job runs on a cron schedule
- Each backup creates a timestamped folder containing:
  - `database.sql.gz` — full Postgres dump
  - `forgejo-data.tar.gz` — repos, config, avatars, LFS, attachments
  - `backup.info` — metadata (timestamp, database name)
- Old backups are automatically deleted after the retention period (default: 30 days)

## Configuration

### Docker Compose

Set these in your `.env` file:

| Variable | Default | Description |
|---|---|---|
| `BACKUP_CRON` | `0 3 * * *` | Cron schedule (default: daily at 3 AM) |
| `BACKUP_KEEP_DAYS` | `30` | Delete backups older than this |

### Kubernetes

Edit `BACKUP_KEEP_DAYS` in `k8s/backup-cronjob.yml` and the schedule in the `spec.schedule` field.

### Cron schedule examples

```
0 3 * * *        # Daily at 3 AM
0 */6 * * *      # Every 6 hours
0 3 * * 0        # Weekly on Sunday at 3 AM
0 3 1 * *        # Monthly on the 1st at 3 AM
```

## Manual Backup

### Docker Compose

```bash
docker exec forgejo-backup sh /backup.sh
```

### Kubernetes

```bash
kubectl create job --from=cronjob/forgejo-backup manual-backup -n forgejo
kubectl logs -n forgejo -f job/manual-backup
kubectl delete job manual-backup -n forgejo
```

## Restore

### Docker Compose

```bash
# List backups
ls backups/

# Restore latest
docker compose run --rm backup sh /scripts/restore.sh

# Restore specific
docker compose run --rm backup sh /scripts/restore.sh 20260620_030000

# Restart
docker compose restart forgejo
```

### Kubernetes

```bash
# List backups
kubectl run ls-backups --rm -it --restart=Never -n forgejo \
  --overrides='{"spec":{"containers":[{"name":"ls","image":"alpine","command":["ls","/backups"],"volumeMounts":[{"name":"b","mountPath":"/backups"}]}],"volumes":[{"name":"b","persistentVolumeClaim":{"claimName":"forgejo-backups"}}]}}'

# Restore latest
kubectl apply -f k8s/restore-job.yml
kubectl logs -n forgejo -f job/forgejo-restore

# Restore specific (edit BACKUP_NAME in restore-job.yml first)

# Restart
kubectl rollout restart deploy/forgejo -n forgejo

# Clean up restore job
kubectl delete job forgejo-restore -n forgejo
```

## Moving to a New Host

1. Copy the backups to the new host:

   ```bash
   scp -r backups/YYYYMMDD_HHMMSS user@newhost:/path/to/project/backups/
   ```

2. On the new host, set up the stack (Docker or K8s)

3. Create the admin user

4. Run the restore

5. Restart Forgejo

## Upgrading Forgejo

1. Trigger a manual backup (see above)

2. Update the image version:
   - Docker: edit `compose.yml`
   - K8s: edit `k8s/forgejo.yml`

3. Restart:
   - Docker: `docker compose up -d`
   - K8s: `kubectl apply -f k8s/forgejo.yml`

4. If something breaks, restore from the backup
