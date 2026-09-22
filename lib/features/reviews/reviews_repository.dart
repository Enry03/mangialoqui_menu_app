import 'package:supabase_flutter/supabase_flutter.dart';

import 'review.dart';

class ReviewsRepository {
  final SupabaseClient _client;

  ReviewsRepository(this._client);

  Future<List<MenuReview>> getReviews(String restaurantId) async {
    final response = await _client
        .from('menu_reviews')
        .select()
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => MenuReview.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}
