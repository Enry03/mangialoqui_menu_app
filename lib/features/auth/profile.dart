class Profile {
  final String id;
  final String restaurantId;
  final String role;
  final String? fullName;

  Profile({
    required this.id,
    required this.restaurantId,
    required this.role,
    this.fullName,
  });

  bool get isOwner => role == 'owner';

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      role: map['role'] as String,
      fullName: map['full_name'] as String?,
    );
  }
}