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

  static Future<void> requestSignOutEverywhereAfterPasswordChange() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      throw StateError('Utente non autenticato.');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    await supabase.from('account_logout_state').upsert({
      'user_id': userId,
      'force_logout_after': now,
      'keep_session_key': null,
      'reason': 'password_change',
      'updated_at': now,
    }, onConflict: 'user_id');

    await supabase.auth.signOut(scope: SignOutScope.global);
  }
}
