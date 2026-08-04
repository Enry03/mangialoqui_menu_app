import '../auth/profile.dart';
import 'restaurant.dart';

class RestaurantMembership {
  final Profile profile;
  final Restaurant restaurant;

  const RestaurantMembership({
    required this.profile,
    required this.restaurant,
  });

  String get restaurantId => restaurant.id;
  String get role => profile.role;
  bool get isOwner => profile.isOwner;
}
