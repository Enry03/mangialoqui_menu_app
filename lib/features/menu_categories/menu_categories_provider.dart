import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import 'menu_categories_repository.dart';
import 'menu_category.dart';

final menuCategoriesRepositoryProvider = Provider<MenuCategoriesRepository>((
  ref,
) {
  return MenuCategoriesRepository(Supabase.instance.client);
});

final menuCategoriesProvider = FutureProvider<List<MenuCategory>>((ref) async {
  final menu = await ref.watch(currentMenuProvider.future);
  final repository = ref.watch(menuCategoriesRepositoryProvider);
  return repository.getCategories(menu.id);
});
