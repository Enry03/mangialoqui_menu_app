class MenuCategory {
  final String id;
  final String restaurantId;
  final String name;
  final int sortOrder;

  MenuCategory({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.sortOrder,
  });

  factory MenuCategory.fromMap(Map<String, dynamic> map) {
    return MenuCategory(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      name: map['name'] as String,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
