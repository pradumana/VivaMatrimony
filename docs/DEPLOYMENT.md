# Viva — Deployment Guide

## Production Stack

```
Internet
   │ HTTPS (443)
   ▼
Nginx (reverse proxy + SSL termination)
   │
   ▼
FastAPI (Uvicorn, port 8000)
   │
   ├── Supabase PostgreSQL (managed)
   └── Supabase Storage (managed)
```

## VPS Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 vCPU | 2 vCPU |
| RAM | 1 GB | 2 GB |
| Storage | 20 GB SSD | 40 GB SSD |
| OS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |

**Estimated cost: ₹800–₹1,500/month** (DigitalOcean, Linode, Hetzner, or Indian providers like E2E Networks)

## Step 1 — Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Install Nginx
sudo apt install nginx certbot python3-certbot-nginx -y
```

## Step 2 — SSL Certificate

```bash
sudo certbot --nginx -d api.yourdomain.com
# Certbot auto-renews via systemd timer
```

## Step 3 — Clone & Configure

```bash
git clone https://github.com/yourorg/viva.git /opt/viva
cd /opt/viva
cp .env.example .env
nano .env   # Fill in all values
```

## Step 4 — Build & Run

```bash
docker-compose up -d --build
docker-compose logs -f   # Watch startup
```

## Step 5 — Nginx Configuration

Copy `nginx.conf` to `/etc/nginx/sites-available/viva`:

```bash
sudo cp nginx.conf /etc/nginx/sites-available/viva
sudo ln -s /etc/nginx/sites-available/viva /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## Step 6 — Database Migrations

```bash
# Apply Supabase migrations via SQL editor or CLI
# See docs/SUPABASE_SETUP.md
```

## Step 7 — Verify Deployment

```bash
curl https://api.yourdomain.com/health
# Should return: {"status":"ok","version":"1.0.0"}
```

## Zero-Downtime Deploys

```bash
cd /opt/viva
git pull
docker-compose up -d --build --no-deps backend
# Old container keeps serving while new one starts
```

## Monitoring

```bash
# View logs
docker-compose logs -f backend

# Check resource usage
docker stats

# Check disk
df -h
```

## Process Management

```bash
# Restart backend
docker-compose restart backend

# Stop all
docker-compose down

# Full restart
docker-compose down && docker-compose up -d
```

## Environment Secrets

- Never commit `.env` to git
- Use strong random values for `APP_SECRET_KEY` and `JWT_SECRET_KEY`
- Generate with: `openssl rand -hex 32`
- Rotate JWT secrets by updating `.env` and restarting

## Scaling Path

When traffic grows beyond single VPS capacity:

1. **Vertical scale**: Upgrade VPS RAM/CPU first (cheapest)
2. **Read replicas**: Supabase supports read replicas (Pro plan)
3. **Horizontal scale**: Add load balancer + multiple backend instances
4. **Database scale**: Upgrade Supabase plan or migrate to dedicated PostgreSQL
5. **Cache**: Add Redis for session cache (when measured bottleneck)
6. **Search**: Add Meilisearch/OpenSearch (when FTS insufficient)

Do not introduce complexity before measured need.
