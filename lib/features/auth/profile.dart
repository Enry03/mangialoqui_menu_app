class Profile {
  final String id;
  final String restaurantId;
  final String? fullName;

  Profile({required this.id, required this.restaurantId, this.fullName});

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      fullName: map['full_name'] as String?,
    );
  }
}
