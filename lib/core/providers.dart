import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/menu_pro_account_service.dart';
import '../features/auth/profile.dart';
import '../features/auth/profile_repository.dart';
import '../features/menu/menu.dart';
import '../features/menu/menu_repository.dart';
import '../features/restaurant/restaurant.dart';
import '../features/restaurant/restaurant_membership.dart';
import '../features/restaurant/restaurant_repository.dart';
import '../features/theme_settings/theme_model.dart';
import '../features/theme_settings/theme_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final menuProAccountServiceProvider = Provider<MenuProAccountService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MenuProAccountService(client);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProfileRepository(client);
});

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return RestaurantRepository(client);
});

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MenuRepository(client);
});

final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ThemeRepository(client);
});

final availableRestaurantMembershipsProvider =
    FutureProvider<List<RestaurantMembership>>((ref) async {
  final profileRepository = ref.watch(profileRepositoryProvider);
  var profiles = await profileRepository.findActiveProfiles();

  if (profiles.isEmpty) {
    final accountService = ref.watch(menuProAccountServiceProvider);
    await accountService.claimAccessFromAllowedEmail();
    profiles = await profileRepository.findActiveProfiles();
  }

  if (profiles.isEmpty) {
    return const [];
  }

  final restaurantRepository = ref.watch(restaurantRepositoryProvider);
  final restaurants = await restaurantRepository.getRestaurantsByIds(
    profiles.map((profile) => profile.restaurantId),
  );
  final restaurantsById = {
    for (final restaurant in restaurants) restaurant.id: restaurant,
  };

  final memberships = <RestaurantMembership>[];
  for (final profile in profiles) {
    final restaurant = restaurantsById[profile.restaurantId];
    if (restaurant == null || !restaurant.hasMenuPro) {
      continue;
    }

    memberships.add(
      RestaurantMembership(profile: profile, restaurant: restaurant),
    );
  }

  memberships.sort(
    (left, right) => left.restaurant.name.toLowerCase().compareTo(
          right.restaurant.name.toLowerCase(),
        ),
  );
  return memberships;
});

final restaurantMembershipsRealtimeProvider = Provider.autoDispose<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;

  if (userId == null) {
    return;
  }

  var disposed = false;

  final channel = client
      .channel('menu-pro-memberships-$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: userId,
        ),
        callback: (payload) {
          if (disposed) return;

          final isDelete =
              payload.eventType == PostgresChangeEvent.delete;
          final isRevocationUpdate =
              payload.eventType == PostgresChangeEvent.update &&
              payload.newRecord['is_hired'] == false;

          if (isDelete || isRevocationUpdate) {
            final record =
                isDelete ? payload.oldRecord : payload.newRecord;
            final removedRestaurantId =
                record['restaurant_id']?.toString();
            final lastCurrentRestaurantId = ref.read(
              lastCurrentRestaurantIdProvider,
            );

            if (removedRestaurantId != null &&
                removedRestaurantId == lastCurrentRestaurantId) {
              ref.read(selectedRestaurantIdProvider.notifier).state = null;
              ref.read(currentRestaurantRemovedProvider.notifier).state = true;
            }
          }

          ref.invalidate(availableRestaurantMembershipsProvider);
        },
      )
      .subscribe();

  ref.onDispose(() {
    disposed = true;
    channel.unsubscribe();
  });
});

final selectedRestaurantIdProvider = StateProvider<String?>((ref) => null);
final lastCurrentRestaurantIdProvider = StateProvider<String?>((ref) => null);
final currentRestaurantRemovedProvider = StateProvider<bool>((ref) => false);

final currentRestaurantMembershipProvider =
    FutureProvider<RestaurantMembership>((ref) async {
  final memberships = await ref.watch(
    availableRestaurantMembershipsProvider.future,
  );

  if (memberships.isEmpty) {
    throw Exception(
      'Nessun ristorante con Menu Pro attivo è disponibile per questo account.',
    );
  }

  if (memberships.length == 1) {
    return memberships.single;
  }

  final selectedRestaurantId = ref.watch(selectedRestaurantIdProvider);
  if (selectedRestaurantId == null) {
    throw Exception('Seleziona un ristorante.');
  }

  for (final membership in memberships) {
    if (membership.restaurantId == selectedRestaurantId) {
      return membership;
    }
  }

  throw Exception('Seleziona un ristorante.');
});

final currentProfileProvider = FutureProvider<Profile>((ref) async {
  final membership = await ref.watch(
    currentRestaurantMembershipProvider.future,
  );
  return membership.profile;
});

final currentMenuProAccessProvider = FutureProvider<bool>((ref) async {
  final membership = await ref.watch(
    currentRestaurantMembershipProvider.future,
  );

  if (membership.profile.isOwner) {
    return true;
  }

  final accountService = ref.watch(menuProAccountServiceProvider);
  return accountService.canManageMenuPro(
    restaurantId: membership.restaurantId,
  );
});

final menuProPermissionRealtimeProvider =
    FutureProvider.autoDispose<void>((ref) async {
  final membership = await ref.watch(
    currentRestaurantMembershipProvider.future,
  );

  if (membership.profile.isOwner) {
    return;
  }

  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;

  if (userId == null) {
    return;
  }

  var disposed = false;

  final channel = client
      .channel(
        'menu-pro-permission-$userId-${membership.restaurantId}',
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'restaurant_allowed_emails',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'restaurant_id',
          value: membership.restaurantId,
        ),
        callback: (_) {
          if (disposed) return;

          ref.invalidate(currentMenuProAccessProvider);
        },
      )
      .subscribe();

  ref.onDispose(() {
    disposed = true;
    channel.unsubscribe();
  });
});

final currentRestaurantProvider = FutureProvider<Restaurant>((ref) async {
  final membership = await ref.watch(
    currentRestaurantMembershipProvider.future,
  );
  return membership.restaurant;
});

final currentMenuProvider = FutureProvider<MenuModel>((ref) async {
  final restaurant = await ref.watch(currentRestaurantProvider.future);
  final repo = ref.watch(menuRepositoryProvider);
  return repo.getCurrentMenu(restaurant);
});

final currentThemeProvider = FutureProvider<ThemeModel?>((ref) async {
  final restaurant = await ref.watch(currentRestaurantProvider.future);
  final repo = ref.watch(themeRepositoryProvider);
  return repo.getThemeForRestaurant(restaurant.id);
});

enum AuthFlowPhase {
  idle,
  selectingRestaurant,
}

final authFlowControllerProvider =
    StateNotifierProvider<AuthFlowController, AuthFlowPhase>((ref) {
  return AuthFlowController(ref);
});

class AuthFlowController extends StateNotifier<AuthFlowPhase> {
  final Ref _ref;

  AuthFlowController(this._ref) : super(AuthFlowPhase.idle);

  void _invalidateCurrentRestaurantScope() {
    _ref.invalidate(currentRestaurantMembershipProvider);
    _ref.invalidate(currentProfileProvider);
    _ref.invalidate(currentRestaurantProvider);
    _ref.invalidate(currentMenuProAccessProvider);
    _ref.invalidate(currentMenuProvider);
    _ref.invalidate(currentThemeProvider);
  }

  Future<void> selectRestaurant({
    required String restaurantId,
    required GoRouter router,
  }) async {
    state = AuthFlowPhase.selectingRestaurant;

    try {
      _invalidateCurrentRestaurantScope();

      _ref.read(selectedRestaurantIdProvider.notifier).state = restaurantId;
      _ref.read(lastCurrentRestaurantIdProvider.notifier).state = restaurantId;
      _ref.read(currentRestaurantRemovedProvider.notifier).state = false;

      try {
        await _ref.read(currentRestaurantMembershipProvider.future);
        await _ref.read(currentMenuProAccessProvider.future);
        router.go('/');
      } catch (_) {
        // OwnerGate mostrerà l'eventuale errore reale soltanto
        // dopo la fine della transizione.
      }
    } finally {
      state = AuthFlowPhase.idle;
    }
  }
}
