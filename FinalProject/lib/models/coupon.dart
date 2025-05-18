class Coupon {
  final String id;
  final String description;
  final double discountMoney;
  final int quantity;
  final String couponCode;
  final bool validity;
  final DateTime createdAt;

  Coupon({
    required this.id,
    required this.description,
    required this.discountMoney,
    required this.quantity,
    required this.validity,
    required this.couponCode,
    required this.createdAt,
  });

  factory Coupon.fromMap(String id, Map<String, dynamic> data) {
    return Coupon(
      id: id,
      couponCode: data['couponCode'] ?? 'no code',
      description: data['description'] ?? '',
      discountMoney: (data['discountMoney'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 0,
      validity: data['validity'] ?? false,
      createdAt: (data['createdAt']).toDate(),
    );
  }
}
