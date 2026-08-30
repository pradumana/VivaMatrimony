# Viva — Indian Matrimony App

> **"Find someone who feels like home."**

A premium, low-cost Indian matrimonial platform built with Flutter, FastAPI, and Supabase.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.x + Dart (Material 3, Riverpod, GoRouter) |
| Backend | Python 3.11 + FastAPI + Pydantic v2 |
| Database | Supabase PostgreSQL |
| Storage | Supabase Storage |
| Auth | WhatsApp OTP (OpenWA dev / Official Meta API prod) |
| Deployment | Docker Compose + Nginx on low-cost VPS |

---

## Project Structure

```
viva/
├── backend/           # FastAPI backend
│   ├── app/
│   │   ├── main.py
│   │   ├── api/v1/endpoints/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/
│   │   ├── repositories/
│   │   ├── database/
│   │   ├── middleware/
│   │   ├── utils/
│   │   └── config/
│   ├── migrations/
│   └── tests/
├── viva_app/          # Flutter application
│   ├── lib/
│   │   ├── core/
│   │   ├── features/
│   │   └── shared/
├── supabase/          # DB migrations + RLS policies
├── docs/              # Architecture, SRS, API docs
├── scripts/           # Deployment & utility scripts
├── docker-compose.yml
├── nginx.conf
└── .env.example
```

---

## Quick Start

### Prerequisites
- Python 3.11+
- Flutter 3.x
- Docker & Docker Compose
- Supabase account (free tier works)
- Node.js 18+ (for OpenWA dev usage)

### 1. Clone & configure

```bash
cp .env.example .env
# Edit .env with your Supabase credentials
```

### 2. Run database migrations

```bash
cd supabase
# Apply migrations via Supabase SQL editor or CLI
# See docs/SUPABASE_SETUP.md
```

### 3. Start backend

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload
# API docs: http://localhost:8000/docs
```

### 4. Run Flutter app

```bash
cd viva_app
flutter pub get
flutter run
```

### 5. Docker Compose (production)

```bash
docker-compose up -d
```

---

## Environment Variables

See `.env.example` for all required variables.

---

## Documentation

| Document | Location |
|----------|----------|
| System Requirements | docs/SRS.md |
| API Specification | docs/API.md |
| Database Schema | docs/DATABASE.md |
| Architecture | docs/ARCHITECTURE.md |
| Deployment Guide | docs/DEPLOYMENT.md |
| Supabase Setup | docs/SUPABASE_SETUP.md |
| Backup Strategy | docs/BACKUP.md |
| WhatsApp Setup | docs/WHATSAPP.md |

---

## Target Infrastructure Cost

| Item | Monthly Cost (INR) |
|------|--------------------|
| VPS (2 vCPU / 2GB RAM) | ₹800–₹1,200 |
| Supabase Free Tier | ₹0 |
| Supabase Pro (at scale) | ₹2,000 |
| Domain | ₹800/year |
| **Base total** | **₹800–₹3,200** |

---

## Feature Phases

**P0 — MVP (this build)**
WhatsApp login · Profile · Biodata · Verification · Search · Matching · Interests · Messaging · Admin

**P1 — Next**
Subscriptions · Payments · Advanced filters · Analytics

**P2 — Scale**
AI matching · Video calls · Elasticsearch · Redis

---

## License

Private — All rights reserved.
