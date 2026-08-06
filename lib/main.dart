import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'features/auth/auth_flow_service.dart';

bool _isPasswordResetExpiredError(Object error) {
  final text = error.toString().toLowerCase();

  return text.contains('otp_expired') ||
      text.contains('email link is invalid or has expired');
}

Future<void> _handlePasswordResetExpiredError() async {
  AuthFlowService.enterPasswordResetExpiredMode();

  try {
    await Supabase.instance.client.auth.signOut(
      scope: SignOutScope.local,
    );
  } catch (_) {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  _navigateWhenReady('/reset-password-expired');
}

String? _pendingMetadata(Session? session, String key) {
  final raw = session?.user.userMetadata?[key];

  if (raw is! String) {
    return null;
  }

  final value = raw.trim();
  return value.isEmpty ? null : value;
}

void _navigateWhenReady(String location) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    appRouter.go(location);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    if (_isPasswordResetExpiredError(error)) {
      unawaited(_handlePasswordResetExpiredError());
      return true;
    }

    return false;
  };

  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.isEmpty) {
    throw Exception('Variabili Supabase mancanti nel file .env');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final session = data.session;

    switch (data.event) {
      case AuthChangeEvent.signedOut:
        AuthFlowService.exitPasswordRecoveryMode();
        AuthFlowService.exitEmailConfirmationMode();
        appRouter.refresh();
        break;

      case AuthChangeEvent.passwordRecovery:
        AuthFlowService.exitPasswordResetExpiredMode();
        AuthFlowService.enterPasswordRecoveryMode();
        _navigateWhenReady('/reset-password');
        break;

      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.userUpdated:
      case AuthChangeEvent.tokenRefreshed:
        final pendingRestaurantName = _pendingMetadata(
          session,
          'pending_restaurant_name',
        );
        final pendingRestaurantSlug = _pendingMetadata(
          session,
          'pending_restaurant_slug',
        );

        if (session?.user.emailConfirmedAt != null &&
            pendingRestaurantName != null &&
            pendingRestaurantSlug != null) {
          AuthFlowService.enterRestaurantEmailConfirmationMode(
            email: session?.user.email ?? '',
            restaurantName: pendingRestaurantName,
            restaurantSlug: pendingRestaurantSlug,
          );
          _navigateWhenReady('/complete-restaurant');
          break;
        }

        if (session?.user.emailConfirmedAt != null &&
            AuthFlowService.pendingConfirmationEmail.value != null) {
          AuthFlowService.enterEmailConfirmationMode(
            email: session?.user.email ??
                AuthFlowService.pendingConfirmationEmail.value,
          );
        }
        break;

      default:
        break;
    }
  });

  runApp(const ProviderScope(child: MangialoquiMenuApp()));
}
