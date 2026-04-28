import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import 'ai_repository.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(Supabase.instance.client);
});

final aiHistoryProvider = FutureProvider<List<AiHistoryItem>>((ref) async {
  final restaurant = await ref.watch(currentRestaurantProvider.future);
  final repo = ref.watch(aiRepositoryProvider);
  return repo.getHistory(restaurant.id);
});
