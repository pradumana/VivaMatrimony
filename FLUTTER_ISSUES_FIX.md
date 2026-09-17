# Flutter App Issues - Diagnosis & Fixes

## Summary
Three issues reported:
1. "Register Now" / "Create account" link not working
2. Biodata tab not loading
3. Connection page layout issues

---

## Issue #1: Register Link Not Working

### Diagnosis
The code is correct - navigation exists in `login_screen.dart` (line 153):
```dart
GestureDetector(
  onTap: () => context.go(AppRoutes.register),
  child: const Text('Create account', ...),
)
```

The router is properly configured in `app_router.dart` (line 91):
```dart
GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),
```

### Possible Causes
1. **App not rebuilt** - Old build cached without latest code
2. **Hot reload issue** - Changes not applied  
3. **Navigation blocked by redirect logic** - Auth state might be interfering

### Fix
Run a clean rebuild:
```bash
cd viva_app
flutter clean
flutter pub get
flutter run
```

### Alternative Fix
If the issue persists, there might be a redirect blocking navigation. Check the auth state in `app_router.dart` redirect logic (lines 59-82).

The redirect might be immediately sending users away from `/register` before the screen loads.

### Test
1. Open the app
2. Go to login screen  
3. Tap "Create account" text (below "New here?")
4. Should navigate to registration screen

---

## Issue #2: Biodata Tab Not Loading

### Diagnosis
The biodata screen fetches data from `/biodata` endpoint with a template parameter.

Provider at line 16-22:
```dart
final _biodataProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, template) async {
  final r = await ref.read(apiClientProvider).get(
    '/biodata',
    queryParameters: {'template': template},
  );
  return r.data as Map<String, dynamic>;
});
```

### Possible Causes
1. **Backend API error** - `/biodata` endpoint returning error
2. **Auth token expired** - API returning 401
3. **Network timeout** - Render cold start taking too long
4. **Missing data** - User profile incomplete, biodata can't be generated

### Fix Options

**Fix 1: Add Better Error Handling**
The screen shows generic "Could not load biodata status" on error. We need to show the actual error message.

**Fix 2: Check Backend Endpoint**
Verify the backend `/biodata` endpoint exists and returns proper data:
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.vivamatrimony.in/api/v1/biodata?template=traditional
```

**Fix 3: Add Retry Logic**
The screen has no retry button for loading state. Add pull-to-refresh.

### Immediate Fix
Add error details display:

In `biodata_screen.dart`, change line 113-115 from:
```dart
error: (_, __) => const Center(
    child: Text('Could not load biodata status.',
        style: TextStyle(color: AppTheme.textSecondary))),
```

To:
```dart
error: (error, stack) => Center(
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 60, color: AppTheme.error),
        const SizedBox(height: 16),
        const Text('Could not load biodata status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          onPressed: () => ref.invalidate(_biodataProvider),
        ),
      ],
    ),
  ),
),
```

This will show the actual error message and provide a retry button.

---

## Issue #3: Connection Page Layout Issues

### Diagnosis
The connections screen (`conversations_screen.dart`) displays mutual matches with:
- User photo (58x70)
- Name, age, location
- Verified badge
- "Mutually connected" status
- WhatsApp chat button

Layout is in `_ConnectionCard` (lines 93-280).

### Possible Layout Issues

**Issue 3a: Text Overflow**
Long names or locations might overflow. The name/age text doesn't have `overflow: TextOverflow.ellipsis`.

**Fix:**
Line 220-227, change to:
```dart
Text(
  '${c.fullName}${c.age != null ? ", ${c.age}" : ""}',
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: const TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 15,
    color: AppTheme.textPrimary,
  ),
),
```

**Issue 3b: Missing LoadingView/EmptyStateView Widgets**
Lines 74 and 79 reference widgets that might not exist:
- `LoadingView()`
- `EmptyStateView(...)`

These need to be defined or imported.

**Fix:** Add to imports at top of file:
```dart
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/empty_state_view.dart';
```

If these widgets don't exist, create them or replace with inline widgets:

Replace line 74:
```dart
loading: () => const Center(
  child: CircularProgressIndicator(color: AppTheme.primary),
),
```

Replace lines 79-83:
```dart
data: (connections) => connections.isEmpty
  ? Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, 
                size: 80, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(l.noConnectionsYet,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(l.noConnectionsMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    )
  : ListView.builder(...)
```

**Issue 3c: Image Loading Failures**
Photos might not load, causing layout shifts. The placeholder is defined but might not work properly.

**Fix:** Already handled with `_placeholder()` method, but ensure it has proper sizing:
```dart
Widget _placeholder() => Container(
  width: 58,
  height: 70,
  color: AppTheme.primaryContainer,
  child: const Icon(Icons.person_outline,
      color: AppTheme.primary, size: 28),
);
```

---

## Quick Fixes Summary

### For Register Link Issue:
```bash
cd viva_app
flutter clean && flutter pub get && flutter run
```

### For Biodata Loading Issue:
Add error display and retry button (see detailed fix above in biodata_screen.dart lines 113-115).

### For Connections Layout Issue:
1. Add `overflow: TextOverflow.ellipsis` to name text
2. Replace `LoadingView()` and `EmptyStateView()` with inline widgets
3. Verify placeholder sizing

---

## Testing Checklist

After fixes:
- [ ] Login screen → Click "Create account" → Should open register screen
- [ ] Navigate to Biodata tab → Should show status or detailed error
- [ ] Navigate to Connections → Should show loading, empty state, or list without overflow
- [ ] Test with long names in connections
- [ ] Test with no network connection
- [ ] Test with expired token

---

## Additional Notes

1. **All navigation uses GoRouter** - context.go() and context.push()
2. **All API calls use Dio** - via apiClientProvider
3. **All state management uses Riverpod** - FutureProvider, StateNotifier
4. **Auth state controls navigation** - redirect logic in app_router.dart

If issues persist, check:
- Backend API health: https://api.vivamatrimony.in/health
- Auth token validity: Check if user is logged in
- Network connectivity: Use Flutter DevTools to inspect API calls
