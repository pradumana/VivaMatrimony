# Firebase Setup Guide
**App:** Viva Matrimony (`com.vivamatrimony.viva_app`)
**Firebase Project:** `viva-analytics-135d4`

All steps below require manual action in the Firebase console or CLI.
Items marked **NOT VERIFIED** must be confirmed in `manual-checklist.md`.

---

## 1. Prerequisites

- Node.js ≥ 18 (for Cloud Functions)
- Firebase CLI: `npm install -g firebase-tools`
- FlutterFire CLI: `dart pub global activate flutterfire_cli`
- Logged in: `firebase login`

---

## 2. Confirm FlutterFire configuration

`firebase_options.dart` is already generated for project `viva-analytics-135d4`.
Run this only if the project settings change:

```bash
cd viva_app
flutterfire configure --project=viva-analytics-135d4
```

**NOT VERIFIED — confirm `firebase_options.dart` is up to date.**

---

## 3. Register Android SHA fingerprints

Required for Firebase Auth to work on Android (especially email link verification).

Get your keystore fingerprints:
```bash
# Debug keystore (for development builds)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release keystore
keytool -list -v -keystore <path-to-your-keystore.jks> -alias <key-alias>
```

In Firebase console → Project settings → Your apps → Android app (`com.vivamatrimony.viva_app`):
- Add SHA-1 fingerprint
- Add SHA-256 fingerprint
- Click Save

Download updated `google-services.json` and replace `viva_app/android/app/google-services.json`.

**NOT VERIFIED — manual step required.**

---

## 4. Enable Email/Password sign-in

Firebase console → Authentication → Sign-in methods → Email/Password → Enable → Save.

**NOT VERIFIED — manual step required.**

---

## 5. Customise email templates

Firebase console → Authentication → Templates:
- **Email verification**: Set sender name to "Viva Matrimony", customise subject and body.
- **Password reset**: Same customisation.
- **Email link sign-in** (if used): Same.

Ensure the action URL domain is `vivamatrimony.in` or `viva-analytics-135d4.firebaseapp.com`.

**NOT VERIFIED — manual step required.**

---

## 6. Authorised domains

Firebase console → Authentication → Settings → Authorised domains → Add domain:
- `vivamatrimony.in`
- `api.vivamatrimony.in` (if backend redirects land here)

**NOT VERIFIED — manual step required.**

---

## 7. Android intent filter for Firebase email links

Firebase email verification and password-reset links open in the browser and redirect
back to the app using a custom scheme or App Links.

The current intent filter in `AndroidManifest.xml`:
```xml
<data android:scheme="com.vivamatrimony.viva_app"
      android:host="login-callback" />
```

For Firebase Auth email links, update the intent filter to handle
`https://viva-analytics-135d4.firebaseapp.com/__/auth/action` redirects,
or configure Dynamic Links / a custom domain in the Firebase console.

**Decision required:** Use Firebase default domain (`firebaseapp.com`) or configure
a custom domain (`vivamatrimony.in`) for email action links.

**NOT VERIFIED — update AndroidManifest.xml and Firebase console in Phase 4.**

---

## 8. Identity Platform upgrade (optional — for blocking functions)

The Cloud Function `beforeSignIn` (which sets `role: "authenticated"` as a custom claim)
requires **Identity Platform** (formerly "Firebase Auth with Identity Platform").

Check: Firebase console → Authentication → If you see "Upgrade" button → you are on
the free plan and need to upgrade. This incurs costs based on monthly active users.

**Decision required before Phase 4 — see OQ-8 in `manual-checklist.md`.**

---

## 9. Deploy Cloud Function (Phase 4)

The `beforeSignIn` blocking function adds `role: "authenticated"` to every Firebase token.

```bash
cd functions
npm install
npm run build       # compiles TypeScript
firebase deploy --only functions:beforeSignIn --project viva-analytics-135d4
```

**NOT VERIFIED — deploy only after Identity Platform decision (step 8).**

---

## 10. google-services.json

File location: `viva_app/android/app/google-services.json`
Currently present and correct for project `viva-analytics-135d4`.

If you regenerate it (after adding SHA fingerprints), replace this file.
**Never commit this file with secrets to a public repository** (it is safe for private repos;
the API keys in `google-services.json` are restricted by package name + SHA).
