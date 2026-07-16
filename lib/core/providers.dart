import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/menu_pro_account_service.dart';
import '../features/auth/profile.dart';
import '../features/auth/profile_repository.dart';
import '../features/menu/menu.dart';
import '../features/menu/menu_repository.dart';
import '../features/restaurant/restaurant.dart';
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

final currentProfileProvider = FutureProvider<Profile>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);

  var profile = await repo.findCurrentProfile();

  if (profile != null) {
    return profile;
  }

  final accountService = ref.watch(menuProAccountServiceProvider);
  await accountService.claimAccessFromAllowedEmail();

  profile = await repo.findCurrentProfile();

  if (profile == null) {
    throw Exception(
      'Il tuo account non è autorizzato ad accedere a questo ristorante.',
    );
  }

  return profile;
});

final currentRestaurantProvider = FutureProvider<Restaurant>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final repo = ref.watch(restaurantRepositoryProvider);
  return repo.getRestaurantForProfile(profile);
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
