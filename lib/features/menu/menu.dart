class MenuModel {
  final String id;
  final String restaurantId;
  final String name;
  final bool isPublished;

  MenuModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.isPublished,
  });

  factory MenuModel.fromMap(Map<String, dynamic> map) {
    return MenuModel(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      name: map['name'] as String? ?? '',
      isPublished: map['is_published'] as bool? ?? false,
    );
  }
}
