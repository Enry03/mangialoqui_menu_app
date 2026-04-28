import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import 'appearance_repository.dart';

final appearanceRepositoryProvider = Provider<AppearanceRepository>((ref) {
  return AppearanceRepository(Supabase.instance.client);
});

final menuAppearanceProvider = FutureProvider<MenuAppearance>((ref) async {
  final restaurant = await ref.watch(currentRestaurantProvider.future);
  final repo = ref.watch(appearanceRepositoryProvider);
  return repo.ensureAppearance(restaurant.id);
});
