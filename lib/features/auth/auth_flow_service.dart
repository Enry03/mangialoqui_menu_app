import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthFlowService {
  static const confirmEmailRedirect =
      'mangialoquimenu://confirm-email';
  static const resetPasswordRedirect =
      'mangialoquimenu://reset-password';

  static final ValueNotifier<bool> isPasswordRecoveryMode =
      ValueNotifier<bool>(false);

  static final ValueNotifier<bool> isPasswordResetExpiredMode =
      ValueNotifier<bool>(false);

  static final ValueNotifier<bool> isEmailConfirmationMode =
      ValueNotifier<bool>(false);

  static final ValueNotifier<String?> pendingConfirmationEmail =
      ValueNotifier<String?>(null);

  static final ValueNotifier<String?> pendingRestaurantName =
      ValueNotifier<String?>(null);

  static final ValueNotifier<String?> pendingRestaurantSlug =
      ValueNotifier<String?>(null);

  static RealtimeChannel? _accountLogoutChannel;
  static String? _accountLogoutUserId;
  static bool _localLogoutInProgress = false;

  static final String _fallbackDeviceKey =
      'device:${DateTime.now().microsecondsSinceEpoch}:${Random.secure().nextInt(1 << 32)}';

  static void enterPasswordRecoveryMode() {
    isPasswordResetExpiredMode.value = false;
    isPasswordRecoveryMode.value = true;
  }

  static void exitPasswordRecoveryMode() {
    isPasswordRecoveryMode.value = false;
  }

  static void enterPasswordResetExpiredMode() {
    isPasswordRecoveryMode.value = false;
    isPasswordResetExpiredMode.value = true;
  }

  static void exitPasswordResetExpiredMode() {
    isPasswordResetExpiredMode.value = false;
  }

  static void enterEmailConfirmationMode({String? email}) {
    pendingConfirmationEmail.value = email;
    isEmailConfirmationMode.value = true;
  }

  static void enterRestaurantEmailConfirmationMode({
    required String email,
    required String restaurantName,
    required String restaurantSlug,
  }) {
    pendingConfirmationEmail.value = email;
    pendingRestaurantName.value = restaurantName;
    pendingRestaurantSlug.value = restaurantSlug;
    isEmailConfirmationMode.value = true;
  }

  static void exitEmailConfirmationMode() {
    isEmailConfirmationMode.value = false;
    pendingConfirmationEmail.value = null;
    pendingRestaurantName.value = null;
    pendingRestaurantSlug.value = null;
  }

  static Map<String, dynamic>? _currentJwtPayload() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) return null;

    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final raw = jsonDecode(decoded);

      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {
      return null;
    }

    return null;
  }

  static String _currentSessionKey() {
    final payload = _currentJwtPayload();

    final sessionId = payload?['session_id'] ?? payload?['sid'];
    final text = sessionId?.toString().trim();

    if (text != null && text.isNotEmpty) {
      return 'session:$text';
    }

    return _fallbackDeviceKey;
  }

  static DateTime? _currentTokenIssuedAt() {
    final payload = _currentJwtPayload();
    final raw = payload?['iat'];

    int? seconds;

    if (raw is int) {
      seconds = raw;
    } else if (raw is num) {
      seconds = raw.toInt();
    } else if (raw is String) {
      seconds = int.tryParse(raw);
    }

    if (seconds == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static Future<void> startAccountLogoutWatcher() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      await stopAccountLogoutWatcher();
      return;
    }

    if (_accountLogoutUserId == userId && _accountLogoutChannel != null) {
      await checkAccountLogoutStateNow();
      return;
    }

    await stopAccountLogoutWatcher();

    _accountLogoutUserId = userId;

    final safeUserId = userId.replaceAll('-', '_');
    final channel = supabase.channel('account_logout_state_$safeUserId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'account_logout_state',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        unawaited(_handleAccountLogoutState(payload.newRecord));
      },
    );

    _accountLogoutChannel = channel;

    var hasSubscribedOnce = false;

    channel.subscribe((status, error) {
      if (status != RealtimeSubscribeStatus.subscribed) return;

      if (!hasSubscribedOnce) {
        hasSubscribedOnce = true;
        return;
      }

      unawaited(checkAccountLogoutStateNow());
    });

    await checkAccountLogoutStateNow();
  }

  static Future<void> stopAccountLogoutWatcher() async {
    final channel = _accountLogoutChannel;

    _accountLogoutChannel = null;
    _accountLogoutUserId = null;

    if (channel == null) return;

    try {
      await Supabase.instance.client.removeChannel(channel);
    } catch (_) {
      // niente
    }
  }

  static Future<void> reconcileAccountLogoutStateNow() async {
    if (_localLogoutInProgress) return;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return;

    final row =
        await supabase
            .from('account_logout_state')
            .select(
              'user_id, force_logout_after, keep_session_key, reason, updated_at',
            )
            .eq('user_id', userId)
            .maybeSingle();

    if (row == null) return;

    await _handleAccountLogoutState(Map<String, dynamic>.from(row));
  }

  static Future<void> checkAccountLogoutStateNow() async {
    try {
      await reconcileAccountLogoutStateNow();
    } catch (_) {
      // Controllo logout non bloccante: se fallisce, la sessione resta invariata.
    }
  }

  static Future<void> _handleAccountLogoutState(
    Map<String, dynamic> record,
  ) async {
    if (_localLogoutInProgress) return;

    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) return;

    final recordUserId = record['user_id']?.toString();
    if (recordUserId != currentUserId) return;

    final keepSessionKey = record['keep_session_key']?.toString();
    final currentSessionKey = _currentSessionKey();

    if (keepSessionKey != null && keepSessionKey == currentSessionKey) {
      return;
    }

    final forceLogoutRaw = record['force_logout_after']?.toString();
    if (forceLogoutRaw == null || forceLogoutRaw.isEmpty) return;

    final forceLogoutAfter = DateTime.tryParse(forceLogoutRaw)?.toUtc();
    if (forceLogoutAfter == null) return;

    final issuedAt = _currentTokenIssuedAt();

    if (issuedAt != null && issuedAt.isAfter(forceLogoutAfter)) {
      return;
    }

    await _signOutOnlyThisDevice();
  }

  static Future<void> _signOutOnlyThisDevice() async {
    if (_localLogoutInProgress) return;

    _localLogoutInProgress = true;

    try {
      await stopAccountLogoutWatcher();
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        // niente
      }
    } finally {
      _localLogoutInProgress = false;
    }
  }

  static Future<void> requestSignOutOtherDevices() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      throw StateError('Utente non autenticato.');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    await supabase.from('account_logout_state').upsert({
      'user_id': userId,
      'force_logout_after': now,
      'keep_session_key': _currentSessionKey(),
      'reason': 'manual_others',
      'updated_at': now,
    }, onConflict: 'user_id');

    try {
      await supabase.auth.signOut(scope: SignOutScope.others);
    } catch (_) {
      // La disconnessione vera passa dal DB.
    }
  }

  static Future<void> requestSignOutEverywhereAfterPasswordChange() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      throw StateError('Utente non autenticato.');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    _localLogoutInProgress = true;

    try {
      await supabase.from('account_logout_state').upsert({
        'user_id': userId,
        'force_logout_after': now,
        'keep_session_key': null,
        'reason': 'password_change',
        'updated_at': now,
      }, onConflict: 'user_id');

      await supabase.auth.signOut(scope: SignOutScope.global);
    } finally {
      _localLogoutInProgress = false;
    }
  }
}
