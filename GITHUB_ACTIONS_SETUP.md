# GitHub Actions Release Build Setup

## ✅ Changes Made to `.github/workflows/build-apk.yml`

### 1. **Fixed Flutter Version** ✅
- **Before:** `flutter-version: '3.47.2'` ❌ (doesn't exist)
- **After:** `flutter-version: '3.47.1'` ✅ (latest stable)

### 2. **Added .env File Decoding** ✅
- Now decodes `ENV_FILE` secret to `viva_app/.env`
- Required for Supabase URL, API keys, etc.

### 3. **Added APK Verification Step** ✅
- Verifies the APK was built successfully
- Shows file size in logs
- Fails early if APK is missing

---

## 🔐 Required GitHub Secrets

You need to configure these secrets in your repository:
**Settings → Secrets and variables → Actions → New repository secret**

### **1. KEYSTORE_BASE64** (Required)
Your Android signing keystore encoded in base64.

**To create:**
```bash
# On your local machine where keystore.jks exists
base64 -w 0 viva_app/android/keystore.jks > keystore_base64.txt
# Copy the contents of keystore_base64.txt to GitHub secret
```

**Windows PowerShell:**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("viva_app\android\keystore.jks")) | Out-File keystore_base64.txt
```

---

### **2. KEYSTORE_PASSWORD** (Required)
Password for your keystore file.

**Example:** `MyStr0ngP@ssw0rd`

---

### **3. KEY_ALIAS** (Required)
The alias name used when creating the keystore.

**Example:** `viva_upload_key`

---

### **4. KEY_PASSWORD** (Required)
Password for the key alias (often same as keystore password).

**Example:** `MyStr0ngP@ssw0rd`

---

### **5. GOOGLE_SERVICES_JSON** (Required)
Your Firebase `google-services.json` file encoded in base64.

**To create:**
```bash
# On your local machine
base64 -w 0 viva_app/android/app/google-services.json > google_services_base64.txt
# Copy the contents to GitHub secret
```

**Windows PowerShell:**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("viva_app\android\app\google-services.json")) | Out-File google_services_base64.txt
```

---

### **6. ENV_FILE** (NEW - Required)
Your `.env` file with Supabase credentials encoded in base64.

**Content should be like:**
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-key-here
API_BASE_URL=https://api.yourdomain.com
```

**To create:**
```bash
base64 -w 0 viva_app/.env > env_base64.txt
# Copy the contents to GitHub secret
```

**Windows PowerShell:**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("viva_app\.env")) | Out-File env_base64.txt
```

---

## 🚀 How to Trigger a Build

### **Method 1: Manual Trigger (Recommended for testing)**
1. Go to your GitHub repository
2. Click **Actions** tab
3. Select **Build Release APK** workflow
4. Click **Run workflow** button
5. Select branch (usually `main`)
6. Click **Run workflow**

### **Method 2: Git Tag (Automated)**
```bash
# Create and push a version tag
git tag v1.0.2
git push origin v1.0.2
```

This automatically triggers the build.

---

## 📥 Download Your APK

After the build completes:

1. Go to the **Actions** tab
2. Click on your completed workflow run
3. Scroll down to **Artifacts** section
4. Click **viva-release-apk** to download
5. Extract the ZIP file to get `app-release.apk`

**Note:** Artifacts are kept for **30 days**.

---

## 🔍 What Happens During Build

```
1. Checkout code from repository
   ↓
2. Setup Java 17 (required for Android build)
   ↓
3. Setup Flutter 3.47.1 (stable channel)
   ↓
4. Decode secrets:
   - keystore.jks → viva_app/android/keystore.jks
   - google-services.json → viva_app/android/app/google-services.json
   - .env → viva_app/.env
   ↓
5. Flutter pub get (download dependencies)
   ↓
6. Flutter build apk --release
   - Uses keystore for signing
   - Enables R8 minification & shrinking
   - Applies ProGuard rules
   ↓
7. Verify APK was created successfully
   ↓
8. Upload APK as downloadable artifact
```

---

## ⚙️ Build Configuration Summary

| Setting | Value |
|---------|-------|
| **Runner** | `ubuntu-latest` |
| **Java Version** | 17 (Temurin distribution) |
| **Flutter Version** | 3.47.1 (stable) |
| **Build Type** | Release (signed) |
| **Minification** | Enabled (R8) |
| **Shrink Resources** | Enabled |
| **ProGuard** | Custom rules applied |
| **Artifact Retention** | 30 days |

---

## 🐛 Troubleshooting

### **Build fails with "keystore not found"**
- Check `KEYSTORE_BASE64` secret is set correctly
- Verify base64 encoding has no line breaks (`-w 0` flag)

### **Build fails with "google-services.json not found"**
- Check `GOOGLE_SERVICES_JSON` secret is set
- Verify it's the correct Firebase config for your app

### **Build fails with "Supabase URL not found"**
- Check `ENV_FILE` secret is set
- Verify `.env` file contains all required variables

### **Signing failed / Invalid keystore**
- Verify `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` are correct
- They must match what was used when creating the keystore

### **Flutter version not found**
- The workflow now uses `3.47.1` which is correct
- If it still fails, check Flutter's release page for latest stable

### **APK not uploaded**
- Check the "Verify APK exists" step in logs
- Look for build errors in the "Build release APK" step

---

## 📝 Local Testing (Before Pushing)

Test your release build locally first:

```bash
cd viva_app

# Clean previous builds
flutter clean
flutter pub get

# Build release APK (uses local key.properties)
flutter build apk --release

# Verify APK exists
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

If this works locally, the GitHub Actions build should work too (assuming secrets are configured correctly).

---

## 🔄 Updating Your Secrets

If you need to update any secret:

1. Go to **Settings → Secrets and variables → Actions**
2. Click on the secret name
3. Click **Update secret**
4. Paste new base64-encoded value
5. Click **Update secret**

**Note:** Re-run your workflow after updating secrets.

---

## 📦 Next Steps After Build

Once you have your signed APK:

1. **Test on physical devices** (different Android versions)
2. **Internal testing** with friends/family
3. **Upload to Google Play Console** (Internal testing track)
4. **Promote to closed beta** after internal testing
5. **Production release** after beta testing

---

## 🎯 Checklist Before First Build

- [ ] All 6 secrets configured in GitHub
- [ ] `key.properties` file exists locally (for reference)
- [ ] `.env` file exists locally and in secret
- [ ] `google-services.json` exists and is correctly configured
- [ ] Keystore file exists and passwords are known
- [ ] Flutter version updated to 3.47.1 ✅
- [ ] Local release build works
- [ ] Committed and pushed workflow changes ✅

---

## 📞 Support

If builds continue to fail:
1. Check the full logs in GitHub Actions
2. Look for the specific error message
3. Google the error with "Flutter" + "GitHub Actions"
4. Check if secrets are properly base64 encoded

**Common issue:** Line breaks in base64 secrets. Always use `-w 0` flag or PowerShell one-liner.

---

**Last Updated:** January 2025  
**Flutter Version:** 3.47.1  
**Workflow Version:** 2.0
