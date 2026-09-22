import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'review.dart';
import 'reviews_repository.dart';

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ReviewsRepository(client);
});

final reviewsProvider = FutureProvider<List<MenuReview>>((ref) async {
  final restaurant = await ref.watch(currentRestaurantProvider.future);
  final repository = ref.watch(reviewsRepositoryProvider);
  return repository.getReviews(restaurant.id);
});
