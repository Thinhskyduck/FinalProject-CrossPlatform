import 'dart:convert';

import 'package:intl/intl.dart';

// --- Main Response Model ---
class OrderPreviewResponse {
  final String recipientName;
  final String recipientPhone;
  final String shippingAddress;
  final String? notes;
  final String? paymentMethod; // Có thể null hoặc là giá trị mặc định
  final List<PreviewItem> items;
  final double subtotal;
  final double shippingFee;
  final double couponDiscountAmount;
  final int loyaltyPointsUsed;
  final double loyaltyDiscountAmount;
  final double totalAmount;
  final AppliedCoupon? appliedCoupon;
  final int loyaltyPointsEarned;
  final int currentLoyaltyPoints;

  OrderPreviewResponse({
    required this.recipientName,
    required this.recipientPhone,
    required this.shippingAddress,
    this.notes,
    this.paymentMethod,
    required this.items,
    required this.subtotal,
    required this.shippingFee,
    required this.couponDiscountAmount,
    required this.loyaltyPointsUsed,
    required this.loyaltyDiscountAmount,
    required this.totalAmount,
    this.appliedCoupon,
    required this.loyaltyPointsEarned,
    required this.currentLoyaltyPoints,
  });

  factory OrderPreviewResponse.fromJson(Map<String, dynamic> json) {
    // Hàm tiện ích để parse double từ String, trả về 0.0 nếu lỗi
    double parseDouble(String? value) {
      return double.tryParse(value ?? '0') ?? 0.0;
    }

    return OrderPreviewResponse(
      recipientName: json['recipient_name'] as String? ?? '',
      recipientPhone: json['recipient_phone'] as String? ?? '',
      shippingAddress: json['shipping_address'] as String? ?? '',
      notes: json['notes'] as String?,
      paymentMethod: json['payment_method'] as String?,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((itemJson) => PreviewItem.fromJson(itemJson as Map<String, dynamic>))
          .toList(),
      subtotal: parseDouble(json['subtotal'] as String?),
      shippingFee: parseDouble(json['shipping_fee'] as String?),
      couponDiscountAmount: parseDouble(json['coupon_discount_amount'] as String?),
      loyaltyPointsUsed: json['loyalty_points_used'] as int? ?? 0,
      loyaltyDiscountAmount: parseDouble(json['loyalty_discount_amount'] as String?),
      totalAmount: parseDouble(json['total_amount'] as String?),
      appliedCoupon: json['applied_coupon'] == null
          ? null
          : AppliedCoupon.fromJson(json['applied_coupon'] as Map<String, dynamic>),
      loyaltyPointsEarned: json['loyalty_points_earned'] as int? ?? 0,
      currentLoyaltyPoints: json['current_loyalty_points'] as int? ?? 0,
    );
  }
}

// --- Nested Item Model ---
class PreviewItem {
  final int variantId;
  final int quantity;
  final double priceAtPurchase;
  final double totalPrice;
  final PreviewVariant variant;

  PreviewItem({
    required this.variantId,
    required this.quantity,
    required this.priceAtPurchase,
    required this.totalPrice,
    required this.variant,
  });

  factory PreviewItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(String? value) {
      return double.tryParse(value ?? '0') ?? 0.0;
    }
    return PreviewItem(
      variantId: json['variant_id'] as int? ?? 0,
      quantity: json['quantity'] as int? ?? 0,
      priceAtPurchase: parseDouble(json['price_at_purchase'] as String?),
      totalPrice: parseDouble(json['total_price'] as String?),
      variant: PreviewVariant.fromJson(json['variant'] as Map<String, dynamic>? ?? {}),
    );
  }
}

// --- Nested Variant Model ---
class PreviewVariant {
  final String variantName;
  final String? imageUrl;
  final double additionalPrice;
  final int stockQuantity;
  final double costPrice;
  final int variantId;
  final int productId;
  final String? variantCode;

  PreviewVariant({
    required this.variantName,
    this.imageUrl,
    required this.additionalPrice,
    required this.stockQuantity,
    required this.costPrice,
    required this.variantId,
    required this.productId,
    this.variantCode,
  });

  factory PreviewVariant.fromJson(Map<String, dynamic> json) {
    double parseDouble(String? value) {
      return double.tryParse(value ?? '0') ?? 0.0;
    }
    return PreviewVariant(
      variantName: json['variant_name'] as String? ?? 'N/A',
      imageUrl: json['image_url'] as String?,
      additionalPrice: parseDouble(json['additional_price'] as String?),
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      costPrice: parseDouble(json['cost_price'] as String?),
      variantId: json['variant_id'] as int? ?? 0,
      productId: json['product_id'] as int? ?? 0,
      variantCode: json['variant_code'] as String?,
    );
  }
}

// --- Nested Applied Coupon Model (Ví dụ, có thể null) ---
class AppliedCoupon {
  // Thêm các trường của coupon nếu API trả về chi tiết
  // final String code;
  // final String description;
  // ...

  AppliedCoupon(/* Khai báo các trường */);

  factory AppliedCoupon.fromJson(Map<String, dynamic> json) {
    // Logic parse coupon
    return AppliedCoupon(/* ... */);
  }
}

// --- Lớp tiện ích để định dạng tiền tệ (nếu chưa có) ---
String formatCurrency(double? amount) {
  if (amount == null) return "N/A";
  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
  return formatter.format(amount);
}
// Đừng quên import: import 'package:intl/intl.dart';