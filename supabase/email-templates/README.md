# Viva Matrimony — Supabase Email Templates

Four branded HTML templates matching Viva's maroon/gold design language.

## Templates

| File | Template type in Dashboard |
|---|---|
| `confirmation.html` | Confirm signup |
| `password-reset.html` | Reset password |
| `magic-link.html` | Magic link |
| `email-change.html` | Change email address |

## How to apply (do this once in the Supabase Dashboard)

### Step 1 — Set sender name and address
1. Go to **Authentication → Email Templates → Sender details**
2. Set **Sender name** → `Viva Matrimony`
3. Set **Sender email** → your verified sending address (see Step 3 if you haven't set one)

### Step 2 — Paste each template
For each template type listed above:
1. Go to **Authentication → Email Templates → [Template name]**
2. Set **Subject** (see subjects below)
3. Paste the full HTML into the **Body** field
4. Click **Save**

**Suggested subjects:**
- Confirm signup → `Confirm your email — Viva Matrimony 🪷`
- Reset password → `Reset your password — Viva Matrimony`
- Magic link → `Your sign-in link — Viva Matrimony`
- Change email → `Confirm your new email — Viva Matrimony`

### Step 3 — Custom SMTP (recommended for production)
Without custom SMTP, emails come from `noreply@mail.supabase.io` regardless of templates.
To send from your own domain (`noreply@vivamatrimony.in`):
1. Go to **Project Settings → Auth → SMTP Settings**
2. Enable **Custom SMTP**
3. Enter your SMTP credentials — see Resend setup below
4. Set **Sender email** to `noreply@vivamatrimony.in`

**Cheapest option for low volume:** [Resend](https://resend.com) — free tier sends 3,000 emails/month.
Setup: create account → **Add Domain** → enter `vivamatrimony.in` → add the DNS records they show you at your registrar → verify → get API key, then use:
- Host: `smtp.resend.com`
- Port: `465`
- User: `resend`
- Password: `<your-resend-api-key>`

### Step 4 — Site URL (connects to deep link fix)
1. Go to **Authentication → URL Configuration**
2. Set **Site URL** → `com.vivamatrimony.viva_app://login-callback`
3. Add `com.vivamatrimony.viva_app://**` to **Redirect URLs**

This ensures the confirmation link opens the app directly.
