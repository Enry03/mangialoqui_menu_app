import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../menu_categories/menu_categories_provider.dart';
import '../menu_items/menu_items_provider.dart';

final menuRealtimeSyncProvider = FutureProvider.autoDispose<void>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  StreamSubscription<List<Map<String, dynamic>>>? categoriesSub;
  StreamSubscription<List<Map<String, dynamic>>>? itemsSub;
  Timer? categoriesDebounce;
  Timer? itemsDebounce;
  var disposed = false;

  ref.onDispose(() {
    disposed = true;
    categoriesDebounce?.cancel();
    itemsDebounce?.cancel();
    categoriesSub?.cancel();
    itemsSub?.cancel();
  });

  final menu = await ref.watch(currentMenuProvider.future);

  if (disposed) {
    return;
  }

  void scheduleCategoriesRefresh() {
    if (disposed) {
      return;
    }

    categoriesDebounce?.cancel();
    categoriesDebounce = Timer(const Duration(milliseconds: 180), () {
      if (disposed) {
        return;
      }

      ref.invalidate(menuCategoriesProvider);
      ref.invalidate(allMenuCategoriesProvider);
    });
  }

  void scheduleItemsRefresh() {
    if (disposed) {
      return;
    }

    itemsDebounce?.cancel();
    itemsDebounce = Timer(const Duration(milliseconds: 180), () {
      if (disposed) {
        return;
      }

      ref.invalidate(menuItemsProvider);
      ref.invalidate(allMenuItemsProvider);
    });
  }

  categoriesSub = client
      .from('menu_categories')
      .stream(primaryKey: ['id'])
      .eq('menu_id', menu.id)
      .listen(
        (_) {
          scheduleCategoriesRefresh();
        },
        onError: (Object error, StackTrace stackTrace) {
          // Supabase Realtime gestisce la riconnessione automatica.
        },
      );

  itemsSub = client
      .from('menu_items')
      .stream(primaryKey: ['id'])
      .eq('menu_id', menu.id)
      .listen(
        (_) {
          scheduleItemsRefresh();
        },
        onError: (Object error, StackTrace stackTrace) {
          // Supabase Realtime gestisce la riconnessione automatica.
        },
      );
});
