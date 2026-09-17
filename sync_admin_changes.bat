@echo off
echo ========================================
echo Syncing Admin Panel Changes to GitHub
echo ========================================
echo.

cd /d "D:\android\viva"

echo Staging files...
git add viva-admin/src/pages/subscriptions/SubscriptionsPage.tsx viva-admin/src/services/api.ts

echo.
echo Committing changes...
git commit -m "fix(admin): Add member search autocomplete for subscription payments" -m "Replace UUID text input with user-friendly autocomplete search" -m "- Search by member_id, phone, or name (min 3 chars)" -m "- Display results with member details" -m "- Send member_id to backend instead of UUID" -m "- Debounced search for performance" -m "- Backend already supports this (commit 9117d04)" -m "" -m "Fixes: Admin couldn't see user UUID to record payments"

echo.
echo Pushing to GitHub...
git push origin main

echo.
echo ========================================
echo Done! Admin panel changes synced.
echo ========================================
echo.
echo Next steps:
echo 1. Rebuild admin panel: cd viva-admin && npm run build
echo 2. Or redeploy if using CI/CD
echo 3. Clear browser cache and refresh admin panel
echo 4. Test: Search for "pank" or a phone number
echo.
pause
