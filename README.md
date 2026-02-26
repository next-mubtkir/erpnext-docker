# ERPNext Docker Deployment

ERPNext v16 deployment with Docker Compose, Traefik, and additional apps (Helpdesk, CRM, Frappe Assistant).

## Quick Start

### Prerequisites

- Docker
- Docker Compose v2

### Local Environment

```bash
# 1. Copy environment variables and edit passwords
cp .env.example .env
# Edit .env and set DB_PASSWORD and ADMIN_PASSWORD

# 2. Generate SSL certificates for localhost (see SSL Certificates section below)

# 3. Add to /etc/hosts
echo "127.0.0.1 erpnext.localhost" | sudo tee -a /etc/hosts

# 4. Start
./start-local.sh

# 5. Access
# https://erpnext.localhost:9443
```

### SSL Certificates (Local)

For local HTTPS, you need to generate self-signed certificates:

```bash
# Create certificates directory
mkdir -p traefik/certs

# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 -keyout traefik/certs/erpnext.localhost-key.pem -out traefik/certs/erpnext.localhost.pem -days 365 -nodes -subj "/CN=erpnext.localhost"

# Add to trusted certificates (macOS)
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain traefik/certs/erpnext.localhost.pem

# For Linux (Ubuntu/Debian)
sudo cp traefik/certs/erpnext.localhost.pem /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### Ports (Local)

| Service | Port |
|---------|------|
| HTTP | 9080 |
| HTTPS | 9443 |
| Traefik Dashboard | 9081 |

## Installed Apps

| App | Version |
|-----|--------|
| frappe | 16.9.0 |
| erpnext | 16.6.1 |
| crm | 1.59.2 |
| telephony | 0.0.1 |
| helpdesk | 1.20.2 |
| frappe_assistant_core | 2.3.1 |

## Project Structure

```
├── apps.json                 # Apps for custom build
├── build-image.sh            # Build custom image
├── compose.yaml              # Base compose config
├── compose.local.yaml        # Local override
├── compose.prd.yaml          # Production override
├── traefik-compose.yaml      # Local Traefik
├── .env.example              # Environment template
├── start-local.sh            # Local startup script
├── start-prd.sh              # Production startup script
├── images/custom/Containerfile
├── resources/core/nginx/
└── traefik/
    ├── traefik.yml
    └── dynamic/
        └── certs.yml
```

## Commands

### Local

```bash
./start-local.sh start    # Start (Traefik + ERPNext)
./start-local.sh stop     # Stop all
./start-local.sh restart  # Restart
./start-local.sh status   # Container status
./start-local.sh logs     # View logs
./start-local.sh reset    # Full reset (DESTRUCTIVE)
```

### Production

```bash
./start-prd.sh start    # Start
./start-prd.sh stop     # Stop
./start-prd.sh restart  # Restart
./start-prd.sh status   # Status
./start-prd.sh logs     # Logs
./start-prd.sh backup   # Database backup
./start-prd.sh migrate  # Run migrations
./start-prd.sh console  # Python console
```

## Custom Image Build

ERPNext v16 requires Python 3.14. Build a custom image:

```bash
# Edit apps.json with desired apps
./build-image.sh           # Normal build
./build-image.sh --no-cache  # Build without cache
```

After build, update `.env`:

```bash
CUSTOM_IMAGE=erpnext-custom
CUSTOM_TAG=16
PULL_POLICY=missing
```

## Architecture

```
                    ┌─────────────────┐
                    │    Traefik      │
                    │  SSL/HTTPS      │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │         frontend            │
              │    (Nginx - port 8080)      │
              └──────────────┬──────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    ┌────┴────┐        ┌─────┴─────┐      ┌──────┴──────┐
    │ backend │        │ websocket │      │   scheduler │
    └────┬────┘        └───────────┘      └─────────────┘
         │
    ┌────┴────────────────────────────┐
    │                                 │
┌───┴────┐   ┌────────────┐   ┌───────┴───────┐
│ MariaDB│   │    Redis   │   │ Queue Workers │
│   db   │   │ cache+queue│   │ short + long  │
└────────┘   └────────────┘   └───────────────┘
```

## Environment Variables

| Variable | Description | Default |
|----------|-----------|---------|
| `ERPNEXT_VERSION` | ERPNext version | `version-16` |
| `FRAPPE_VERSION` | Frappe version | `version-16` |
| `CUSTOM_IMAGE` | Custom image name | `frappe/erpnext` |
| `CUSTOM_TAG` | Image tag | `version-16` |
| `PULL_POLICY` | Pull policy | `always` |
| `DB_PASSWORD` | MariaDB root password | - |
| `ADMIN_PASSWORD` | Site admin password | - |
| `SITE_NAME` | Site name | - |
| `MARIADB_VERSION` | MariaDB version | `11.8` |
| `REDIS_VERSION` | Redis version | `6.2-alpine` |

## Troubleshooting

### Site not loading

```bash
# Check containers
./start-local.sh status

# View logs
docker compose logs backend --tail=50

# Restart
./start-local.sh restart
```

### Database error

```bash
# Check MariaDB health
docker compose ps db

# Restart database
docker compose restart db
```

### Full reset

```bash
./start-local.sh reset
```

## Production Deployment

1. Copy `.env.example` to `.env` and set production values
2. Update `SITE_NAME` to your domain
3. Ensure Traefik is configured with Let's Encrypt
4. Run `./start-prd.sh start`
5. Create the site:

```bash
docker compose exec backend bench new-site your-domain.com \
    --mariadb-user-host-login-scope='%' \
    --db-root-password 'YOUR_DB_PASSWORD' \
    --admin-password 'YOUR_ADMIN_PASSWORD' \
    --install-app erpnext
```

## References

- [ERPNext Documentation](https://docs.erpnext.com)
- [Frappe Documentation](https://frappeframework.com/docs)
- [Community Forum](https://discuss.frappe.io)
- [Frappe Docker GitHub](https://github.com/frappe/frappe_docker)
