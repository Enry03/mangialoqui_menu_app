import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/ai/ai_page.dart';
import '../features/appearance/appearance_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/owner_gate.dart';
import '../features/availability/availability_page.dart';
import '../features/home/home_page.dart';
import '../features/menu/menu_page.dart';
import '../features/publish/publish_page.dart';
import '../features/public_menu/public_menu_page.dart';

final supabase = Supabase.instance.client;

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final session = supabase.auth.currentSession;
    final location = state.matchedLocation;
    final isOnLogin = location == '/login';
    final isPublicRoute = location.startsWith('/public/');

    if (isPublicRoute) {
      return null;
    }

    if (session == null && !isOnLogin) {
      return '/login';
    }

    if (session != null && isOnLogin) {
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
      path: '/',
      builder: (context, state) => const OwnerGate(
        child: HomePage(),
      ),
    ),
    GoRoute(
      path: '/menu',
      builder: (context, state) => const OwnerGate(
        child: MenuPage(),
      ),
    ),
    GoRoute(
      path: '/ai',
      builder: (context, state) => const OwnerGate(
        child: AiPage(),
      ),
    ),
    GoRoute(
      path: '/availability',
      builder: (context, state) => const OwnerGate(
        child: AvailabilityPage(),
      ),
    ),
    GoRoute(
      path: '/publish',
      builder: (context, state) => const OwnerGate(
        child: PublishPage(),
      ),
    ),
    GoRoute(
      path: '/appearance',
      builder: (context, state) => const OwnerGate(
        child: AppearancePage(),
      ),
    ),
    GoRoute(
      path: '/public/:slug',
      builder: (context, state) {
        final slug = state.pathParameters['slug']!;
        return PublicMenuPage(restaurantSlug: slug);
      },
    ),
  ],
);
