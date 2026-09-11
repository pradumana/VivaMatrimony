import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight stale-while-revalidate cache backed by SharedPreferences.
/// Keys are namespaced so they never collide with other prefs.
class CacheService {
  static const _prefix = 'viva_cache_';
  static const _ttlSuffix = '_ttl';

  /// Store [data] under [key] with a [ttl]. Default TTL: 5 minutes.
  static Future<void> set(
    String key,
    dynamic data, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now().add(ttl).millisecondsSinceEpoch;
    await prefs.setString('$_prefix$key', jsonEncode(data));
    await prefs.setInt('$_prefix$key$_ttlSuffix', expiry);
  }

  /// Returns cached value if present (even if stale).
  /// Returns null if never cached.
  static Future<dynamic> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  /// True if key exists AND has not expired.
  static Future<bool> isFresh(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = prefs.getInt('$_prefix$key$_ttlSuffix');
    if (expiry == null) return false;
    return DateTime.now().millisecondsSinceEpoch < expiry;
  }

  /// Delete a specific key.
  static Future<void> invalidate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
    await prefs.remove('$_prefix$key$_ttlSuffix');
  }

  /// Delete all viva cache keys.
  static Future<void> invalidateAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
