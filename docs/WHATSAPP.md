# Viva — WhatsApp Integration Guide

## Provider Strategy

Viva uses a provider-abstracted WhatsApp integration:

```
WhatsAppService (interface)
       │
       ├── OpenWAProvider        → Development / POC
       ├── MetaWhatsAppProvider  → Production (official)
       └── MockWhatsAppProvider  → Tests
```

Switch providers by setting `WHATSAPP_PROVIDER` in `.env`.

---

## Development: OpenWA

OpenWA is an unofficial WhatsApp library for development/POC only.

**Do NOT use OpenWA in production.** It violates WhatsApp Terms of Service and can result in phone number bans.

### Setup

```bash
# Install OpenWA
npm install -g @open-wa/wa-automate

# Start OpenWA session
npx @open-wa/wa-automate \
  --port 8002 \
  --api-key your-api-key \
  --phone +919999999999
```

Scan the QR code with your WhatsApp (development number only).

Set in `.env`:
```
WHATSAPP_PROVIDER=openwa
OPENWA_BASE_URL=http://localhost:8002
OPENWA_API_KEY=your-api-key
```

---

## Production: Meta WhatsApp Business API

### Setup

1. Create a Meta Business Account at https://business.facebook.com
2. Set up WhatsApp Business API at https://developers.facebook.com/docs/whatsapp
3. Verify your business
4. Get a phone number approved for WhatsApp Business
5. Create a message template for OTP:

**Template name**: `viva_otp`
**Template category**: Authentication
**Template body**:
```
Your Viva OTP is {{1}}. Valid for 10 minutes. Do not share with anyone.
```

6. Get approved by Meta (1-3 business days)

### Configuration

```
WHATSAPP_PROVIDER=official
META_WHATSAPP_TOKEN=your_permanent_token
META_WHATSAPP_PHONE_NUMBER_ID=your_phone_number_id
META_WHATSAPP_VERIFY_TOKEN=random_string_for_webhook
```

### Webhook Setup

Point Meta webhook to: `https://api.yourdomain.com/webhook/whatsapp`

This handles delivery receipts and message status updates.

---

## OTP Message Format

**English:**
```
Hi! Your Viva verification code is: 123456

Valid for 10 minutes. Do not share this code with anyone.

- Viva Team
```

**Hindi:**
```
नमस्ते! आपका Viva सत्यापन कोड है: 123456

यह कोड 10 मिनट के लिए वैध है। इसे किसी के साथ साझा न करें।

- Viva Team
```

---

## Cost Estimate

| Provider | Cost |
|----------|------|
| OpenWA | Free (dev only) |
| Meta WhatsApp API | Free tier: 1,000 conversations/month. After: ~$0.004–$0.008/conversation |

At 1,000 new users/month with 2 OTP attempts each:
~2,000 messages × $0.005 = ~$10/month = ~₹830/month

---

## Rate Limits

| Limit | Value |
|-------|-------|
| OTP attempts per phone | 5 per day |
| OTP resend cooldown | 60 seconds |
| OTP validity | 10 minutes |
| Rate limit per IP | 60 req/min general, 5 OTP req/hour |

---

## Fallback

If WhatsApp OTP fails to deliver:
1. Show "Resend OTP" button (appears after 60 seconds)
2. After 3 failed attempts, show contact support
3. Log delivery failures for monitoring
4. Admin can manually verify users if needed
