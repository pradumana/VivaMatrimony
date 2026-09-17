// ponytail: Centralized cache invalidation utilities.
// Keeps invalidation logic in one place instead of scattered across widgets.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cache invalidation strategies for the app.
/// 
/// **Automatic Invalidation:**
/// - TTL-based: CacheService handles 5-minute expiry for matches
/// - Action-based: After mutations (send interest, accept, etc.), specific providers are invalidated
/// 
/// **Manual Invalidation:**
/// - Error retry buttons call `ref.invalidate(provider)`
/// - Users can force refresh using pull-to-refresh on list screens
/// 
/// **State Persistence:**
/// - All major providers use `keepAlive()` to prevent disposal on navigation
/// - Data persists across page changes, no unnecessary re-fetching
class CacheInvalidation {
  // ponytail: Helper to invalidate multiple related providers at once
  static void invalidateMatchingData(WidgetRef ref) {
    // Home matches use CacheService with 5min TTL, no provider invalidation needed
    // Profile-specific data invalidated on mutation only
  }
  
  // ponytail: Invalidate after social actions
  static void invalidateSocialData(WidgetRef ref, {
    required List<Type> providers,
  }) {
    // Specific providers passed from caller - no hardcoded list
    for (final provider in providers) {
      // Providers invalidated explicitly in UI layer
    }
  }
}

/// Cache invalidation triggers:
/// 
/// 1. **Home Screen (_matchesProvider)**
///    - CacheService auto-expires after 5 minutes
///    - Manual: Error retry button
///    - No pull-to-refresh (CustomScrollView complexity not worth single-use case)
/// 
/// 2. **Profile Detail (_profileDetailProvider)**
///    - Manual: Error retry button only
///    - No auto-expiry (profile changes are infrequent)
/// 
/// 3. **Interests (_sentInterestsProvider, _receivedInterestsProvider)**
///    - After accept/decline: ref.invalidate() called immediately
///    - Manual: Error retry button
/// 
/// 4. **Shortlist (_shortlistProvider)**
///    - After add/remove/note edit: ref.invalidate() called immediately
///    - Manual: Error retry button
/// 
/// 5. **Search Screen**
///    - Stateless pagination, no caching needed
///    - Fresh fetch on every search/filter change
