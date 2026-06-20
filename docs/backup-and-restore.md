# Backup and Restore

Backups run automatically — no user interaction needed. A dedicated container handles scheduling, rotation, and cleanup.

## How It Works

- A lightweight Alpine container runs a cron job on a schedule
- Each backup creates a timestamped folder in `./backups/` containing:
  - `database.sql.gz` — full Postgres dump
  - `forgejo-data.tar.gz` — repos, config, avatars, LFS, attachments
  - `backup.info` — metadata (timestamp, database name)
- Old backups are automatically deleted after the retention period

## Configuration

Set these in your `.env` file:

| Variable | Default | Description |
|---|---|---|
| `BACKUP_CRON` | `0 3 * * *` | Cron schedule (default: daily at 3 AM) |
| `BACKUP_KEEP_DAYS` | `30` | Delete backups older than this |

### Cron schedule examples

```env
BACKUP_CRON=0 3 * * *        # Daily at 3 AM
BACKUP_CRON=0 */6 * * *      # Every 6 hours
BACKUP_CRON=0 3 * * 0        # Weekly on Sunday at 3 AM
BACKUP_CRON=0 3 1 * *        # Monthly on the 1st at 3 AM
```

## Where Data Lives

| Path | Contents |
|---|---|
| `./data/forgejo/` | Live Forgejo data (repos, config, avatars, LFS) |
| `./data/postgres/` | Live Postgres database files |
| `./backups/` | Timestamped backup snapshots |

All on the host filesystem — easy to copy, rsync, or move.

## Manual Backup

To trigger a backup outside the schedule:

```bash
docker exec forgejo-backup sh /backup.sh
```

## Restore

### List available backups

```bash
ls backups/
```

### Restore the latest backup

```bash
docker compose run --rm backup sh /restore.sh
```

### Restore a specific backup

```bash
docker compose run --rm backup sh /restore.sh 20260620_030000
```

### Restart after restore

```bash
docker compose restart forgejo
```

## Moving to a New Host

1. On the old host, copy the latest backup:

   ```bash
   scp -r backups/YYYYMMDD_HHMMSS user@newhost:/path/to/HomeGit/backups/
   ```

   Or copy the entire project:

   ```bash
   scp -r HomeGit/ user@newhost:/path/to/
   ```

2. On the new host, update `.env` with the new domain/settings

3. Start the stack:

   ```bash
   docker compose -f compose.yml -f compose.prod.yml up -d
   ```

4. Create the admin user:

   ```bash
   docker exec --user git forgejo forgejo admin user create \
     --admin --username YOUR_USER --password YOUR_PASSWORD --email YOUR_EMAIL
   ```

5. Restore the backup:

   ```bash
   docker compose run --rm backup sh /restore.sh
   docker compose restart forgejo
   ```

6. Log in — all repos, users, and settings are restored

## Upgrading Forgejo

Before upgrading the Forgejo image version:

1. Trigger a manual backup:

   ```bash
   docker exec forgejo-backup sh /backup.sh
   ```

2. Update the image tag in `compose.yml`

3. Recreate:

   ```bash
   docker compose up -d
   ```

4. If something breaks, restore:

   ```bash
   docker compose run --rm backup sh /restore.sh
   docker compose restart forgejo
   ```
