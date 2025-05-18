// lib/models/user_model.dart
import 'package:intl/intl.dart';

class UserModel {
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? shippingAddress;
  final int userId;
  final String firebaseUid;
  final String role;
  final int loyaltyPoints;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double totalSpent;

  UserModel({
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.shippingAddress,
    required this.userId,
    required this.firebaseUid,
    required this.role,
    required this.loyaltyPoints,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    required this.totalSpent,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String?,
      shippingAddress: json['shipping_address'] as String?,
      userId: json['user_id'] as int,
      firebaseUid: json['firebase_uid'] as String,
      role: json['role'] as String,
      loyaltyPoints: json['loyalty_points'] as int,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      totalSpent: double.tryParse(json['total_spent']?.toString() ?? '0.0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'full_name': fullName,
      'phone_number': phoneNumber,
      'shipping_address': shippingAddress,
    };
  }

  // Helper getters for display
  String get formattedTotalSpent {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return formatCurrency.format(totalSpent);
  }

  String get formattedCreatedAt {
    return DateFormat('dd/MM/yyyy').format(createdAt);
  }
}