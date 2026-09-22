import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import 'menu_combo.dart';
import 'menu_combos_repository.dart';

final menuCombosRepositoryProvider = Provider<MenuCombosRepository>((ref) {
  return MenuCombosRepository(Supabase.instance.client);
});

final menuCombosProvider = FutureProvider<List<MenuCombo>>((ref) async {
  final menu = await ref.watch(currentMenuProvider.future);
  final repository = ref.watch(menuCombosRepositoryProvider);
  return repository.getCombos(menu.id);
});

final allMenuCombosProvider = FutureProvider<List<MenuCombo>>((ref) async {
  final menu = await ref.watch(currentMenuProvider.future);
  final repository = ref.watch(menuCombosRepositoryProvider);
  return repository.getCombos(menu.id, includeInactive: true);
});
