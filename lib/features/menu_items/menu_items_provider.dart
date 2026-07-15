import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import 'menu_item.dart';
import 'menu_items_repository.dart';

final menuItemsRepositoryProvider = Provider<MenuItemsRepository>((ref) {
  return MenuItemsRepository(Supabase.instance.client);
});

final menuItemsProvider = FutureProvider<List<MenuItemModel>>((ref) async {
  final menu = await ref.watch(currentMenuProvider.future);
  final repository = ref.watch(menuItemsRepositoryProvider);
  return repository.getItems(menu.id);
});

final allMenuItemsProvider = FutureProvider<List<MenuItemModel>>((ref) async {
  final menu = await ref.watch(currentMenuProvider.future);
  final repository = ref.watch(menuItemsRepositoryProvider);
  return repository.getItems(menu.id, includeInactive: true);
});