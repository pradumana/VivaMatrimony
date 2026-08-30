# Viva — System Architecture

## Overview

Viva is built as a **modular monolith** — one deployable backend unit with clean internal service abstractions that can be decomposed later if needed.

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App (Android/iOS)             │
│  Riverpod · GoRouter · Dio · Material 3                  │
└────────────────────────┬────────────────────────────────┘
                         │ HTTPS REST API
                         ▼
┌─────────────────────────────────────────────────────────┐
│                  FastAPI Backend                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │  Auth    │ │ Profile  │ │ Matching │ │  Admin   │  │
│  │ Service  │ │ Service  │ │ Service  │ │ Service  │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │Verification│ │Messaging│ │ Biodata  │ │Notification│ │
│  │ Service  │ │ Service  │ │ Service  │ │ Service  │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
│                   Repository Layer                       │
└────────────────────────┬────────────────────────────────┘
                         │
           ┌─────────────┴─────────────┐
           ▼                           ▼
┌─────────────────┐         ┌────────────────────┐
│ Supabase Postgres│         │  Supabase Storage  │
│                 │         │                    │
│ • users         │         │ • profile-photos/  │
│ • profiles      │         │ • biodata-pdfs/    │
│ • interests     │         │ • verification-docs│
│ • messages      │         │   (private bucket) │
│ • ...           │         └────────────────────┘
└─────────────────┘
           │
           ▼
┌─────────────────────────┐
│   WhatsApp Provider     │
│   ┌─────────────────┐   │
│   │  OpenWA (dev)   │   │
│   └─────────────────┘   │
│   ┌─────────────────┐   │
│   │  Meta API (prod)│   │
│   └─────────────────┘   │
└─────────────────────────┘
```

## Request Authorization Flow

Every protected API endpoint follows this chain:

```
HTTP Request
    │
    ▼
Rate Limiter Middleware
    │
    ▼
JWT Authentication Middleware
    │
    ▼
Account Status Check (active / suspended / banned)
    │
    ▼
Resource Ownership Check
    │
    ▼
Business Rule Validation
    │
    ▼
Handler / Service
    │
    ▼
Repository → Database
```

## Service Abstractions

All external dependencies are hidden behind interfaces:

| Interface | Dev Implementation | Prod Implementation |
|-----------|-------------------|---------------------|
| WhatsAppService | OpenWAProvider | MetaWhatsAppProvider |
| StorageService | SupabaseStorageService | SupabaseStorageService |
| SearchService | PostgresSearchService | PostgresSearchService (→ future: AdvancedSearchService) |
| NotificationService | FCMNotificationService | FCMNotificationService |
| BiodataService | WeasyPrintBiodataService | WeasyPrintBiodataService |

## Flutter Architecture

```
lib/
├── core/
│   ├── router/          # GoRouter configuration
│   ├── theme/           # Material 3 design system
│   ├── network/         # Dio HTTP client + interceptors
│   ├── storage/         # Secure local storage
│   └── providers/       # Root Riverpod providers
├── features/
│   ├── auth/            # WhatsApp login + OTP
│   ├── onboarding/      # Multi-step profile creation
│   ├── home/            # Dashboard
│   ├── profile/         # Profile view + edit
│   ├── search/          # Search + filters
│   ├── matches/         # Match recommendations
│   ├── interests/       # Send/receive interests
│   ├── shortlist/       # Saved profiles
│   ├── messaging/       # Conversations + chat
│   ├── verification/    # Reference + certificate
│   ├── biodata/         # Biodata preview + PDF
│   ├── notifications/   # Notification center
│   ├── admin/           # Admin panel (web)
│   └── settings/        # Privacy, account, help
└── shared/
    ├── widgets/         # Reusable components
    ├── models/          # Data models
    ├── extensions/      # Dart extensions
    └── constants/       # App-wide constants
```

## Database Design Principles

1. All tables use UUID primary keys
2. Soft deletion via `deleted_at` timestamp
3. `created_at` / `updated_at` on every table
4. Foreign key constraints enforced at DB level
5. Unique constraints prevent duplicate data
6. RLS policies on every user-facing table
7. Sensitive data (certificates) in private storage

## Cost Optimization

| Decision | Rationale |
|----------|-----------|
| Single FastAPI process | No Celery/Kafka overhead |
| PostgreSQL FTS for search | No Elasticsearch cost |
| Supabase Storage | No S3/GCS setup |
| Supabase free tier | 500MB DB, 1GB storage free |
| VPS over ECS/K8s | Predictable low cost |
| Docker Compose | No Kubernetes complexity |
