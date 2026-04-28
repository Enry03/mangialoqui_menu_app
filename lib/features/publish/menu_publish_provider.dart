import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import 'menu_publish_repository.dart';

final menuPublishRepositoryProvider = Provider<MenuPublishRepository>((ref) {
  return MenuPublishRepository(Supabase.instance.client);
});

final menuVersionsProvider = FutureProvider<List<MenuVersion>>((ref) async {
  final menu = await ref.watch(currentMenuProvider.future);
  final repo = ref.watch(menuPublishRepositoryProvider);
  return repo.getVersions(menu);
});

final menuAndRestaurantProvider = FutureProvider<Tuple2<dynamic, dynamic>>((
  ref,
) async {
  final restaurant = await ref.watch(currentRestaurantProvider.future);
  final menu = await ref.watch(currentMenuProvider.future);
  return Tuple2(restaurant, menu);
});

class Tuple2<A, B> {
  final A first;
  final B second;

  const Tuple2(this.first, this.second);
}
