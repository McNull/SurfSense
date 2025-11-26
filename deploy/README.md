# SurfSense Production Deployment

This directory contains production-ready Docker deployment files for SurfSense.

## Quick Start

### 1. Configure Environment

Copy the example environment file and configure it with your production values:

```bash
cp .env.example .env
# Edit .env with your production values
nano .env  # or vim, code, etc.
```

**Critical variables to configure:**
- `POSTGRES_PASSWORD` - Strong database password (replace `<CHANGE_ME_STRONG_PASSWORD>`)
- `PGADMIN_DEFAULT_PASSWORD` - Strong pgAdmin password (replace `<CHANGE_ME_STRONG_PASSWORD>`)
- `SECRET_KEY` - Application secret key (generate with `openssl rand -hex 32`)
- `NEXT_PUBLIC_FASTAPI_BACKEND_URL` - Set to your production API URL (e.g., `https://your-domain.com/api`)
- API keys (FIRECRAWL_API_KEY, etc.) - Add your actual keys
- OAuth credentials (if using Google auth) - Add your client ID and secret

### 2. Create Volume Directories

Volume directories will be created automatically on first run, or create them manually:

```bash
mkdir -p volumes/{postgres_data,pgadmin_data,redis_data,shared_temp}
```

### 3. Pull Images

Pull the pre-built images from the registry:

```bash
docker compose pull
```

### 4. Start Services

Start all services in detached mode:

```bash
docker compose up -d
```

### 5. Verify Deployment

Check that all services are running and healthy:

```bash
docker compose ps
```

View backend logs:

```bash
docker compose logs -f backend
```

Access the application:
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **pgAdmin**: http://localhost:5050

## Building Images

If you need to build images locally (for development or custom builds):

### Prerequisites
- Docker with BuildKit enabled
- Access to your Docker registry (credentials configured)
- Sufficient disk space for builds (~5GB for backend, ~1GB for frontend)

### Build Scripts

**Build both services:**
```bash
cd scripts/
./build.sh
```

The script will:
1. Extract versions from pyproject.toml (backend) and package.json (frontend)
2. Build images with production URL baked into frontend
3. Tag images with version number and `latest`
4. Ask if you want to push to registry

**Build specific service:**
```bash
./build.sh backend          # Build backend only
./build.sh frontend         # Build frontend only
```

**Build with optional postfix:**
```bash
./build.sh both rc1         # Tags: 0.0.8-rc1, latest
./build.sh backend hotfix   # Tags: 0.0.8-hotfix, latest
./build.sh frontend patch1  # Tags: 0.0.8-patch1, latest
```

The postfix allows multiple builds of the same version for testing or staged rollouts.

### Push to Registry

If you declined the push prompt during build, you can push later:

```bash
./push.sh both              # Push both services
./push.sh backend           # Push backend only
./push.sh frontend hotfix   # Push frontend with -hotfix postfix
```

## Image Versioning

### Version Strategy

Images are automatically tagged with versions extracted from source code:
- **Backend**: Version from `surfsense_backend/pyproject.toml`
- **Frontend**: Version from `surfsense_web/package.json`

Current versions: **Backend 0.0.8**, **Frontend 0.0.8**

### Tag Format

```
${DOCKER_REGISTRY}/${IMAGE_NAME}:${VERSION}[-${POSTFIX}]
${DOCKER_REGISTRY}/${IMAGE_NAME}:latest

Examples:
- your-registry.com/surfsense-backend:0.0.8
- your-registry.com/surfsense-backend:0.0.8-rc1
- your-registry.com/surfsense-backend:latest
- your-registry.com/surfsense-frontend:0.0.8
- your-registry.com/surfsense-frontend:0.0.8-hotfix
- your-registry.com/surfsense-frontend:latest
```

### Updating Versions

To deploy a new version:

1. Update version in source:
   - Backend: Edit `surfsense_backend/pyproject.toml`
   - Frontend: Edit `surfsense_web/package.json`

2. Build and push:
   ```bash
   cd deploy/scripts/
   ./build.sh both
   ```

3. Update `.env` file:
   ```bash
   BACKEND_IMAGE_TAG=0.0.9
   FRONTEND_IMAGE_TAG=0.0.9
   ```

4. Pull and restart:
   ```bash
   docker compose pull
   docker compose up -d
   ```

## Environment Variables

### Build-time vs Runtime

**IMPORTANT**: The frontend uses Next.js, which embeds `NEXT_PUBLIC_*` variables at build time.

**Build-time variables** (embedded in frontend image, cannot change at runtime):
- `NEXT_PUBLIC_FASTAPI_BACKEND_URL` - Set to your production API URL (e.g., `https://your-domain.com/api`)
- `NEXT_PUBLIC_FASTAPI_BACKEND_AUTH_TYPE` - LOCAL or GOOGLE
- `NEXT_PUBLIC_ETL_SERVICE` - DOCLING, UNSTRUCTURED, or LLAMACLOUD

To change these values, you must rebuild the frontend image with new build args.

**Runtime variables** (can be changed in .env):
- All backend configuration (database, Celery, API keys, etc.)
- Service ports
- Infrastructure settings

### Critical Configuration

See [.env.example](.env.example) for full documentation of all variables.

**Must configure:**
- Database passwords (POSTGRES_PASSWORD, PGADMIN_DEFAULT_PASSWORD)
- Application secret (SECRET_KEY)
- API keys for external services

**Should review:**
- Authentication type (AUTH_TYPE: LOCAL or GOOGLE)
- ETL service (ETL_SERVICE: DOCLING, UNSTRUCTURED, or LLAMACLOUD)
- Embedding model (EMBEDDING_MODEL)

## Volume Management

Comprehensive volume documentation: [VOLUMES.md](VOLUMES.md)

### Quick Reference

**Backup database:**
```bash
docker compose exec db pg_dump -U postgres -Fc surfsense > backup_$(date +%Y%m%d).dump
```

**Restore database:**
```bash
cat backup_20250125.dump | docker compose exec -T db pg_restore -U postgres -d surfsense
```

**Backup all volumes:**
```bash
tar -czf volumes_backup_$(date +%Y%m%d).tar.gz volumes/
```

## Service Management

### View Logs

All services:
```bash
docker compose logs -f
```

Specific service:
```bash
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f db
```

Last 100 lines:
```bash
docker compose logs --tail=100 backend
```

### Restart Services

All services:
```bash
docker compose restart
```

Specific service:
```bash
docker compose restart backend
docker compose restart frontend
```

### Stop Services

Stop all services (keeps volumes):
```bash
docker compose stop
```

Stop and remove containers (keeps volumes):
```bash
docker compose down
```

### Update Images

Pull latest images:
```bash
docker compose pull
```

Apply updates:
```bash
docker compose up -d
```

Docker Compose will recreate only the containers with updated images.

### Scale Services (Advanced)

If you've uncommented the Celery services:

```bash
# Start Celery worker separately
docker compose up -d celery_worker

# Scale workers
docker compose up -d --scale celery_worker=3
```

## Health Checks

All services include health checks for reliable startup and monitoring.

### Health Check Configuration

| Service  | Check Method        | Interval | Timeout | Retries | Start Period |
|----------|---------------------|----------|---------|---------|--------------|
| db       | pg_isready          | 10s      | 5s      | 5       | -            |
| redis    | redis-cli ping      | 10s      | 5s      | 5       | -            |
| backend  | curl /health        | 30s      | 10s     | 3       | 60s          |
| frontend | wget localhost:3000 | 30s      | 10s     | 3       | 40s          |

### Check Health Status

```bash
docker compose ps
```

Look for `(healthy)` status. Services with dependencies wait for health checks before starting.

### Manual Health Check

```bash
# Check backend health endpoint
curl http://localhost:8000/health

# Check database
docker compose exec db pg_isready -U postgres

# Check Redis
docker compose exec redis redis-cli ping
```

## Network Architecture

Services communicate via `surfsense-network` bridge network:

```
┌─────────────────────────────────────────┐
│           Docker Network                │
│        (surfsense-network)              │
│                                         │
│  ┌──────────┐      ┌──────────┐       │
│  │ Frontend │─────▶│ Backend  │       │
│  │  :3000   │      │  :8000   │       │
│  └──────────┘      └────┬─────┘       │
│                          │              │
│              ┌───────────┴────────┐    │
│              ▼                    ▼    │
│         ┌────────┐          ┌────────┐│
│         │   DB   │          │ Redis  ││
│         │  :5432 │          │  :6379 ││
│         └────────┘          └────────┘│
│                                         │
└─────────────────────────────────────────┘
           │           │           │
           ▼           ▼           ▼
    localhost:3000  :8000      :5050 (pgAdmin)
```

**Service URLs (within Docker network):**
- Database: `db:5432`
- Redis: `redis:6379`
- Backend: `backend:8000`
- Frontend: `frontend:3000`

**External access (from host):**
- Frontend: `http://localhost:3000`
- Backend: `http://localhost:8000`
- pgAdmin: `http://localhost:5050`

## Troubleshooting

### Backend Won't Start

**Check logs:**
```bash
docker compose logs backend
```

**Common issues:**
- Database not ready: Wait for health check to pass
- Wrong DATABASE_URL: Verify uses `db` not `localhost`
- Missing environment variables: Check .env file

**Fix:**
```bash
# Verify database is healthy
docker compose ps db

# Restart backend
docker compose restart backend
```

### Frontend Can't Reach Backend

**Remember**: `NEXT_PUBLIC_FASTAPI_BACKEND_URL` is baked in at build time!

If you changed the backend URL, you must rebuild:
```bash
cd scripts/
./build.sh frontend
```

Then update and restart:
```bash
docker compose pull
docker compose up -d frontend
```

### Database Connection Errors

**Check connection string:**
```bash
# Should use 'db' not 'localhost'
grep DATABASE_URL .env
```

**Verify database is running:**
```bash
docker compose exec db psql -U postgres -d surfsense -c "SELECT 1;"
```

**Check password matches:**
```bash
# Ensure POSTGRES_PASSWORD in .env matches DATABASE_URL
```

### Permission Issues with Volumes

```bash
# Check current permissions
ls -la volumes/

# Fix ownership
sudo chown -R $USER:$USER volumes/

# Or broader permissions (less secure)
chmod -R 755 volumes/
```

See [VOLUMES.md](VOLUMES.md) for detailed permission guidance.

### Service Keeps Restarting

**Check health check failures:**
```bash
docker compose ps
docker compose logs <service_name>
```

**Common causes:**
- Insufficient startup time (health check failing too soon)
- Port conflicts
- Out of memory
- Dependency service not healthy

### Out of Disk Space

```bash
# Check volume sizes
du -sh volumes/*/

# Check Docker disk usage
docker system df

# Clean up unused Docker data
docker system prune -a
```

### Container Can't Resolve Service Names

**Ensure all services are on the same network:**
```bash
docker compose ps
```

All should show `surfsense-network`.

**Restart networking:**
```bash
docker compose down
docker compose up -d
```

## Security Considerations

### Production Checklist

Before deploying to production:

- [ ] **Change all default passwords**
  - [ ] POSTGRES_PASSWORD
  - [ ] PGADMIN_DEFAULT_PASSWORD
- [ ] **Generate strong SECRET_KEY** (`openssl rand -hex 32`)
- [ ] **Configure actual API keys** (remove placeholders)
- [ ] **Set up reverse proxy** (nginx/traefik) with SSL/TLS
- [ ] **Restrict port exposure** (use reverse proxy, don't expose all ports)
- [ ] **Enable firewall** (only allow necessary ports)
- [ ] **Set up regular backups** (automate database backups)
- [ ] **Configure monitoring** (health checks, logging, metrics)
- [ ] **Review AUTH_TYPE** (consider GOOGLE for production)
- [ ] **Enable HTTPS** (configure TLS certificates)
- [ ] **Restrict pgAdmin access** (don't expose publicly)
- [ ] **Set up log rotation** (prevent disk space issues)
- [ ] **Document rollback procedure** (how to revert to previous version)

### Securing Exposed Services

**Use a reverse proxy:**

Example nginx configuration:
```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location /api {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Update docker-compose.yml** to only expose ports to localhost:
```yaml
ports:
  - "127.0.0.1:8000:8000"  # Only accessible from localhost
  - "127.0.0.1:3000:3000"
```

### Secrets Management

For production, consider using Docker secrets or external secrets management:

```bash
# Example with Docker secrets
echo "my-secret-password" | docker secret create postgres_password -

# Reference in compose:
secrets:
  - postgres_password
```

### Regular Updates

```bash
# Check for updated images
docker compose pull

# Apply updates
docker compose up -d

# Verify
docker compose ps
```

## Monitoring and Logging

### Container Stats

```bash
# Real-time stats
docker stats

# Specific service
docker stats surfsense-backend
```

### Log Management

**Export logs:**
```bash
docker compose logs > logs_$(date +%Y%m%d_%H%M%S).txt
```

**Log to external system:**
Configure Docker logging driver in docker-compose.yml:
```yaml
logging:
  driver: "syslog"
  options:
    syslog-address: "tcp://192.168.0.42:514"
```

## Advanced Configuration

### Celery Services

To run Celery worker and beat as separate services, uncomment in docker-compose.yml:

```bash
# Edit docker-compose.yml, uncomment celery_worker, celery_beat, flower

# Start services
docker compose up -d celery_worker celery_beat flower
```

Access Flower monitoring at http://localhost:5555

### Custom Network

To use an external network:

```yaml
networks:
  surfsense-network:
    external: true
    name: my-existing-network
```

### Resource Limits

Add resource constraints to services:

```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
```

## Getting Help

- **Documentation**: Start with this README and [VOLUMES.md](VOLUMES.md)
- **Logs**: Always check logs first (`docker compose logs`)
- **Health checks**: Verify all services are healthy (`docker compose ps`)
- **Issues**: Check the GitHub issues page
- **Community**: Join the SurfSense community for support

## Appendix

### Useful Commands Reference

```bash
# View all containers
docker compose ps -a

# Remove all stopped containers
docker compose rm

# View networks
docker network ls

# Inspect service configuration
docker compose config

# Validate compose file
docker compose config --quiet

# View image information
docker compose images

# Execute command in running container
docker compose exec backend bash

# Copy files from container
docker compose cp backend:/app/logs ./backup-logs

# Follow logs from multiple services
docker compose logs -f backend frontend

# Restart with fresh containers (keeps volumes)
docker compose up -d --force-recreate

# Check what will be updated
docker compose pull --dry-run
```

### Port Reference

| Service  | Internal Port | Host Port | Purpose              |
|----------|---------------|-----------|----------------------|
| Frontend | 3000          | 3000      | Web UI               |
| Backend  | 8000          | 8000      | API                  |
| Database | 5432          | 5432      | PostgreSQL           |
| Redis    | 6379          | 6379      | Cache/Queue          |
| pgAdmin  | 80            | 5050      | DB Management        |
| Flower   | 5555          | 5555      | Celery Monitoring    |

### Environment Variables Quick Reference

Full documentation in [.env.example](.env.example)

**Infrastructure:**
- `POSTGRES_*` - Database configuration
- `REDIS_PORT` - Redis port
- `PGADMIN_*` - pgAdmin settings
- `*_PORT` - Service port mappings

**Backend:**
- `DATABASE_URL` - DB connection (uses `db` service)
- `CELERY_*` - Celery configuration (uses `redis` service)
- `SECRET_KEY` - Application secret
- `AUTH_TYPE` - LOCAL or GOOGLE
- `*_API_KEY` - External service keys

**Frontend (build-time):**
- `NEXT_PUBLIC_FASTAPI_BACKEND_URL` - Backend URL (requires rebuild to change)
- `NEXT_PUBLIC_FASTAPI_BACKEND_AUTH_TYPE` - Auth type
- `NEXT_PUBLIC_ETL_SERVICE` - ETL service type

**Images:**
- `DOCKER_REGISTRY` - Image registry URL
- `BACKEND_IMAGE_TAG` - Backend version
- `FRONTEND_IMAGE_TAG` - Frontend version
