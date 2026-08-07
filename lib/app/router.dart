import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/ai/ai_page.dart';
import '../features/appearance/appearance_page.dart';
import '../features/auth/auth_flow_service.dart';
import '../features/auth/confirm_email_page.dart';
import '../features/auth/create_restaurant_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/owner_gate.dart';
import '../features/auth/register_page.dart';
import '../features/auth/reset_password_page.dart';
import '../features/availability/availability_page.dart';
import '../features/home/home_page.dart';
import '../features/menu/menu_page.dart';
import '../features/publish/publish_page.dart';
import '../features/public_menu/public_menu_page.dart';
import '../features/settings/settings_page.dart';
import '../shared/widgets/app_main_scaffold.dart';
import '../shared/widgets/restaurant_scoped_page.dart';

final supabase = Supabase.instance.client;

String? _pendingRestaurantMetadata(User? user, String key) {
  final raw = user?.userMetadata?[key];

  if (raw is! String) {
    return null;
  }

  final value = raw.trim();
  return value.isEmpty ? null : value;
}

final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: Listenable.merge([
    AuthFlowService.isPasswordRecoveryMode,
    AuthFlowService.isPasswordResetExpiredMode,
    AuthFlowService.isEmailConfirmationMode,
  ]),
  redirect: (context, state) {
    final session = supabase.auth.currentSession;
    final location = state.matchedLocation;
    final isPublicMenuRoute = location.startsWith('/public/');

    if (isPublicMenuRoute) {
      return null;
    }

    if (AuthFlowService.isPasswordResetExpiredMode.value &&
        location != '/reset-password-expired') {
      return '/reset-password-expired';
    }

    if (AuthFlowService.isPasswordRecoveryMode.value &&
        location != '/reset-password') {
      return '/reset-password';
    }

    final pendingRestaurantName = _pendingRestaurantMetadata(
      session?.user,
      'pending_restaurant_name',
    );
    final pendingRestaurantSlug = _pendingRestaurantMetadata(
      session?.user,
      'pending_restaurant_slug',
    );

    if (session != null &&
        pendingRestaurantName != null &&
        pendingRestaurantSlug != null &&
        location != '/complete-restaurant') {
      return '/complete-restaurant';
    }

    if (AuthFlowService.isEmailConfirmationMode.value &&
        location != '/confirm-email' &&
        location != '/complete-restaurant') {
      return '/confirm-email';
    }

    final publicAuthRoutes = {
      '/login',
      '/register',
      '/create-restaurant',
      '/confirm-email',
      '/reset-password',
      '/reset-password-expired',
      '/complete-restaurant',
    };

    if (session == null && !publicAuthRoutes.contains(location)) {
      return '/login';
    }

    if (session == null &&
        (location == '/reset-password' ||
            location == '/complete-restaurant') &&
        !AuthFlowService.isPasswordRecoveryMode.value) {
      return '/login';
    }

    if (session != null &&
        (location == '/login' ||
            location == '/register' ||
            location == '/create-restaurant')) {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/create-restaurant',
      builder: (context, state) => const CreateRestaurantPage(),
    ),
    GoRoute(
      path: '/confirm-email',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ??
            AuthFlowService.pendingConfirmationEmail.value ??
            '';
        return ConfirmEmailPage(email: email);
      },
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordPage(),
    ),
    GoRoute(
      path: '/reset-password-expired',
      builder: (context, state) =>
          const ResetPasswordExpiredPage(),
    ),
    GoRoute(
      path: '/complete-restaurant',
      builder: (context, state) =>
          const PendingRestaurantCreationPage(),
    ),
    GoRoute(
      path: '/public/:slug',
      builder: (context, state) {
        final slug = state.pathParameters['slug']!;
        return PublicMenuPage(restaurantSlug: slug);
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => OwnerGate(
        child: AppMainScaffold(navigationShell: navigationShell),
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const RestaurantScopedPage(
                child: HomePage(),
              ),
              routes: [
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const RestaurantScopedPage(
                    child: SettingsPage(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'access',
                      builder: (context, state) =>
                          const RestaurantScopedPage(
                        child: AccessManagementPage(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/menu',
              builder: (context, state) => const RestaurantScopedPage(
                child: MenuPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/ai',
              builder: (context, state) => const RestaurantScopedPage(
                child: AiPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/availability',
              builder: (context, state) => const RestaurantScopedPage(
                child: AvailabilityPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              redirect: (context, state) => '/more/publish',
              routes: [
                GoRoute(
                  path: 'publish',
                  builder: (context, state) => const RestaurantScopedPage(
                    child: PublishPage(),
                  ),
                ),
                GoRoute(
                  path: 'appearance',
                  builder: (context, state) => const RestaurantScopedPage(
                    child: AppearancePage(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
