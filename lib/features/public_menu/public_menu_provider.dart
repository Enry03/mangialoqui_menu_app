import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'public_menu_repository.dart';

final publicMenuRepositoryProvider = Provider<PublicMenuRepository>((ref) {
  return PublicMenuRepository(Supabase.instance.client);
});

final publicMenuProvider = FutureProvider.family<PublicMenuData, String>((
  ref,
  restaurantSlug,
) async {
  final repo = ref.watch(publicMenuRepositoryProvider);
  return repo.loadPublicMenu(restaurantSlug);
});
