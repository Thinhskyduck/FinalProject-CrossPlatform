// models/review_model.dart
import 'dart:convert';

class Review {
  final int rating;
  final String comment;
  final int reviewId;
  final int productId;
  final int userId;
  final DateTime createdAt;
  final bool? isApproved; // Can be null from POST response
  final ReviewUser user;

  Review({
    required this.rating,
    required this.comment,
    required this.reviewId,
    required this.productId,
    required this.userId,
    required this.createdAt,
    this.isApproved,
    required this.user,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      rating: json['rating'],
      comment: json['comment'],
      reviewId: json['review_id'],
      productId: json['product_id'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      isApproved: json['is_approved'],
      user: ReviewUser.fromJson(json['user']),
    );
  }
}

class ReviewUser {
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? shippingAddress;
  final int userId;
  final String? firebaseUid;
  final String? role;
  final int? loyaltyPoints;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt; // Can be null
  final String? totalSpent;

  ReviewUser({
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.shippingAddress,
    required this.userId,
    this.firebaseUid,
    this.role,
    this.loyaltyPoints,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.totalSpent,
  });

  factory ReviewUser.fromJson(Map<String, dynamic> json) {
    return ReviewUser(
      email: json['email'],
      fullName: json['full_name'] ?? "Anonymous", // Handle potential null
      phoneNumber: json['phone_number'],
      shippingAddress: json['shipping_address'],
      userId: json['user_id'],
      firebaseUid: json['firebase_uid'],
      role: json['role'],
      loyaltyPoints: json['loyalty_points'],
      isActive: json['is_active'] ?? true, // Default to true if null
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      totalSpent: json['total_spent'],
    );
  }
}