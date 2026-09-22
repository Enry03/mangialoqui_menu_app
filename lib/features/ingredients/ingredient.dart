class RestaurantIngredient {
  final String id;
  final String restaurantId;
  final String name;
  final int sortOrder;

  const RestaurantIngredient({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.sortOrder,
  });

  factory RestaurantIngredient.fromMap(Map<String, dynamic> map) {
    return RestaurantIngredient(
      id: (map['id'] ?? '').toString(),
      restaurantId: (map['restaurant_id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
