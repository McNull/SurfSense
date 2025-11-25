# Volume Management

This document describes the volume structure and management for the SurfSense production deployment.

## Volume Structure

All volumes use bind mounts to local directories for easier backup, restore, and management:

```
./volumes/
├── postgres_data/    # PostgreSQL database files
├── pgadmin_data/     # pgAdmin configuration and settings
├── redis_data/       # Redis persistence files
└── shared_temp/      # Shared temporary files between services
```

## Volume Creation

Volume directories are automatically created when you first start the services:

```bash
docker compose up -d
```

Or create them manually:

```bash
mkdir -p volumes/{postgres_data,pgadmin_data,redis_data,shared_temp}
```

## Permissions

### Overview

Volume directories will be created with default permissions. Depending on your deployment environment, you may need to adjust permissions for proper access by the containerized services.

### Common Issues

If you encounter permission errors, try:

```bash
# Option 1: Set ownership to your user
sudo chown -R $USER:$USER volumes/

# Option 2: Set broader permissions (less secure, but sometimes necessary)
chmod -R 755 volumes/
```

### Container User Mapping

Different services run as different users inside containers:
- **PostgreSQL**: Runs as user `postgres` (UID 999)
- **pgAdmin**: Runs as user `pgadmin` (UID 5050)
- **Redis**: Runs as user `redis` (UID 999)
- **Backend/Frontend**: May run as root or specific user depending on Dockerfile

If you experience persistent permission issues, you may need to match host directory ownership with container UIDs.

## Data Persistence

All data is stored in bind-mount directories, which means:
- ✅ Data persists across container restarts
- ✅ Data survives `docker compose down`
- ✅ Easy to backup (just copy the directories)
- ✅ Easy to inspect (directly browse files)
- ⚠️ Data is NOT automatically removed by Docker

## Backup and Restore

### PostgreSQL Database Backup

#### Using pg_dump (Recommended)

```bash
# Backup to SQL file
docker compose exec db pg_dump -U postgres surfsense > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup in custom format (compressed)
docker compose exec db pg_dump -U postgres -Fc surfsense > backup_$(date +%Y%m%d_%H%M%S).dump
```

#### Using volume directory backup

```bash
# Stop the database first
docker compose stop db

# Backup the volume
tar -czf postgres_backup_$(date +%Y%m%d_%H%M%S).tar.gz volumes/postgres_data/

# Restart the database
docker compose start db
```

### PostgreSQL Database Restore

#### From SQL dump

```bash
# Restore from SQL file
cat backup_20250125_120000.sql | docker compose exec -T db psql -U postgres surfsense

# Restore from custom format
cat backup_20250125_120000.dump | docker compose exec -T db pg_restore -U postgres -d surfsense
```

#### From volume backup

```bash
# Stop services
docker compose down

# Remove old data
rm -rf volumes/postgres_data/*

# Restore backup
tar -xzf postgres_backup_20250125_120000.tar.gz

# Start services
docker compose up -d
```

### Redis Backup

Redis uses AOF (Append-Only File) persistence:

```bash
# Trigger Redis to save
docker compose exec redis redis-cli BGSAVE

# Backup the volume
tar -czf redis_backup_$(date +%Y%m%d_%H%M%S).tar.gz volumes/redis_data/
```

### Full System Backup

Backup all volumes at once:

```bash
# Stop services (optional, but safer)
docker compose stop

# Create backup
tar -czf surfsense_volumes_backup_$(date +%Y%m%d_%H%M%S).tar.gz volumes/

# Restart services
docker compose start
```

### Automated Backups

Consider setting up automated backups with cron:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /path/to/deploy && docker compose exec db pg_dump -U postgres -Fc surfsense > /backups/surfsense_$(date +\%Y\%m\%d).dump
```

## Volume Migration

### From Named Volumes to Bind Mounts

If migrating from the development setup (named volumes) to production (bind mounts):

1. **Backup data from named volumes:**
   ```bash
   # Start with old compose file
   docker compose up -d

   # Backup database
   docker compose exec db pg_dump -U postgres -Fc surfsense > migration_backup.dump

   # Stop old setup
   docker compose down
   ```

2. **Switch to production setup:**
   ```bash
   cd deploy/

   # Start fresh (will create bind-mount directories)
   docker compose up -d

   # Wait for database to be ready
   docker compose logs -f db
   ```

3. **Restore data:**
   ```bash
   cat ../migration_backup.dump | docker compose exec -T db pg_restore -U postgres -d surfsense
   ```

### Moving to a New Server

1. **On old server:**
   ```bash
   docker compose stop
   tar -czf volumes_transfer.tar.gz volumes/
   ```

2. **Transfer to new server:**
   ```bash
   scp volumes_transfer.tar.gz user@newserver:/path/to/deploy/
   ```

3. **On new server:**
   ```bash
   cd /path/to/deploy
   tar -xzf volumes_transfer.tar.gz
   docker compose up -d
   ```

## Cleanup

### Temporary Files

The `shared_temp` volume can accumulate temporary files:

```bash
# Check size
du -sh volumes/shared_temp/

# Clean old temp files (older than 7 days)
find volumes/shared_temp/ -type f -mtime +7 -delete
```

### Logs

If services generate logs in volumes:

```bash
# Find large log files
find volumes/ -name "*.log" -size +100M

# Rotate or delete as needed
```

## Monitoring

### Check Volume Sizes

```bash
# Check all volume sizes
du -sh volumes/*/

# Detailed breakdown
du -h volumes/ | sort -h
```

### Disk Space Alerts

Monitor available disk space:

```bash
# Check available space
df -h | grep volumes

# Set up alert (example with cron)
# Alert if less than 10% free
*/30 * * * * [ $(df /path/to/volumes | tail -1 | awk '{print $5}' | sed 's/%//') -gt 90 ] && echo "Low disk space!" | mail -s "Alert" admin@example.com
```

## Best Practices

1. **Regular Backups**: Schedule automated database backups
2. **Monitor Disk Space**: Set up alerts for low disk space
3. **Test Restores**: Periodically test your backup restoration process
4. **Separate Backups**: Store backups on a different disk/server
5. **Document Recovery**: Document your disaster recovery procedure
6. **Permission Management**: Document any custom permission requirements for your environment

## Troubleshooting

### Permission Denied Errors

```bash
# Check current permissions
ls -la volumes/

# Fix ownership (adjust as needed)
sudo chown -R $USER:$USER volumes/

# Or match container UIDs
sudo chown -R 999:999 volumes/postgres_data/
sudo chown -R 5050:5050 volumes/pgadmin_data/
```

### Database Won't Start

```bash
# Check logs
docker compose logs db

# Check data directory permissions
ls -la volumes/postgres_data/

# If corrupted, restore from backup
docker compose down
rm -rf volumes/postgres_data/*
tar -xzf postgres_backup.tar.gz
docker compose up -d
```

### Volume is Full

```bash
# Check what's using space
du -sh volumes/*

# Clean temporary files
docker compose exec backend find /tmp -type f -delete

# Vacuum PostgreSQL (reclaim space)
docker compose exec db psql -U postgres surfsense -c "VACUUM FULL;"
```

## Security Considerations

1. **Sensitive Data**: Volume directories contain sensitive data - protect with proper file permissions
2. **Backup Encryption**: Encrypt backups before storing or transferring
3. **Access Control**: Limit who can access the server and volume directories
4. **Network Isolation**: Keep backup storage on a separate network if possible
