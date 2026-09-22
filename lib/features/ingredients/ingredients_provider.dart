import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import 'ingredient.dart';
import 'ingredients_repository.dart';

final ingredientsRepositoryProvider = Provider<IngredientsRepository>((ref) {
  return IngredientsRepository(Supabase.instance.client);
});

final ingredientsProvider = FutureProvider<List<RestaurantIngredient>>((
  ref,
) async {
  final restaurant = await ref.watch(currentRestaurantProvider.future);
  final repository = ref.watch(ingredientsRepositoryProvider);
  return repository.getIngredients(restaurant.id);
});
