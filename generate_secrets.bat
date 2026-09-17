@echo off
echo ================================================
echo GitHub Actions Secrets Generator
echo ================================================
echo.

echo This script will generate base64-encoded secrets for GitHub Actions.
echo Output files will be created in the current directory.
echo.

echo [1/3] Generating KEYSTORE_BASE64...
if exist "viva_app\android\keystore.jks" (
    powershell -Command "[Convert]::ToBase64String([IO.File]::ReadAllBytes('viva_app\android\keystore.jks'))" > keystore_base64.txt
    echo ✓ keystore_base64.txt created
) else (
    echo ✗ keystore.jks not found at viva_app\android\keystore.jks
)
echo.

echo [2/3] Generating GOOGLE_SERVICES_JSON...
if exist "viva_app\android\app\google-services.json" (
    powershell -Command "[Convert]::ToBase64String([IO.File]::ReadAllBytes('viva_app\android\app\google-services.json'))" > google_services_base64.txt
    echo ✓ google_services_base64.txt created
) else (
    echo ✗ google-services.json not found at viva_app\android\app\google-services.json
)
echo.

echo [3/3] Generating ENV_FILE...
if exist "viva_app\.env" (
    powershell -Command "[Convert]::ToBase64String([IO.File]::ReadAllBytes('viva_app\.env'))" > env_base64.txt
    echo ✓ env_base64.txt created
) else (
    echo ✗ .env not found at viva_app\.env
)
echo.

echo ================================================
echo DONE!
echo ================================================
echo.
echo Generated files:
dir /b *_base64.txt 2>nul
echo.
echo Next steps:
echo 1. Open each *_base64.txt file
echo 2. Copy the entire contents (it's one long line)
echo 3. Go to GitHub: Settings → Secrets and variables → Actions
echo 4. Create/update these secrets:
echo    - KEYSTORE_BASE64 (from keystore_base64.txt)
echo    - GOOGLE_SERVICES_JSON (from google_services_base64.txt)
echo    - ENV_FILE (from env_base64.txt)
echo.
echo IMPORTANT: Also set these as text secrets (not base64):
echo    - KEYSTORE_PASSWORD (your keystore password)
echo    - KEY_ALIAS (your key alias name)
echo    - KEY_PASSWORD (your key password)
echo.
pause
