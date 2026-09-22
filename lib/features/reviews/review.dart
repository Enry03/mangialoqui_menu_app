class MenuReview {
  final String id;
  final String restaurantId;
  final int rating;
  final String? comment;
  final String? customerName;
  final bool sentToGoogle;
  final DateTime createdAt;

  const MenuReview({
    required this.id,
    required this.restaurantId,
    required this.rating,
    required this.comment,
    required this.customerName,
    required this.sentToGoogle,
    required this.createdAt,
  });

  factory MenuReview.fromMap(Map<String, dynamic> map) {
    return MenuReview(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      rating: (map['rating'] as num).toInt(),
      comment: (map['comment'] as String?)?.trim().isEmpty ?? true
          ? null
          : map['comment'] as String?,
      customerName: (map['customer_name'] as String?)?.trim().isEmpty ?? true
          ? null
          : map['customer_name'] as String?,
      sentToGoogle: map['sent_to_google'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
