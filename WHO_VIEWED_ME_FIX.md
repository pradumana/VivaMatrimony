# Who Viewed Me Tab - Error Fix

## Problem
The "Who Viewed My Profile" tab was showing an error.

## Root Causes (Possible)

1. **Backend SQL query failure** - The query might fail if:
   - `profile_views` table is empty (normal for new installs)
   - Missing or corrupted data in related tables (users, profiles, photos, current_locations)
   - Database connection issues

2. **Frontend data parsing** - The Flutter app expected specific data format
   - Original code didn't handle null/missing response gracefully
   - No error logging to identify the issue

3. **Missing authentication** - If auth token is invalid/expired

## Changes Made

### 1. Frontend (Flutter) - `who_viewed_me_screen.dart`
- ✅ Added comprehensive error handling in `_viewersProvider`
- ✅ Added debug logging to track API responses
- ✅ Added null checks and type validation
- ✅ Improved error messages in UI
- ✅ Added stack trace logging for debugging

**Before:**
```dart
final _viewersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final r = await ref.read(apiClientProvider).get('/profile/viewers');
  return (r.data['viewers'] as List).cast<Map<String, dynamic>>();
});
```

**After:**
```dart
final _viewersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final r = await ref.read(apiClientProvider).get('/profile/viewers');
    debugPrint('Profile viewers response: ${r.data}');
    
    if (r.data == null || r.data is! Map) {
      throw Exception('Invalid response format');
    }
    
    final viewers = r.data['viewers'];
    if (viewers == null) {
      return [];
    }
    
    if (viewers is! List) {
      throw Exception('Expected viewers to be a list, got ${viewers.runtimeType}');
    }
    
    return viewers.cast<Map<String, dynamic>>();
  } catch (e, stack) {
    debugPrint('Error fetching profile viewers: $e');
    debugPrint('Stack trace: $stack');
    rethrow;
  }
});
```

### 2. Backend (Python) - `profile.py`
- ✅ Added try-catch around the entire endpoint
- ✅ Added error logging with traceback
- ✅ Returns proper HTTP 500 with error details
- ✅ Added photo URL error handling

**Key addition:**
```python
try:
    # ... existing query logic
    return {"viewers": viewers, "count": len(viewers)}
except Exception as e:
    print(f"Error fetching profile viewers: {e}")
    import traceback
    traceback.print_exc()
    raise HTTPException(
        status_code=500,
        detail=f"Failed to fetch profile viewers: {str(e)}"
    )
```

### 3. Test Script - `test_viewers_endpoint.py`
Created a diagnostic script to verify:
- Database connection works
- `profile_views` table exists
- Query returns data correctly
- Sample data is valid

**Run with:**
```bash
cd backend
python test_viewers_endpoint.py
```

## How to Debug

### Step 1: Check Backend Logs
When you open the "Who Viewed Me" tab, check your backend logs for:
```
Error fetching profile viewers: [specific error]
```

### Step 2: Check Flutter Debug Console
Look for:
```
Profile viewers response: {viewers: [...]}
```
or
```
Error fetching profile viewers: [error details]
```

### Step 3: Run Test Script
```bash
cd backend
python test_viewers_endpoint.py
```

This will tell you if:
- ✓ Database connection works
- ✓ Table exists and has data
- ✓ Query runs successfully

## Common Issues & Solutions

### Issue: "No profile views yet"
**Not an error** - This is normal if:
- Fresh installation
- No one has viewed your profile yet

### Issue: SQL query fails
**Check:**
1. Database migrations are up to date
2. All required tables exist (profile_views, users, profiles, photos, current_locations)
3. Database URL is correct in `.env`

**Fix:**
```bash
# Check if migrations ran
cd supabase
# Verify tables exist
```

### Issue: "Invalid response format"
**Means:** Backend returned something other than `{viewers: [...]}`

**Check:**
1. Backend is running
2. API endpoint `/profile/viewers` is accessible
3. Authentication token is valid

### Issue: "Session expired. Please log in again."
**Fix:** Log out and log back in to refresh auth token

## Expected Behavior

### Empty State
When no one has viewed your profile:
- Shows icon with "No profile views yet"
- Shows subtitle "When someone views your profile, they'll appear here."

### With Data
Shows list of viewers with:
- Profile photo
- Name and age
- Location
- Verification badge (if verified)
- Time when they viewed ("Viewed 2h ago", etc.)
- Tap to view their profile

## Testing Checklist

- [ ] Backend starts without errors
- [ ] Can open "Who Viewed Me" tab
- [ ] Empty state shows correctly (if no views)
- [ ] Viewers list shows correctly (if has views)
- [ ] Can tap on a viewer to see their profile
- [ ] Error message shows if backend fails
- [ ] Retry button works if error occurs

## Next Steps

1. **Test the fix:**
   - Restart backend: `cd backend && python -m uvicorn app.main:app --reload`
   - Restart Flutter app
   - Open "Who Viewed Me" tab
   - Check logs for any errors

2. **If still errors:**
   - Run `test_viewers_endpoint.py`
   - Share the error message from backend logs
   - Share the error message from Flutter console

3. **Verify profile views are being tracked:**
   - Visit another user's profile
   - Check database: `SELECT * FROM profile_views;`
   - Should see a new row with viewer_id and viewed_id
