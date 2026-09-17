# Admin User Search Troubleshooting

## Problem
Admin panel shows "Searching..." but never returns results when typing in Member Search field.

## Root Cause
Backend endpoint `/admin/users/search` exists in code but hasn't been deployed yet.

## Solution: Force Render to Redeploy

### Option 1: Trigger Manual Deploy on Render Dashboard
1. Go to https://dashboard.render.com
2. Click on **viva-api** service
3. Click **Manual Deploy** → **Deploy latest commit**
4. Wait for build to complete (~2-3 minutes)
5. Click on **viva-admin** service
6. Click **Manual Deploy** → **Deploy latest commit**
7. Wait for build to complete (~1-2 minutes)

### Option 2: Make a Dummy Commit (Forces Auto-Deploy)
```bash
cd D:\android\viva
echo. >> README.md
git add README.md
git commit -m "chore: trigger redeploy"
git push origin main
```
This will trigger auto-deploy for both services.

### Option 3: Check Render Auto-Deploy Settings
1. Go to https://dashboard.render.com
2. Click **viva-api** service
3. Go to **Settings** tab
4. Scroll to **Build & Deploy** section
5. Ensure **Auto-Deploy** is set to **Yes**
6. Check **Branch** is set to **main**
7. Repeat for **viva-admin** service

## Verify Backend Deployment

### Check if endpoint is live:
```bash
curl -X GET "https://api.vivamatrimony.in/api/v1/admin/users/search?query=test" \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN"
```

**Expected response (200 OK):**
```json
{
  "users": []
}
```

**If you get 404:** Backend hasn't deployed the new code yet.

## Verify Frontend Deployment

1. Open admin panel: https://admin.vivamatrimony.in
2. Open browser DevTools (F12)
3. Go to **Network** tab
4. Click "+ Record Payment" button
5. Type at least 3 characters in Member Search
6. Check Network tab for request to `/admin/users/search`

**If no request appears:** Clear browser cache (Ctrl+Shift+Delete)

**If request shows 404:** Backend not deployed

**If request shows 401:** Token expired, re-login

**If request shows 500:** Check backend logs on Render

## Check Render Build Logs

### Backend (viva-api):
1. Go to https://dashboard.render.com → viva-api
2. Click **Logs** tab
3. Look for latest deployment
4. Verify it says: `Uvicorn running on http://0.0.0.0:PORT`

### Admin (viva-admin):
1. Go to https://dashboard.render.com → viva-admin  
2. Click **Logs** tab
3. Look for latest build
4. Verify it says: `vite v5.x.x building for production...`
5. Should show: `✓ built in XXXXms`

## Common Issues

### Issue 1: Render Didn't Auto-Deploy
**Symptom:** Pushed to GitHub but services still show old commit
**Solution:** Check webhook: Settings → Deploy Hooks → GitHub webhook should be active

### Issue 2: Build Failed on Render
**Symptom:** Deploy started but failed
**Solution:** Click on failed deploy → read error logs → fix and re-push

### Issue 3: CORS Error in Browser Console
**Symptom:** Network tab shows CORS error for /admin/users/search
**Solution:** Check backend ALLOWED_ORIGINS includes admin domain:
```
ALLOWED_ORIGINS=https://admin.vivamatrimony.in,https://vivamatrimony.in
```

### Issue 4: 401 Unauthorized
**Symptom:** Search request returns 401
**Solution:** Admin token expired, logout and login again

### Issue 5: Empty Results for Known Users
**Symptom:** Search works but returns `{ "users": [] }` for existing members
**Solution:** Check database:
```sql
SELECT member_id, phone_normalized, full_name 
FROM users u
LEFT JOIN profiles p ON p.user_id = u.id
WHERE u.deleted_at IS NULL
LIMIT 10;
```

## Test Checklist

After Render deploys successfully:

- [ ] Clear browser cache (Ctrl+Shift+Delete)
- [ ] Logout and login to admin panel
- [ ] Click "+ Record Payment"
- [ ] Type 3+ characters in "Member Search"
- [ ] Should see "Searching..." for <1 second
- [ ] Should see dropdown with user results
- [ ] Click on a user
- [ ] Should show "✓ Selected: VM12345"
- [ ] Fill amount and submit
- [ ] Should show success message

## Quick Debug Commands

### Check latest deployment on Render:
```bash
# Backend last commit
curl -s https://api.vivamatrimony.in/api/v1/admin/dashboard | jq '.version'

# Or check manually in Render dashboard
# viva-api → Settings → scroll to "Repository Info"
```

### Check if search endpoint exists:
```bash
curl -I https://api.vivamatrimony.in/api/v1/admin/users/search
# Should return: 400 Bad Request (missing query param) or 401 Unauthorized
# Should NOT return: 404 Not Found
```

### Check frontend build date:
1. Open https://admin.vivamatrimony.in
2. View page source (Ctrl+U)
3. Look for build timestamp in HTML comments or check main.js file date

## Timeline

- **Commit 9117d04** (Jan 15): Added backend endpoint `/admin/users/search`
- **Commit 1e4c77e** (Jan 15): Added frontend autocomplete UI
- **Status**: Code is in GitHub ✅, waiting for Render deployment ❌

## Contact

If still not working after Render deploys:
1. Check Render build logs for errors
2. Check browser console (F12) for JavaScript errors
3. Check Network tab for API request/response
4. Take screenshot of error and share
