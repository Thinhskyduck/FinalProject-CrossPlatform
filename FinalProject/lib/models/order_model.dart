// lib/models/order_model.dart
import 'package:intl/intl.dart';

import '../services/constants.dart'; // THAY ĐỔI CHO ĐÚNG ĐƯỜNG DẪN PROJECT CỦA BẠN

class OrderModel {
  final String recipientName;
  final String recipientPhone;
  final String shippingAddress;
  final String? notes;
  final String paymentMethod;
  final int orderId;
  final String orderCode;
  final int userId;
  final double subtotal;
  final double shippingFee;
  final double couponDiscountAmount;
  final int loyaltyPointsUsed;
  final double totalAmount;
  final int loyaltyPointsEarned;
  final int? couponId;
  final String status; // e.g., "Completed", "Pending"
  final DateTime orderedAt;
  final DateTime updatedAt;
  final List<OrderItemModel> items;
  final List<OrderStatusHistoryModel> statusHistory;
  final InvoiceModel? invoice;
  // final UserModel? userDetail; // Thông tin user trong đơn hàng, có thể dùng nếu cần
  // final CouponModel? couponDetail;
  // final ShipperModel? shipperDetail;

  OrderModel({
    required this.recipientName,
    required this.recipientPhone,
    required this.shippingAddress,
    this.notes,
    required this.paymentMethod,
    required this.orderId,
    required this.orderCode,
    required this.userId,
    required this.subtotal,
    required this.shippingFee,
    required this.couponDiscountAmount,
    required this.loyaltyPointsUsed,
    required this.totalAmount,
    required this.loyaltyPointsEarned,
    this.couponId,
    required this.status,
    required this.orderedAt,
    required this.updatedAt,
    required this.items,
    required this.statusHistory,
    this.invoice,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      recipientName: json['recipient_name'] as String,
      recipientPhone: json['recipient_phone'] as String,
      shippingAddress: json['shipping_address'] as String,
      notes: json['notes'] as String?,
      paymentMethod: json['payment_method'] as String,
      orderId: json['order_id'] as int,
      orderCode: json['order_code'] as String,
      userId: json['user_id'] as int,
      subtotal: double.parse(json['subtotal'].toString()),
      shippingFee: double.parse(json['shipping_fee'].toString()),
      couponDiscountAmount: double.parse(json['coupon_discount_amount'].toString()),
      loyaltyPointsUsed: json['loyalty_points_used'] as int,
      totalAmount: double.parse(json['total_amount'].toString()),
      loyaltyPointsEarned: json['loyalty_points_earned'] as int,
      couponId: json['coupon_id'] as int?,
      status: json['status'] as String,
      orderedAt: DateTime.parse(json['ordered_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items: (json['items'] as List<dynamic>)
          .map((itemJson) => OrderItemModel.fromJson(itemJson as Map<String, dynamic>))
          .toList(),
      statusHistory: (json['status_history'] as List<dynamic>)
          .map((historyJson) => OrderStatusHistoryModel.fromJson(historyJson as Map<String, dynamic>))
          .toList(),
      invoice: json['invoice'] != null ? InvoiceModel.fromJson(json['invoice'] as Map<String, dynamic>) : null,
    );
  }

  // Helpers for display
  String get formattedTotalAmount {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return formatCurrency.format(totalAmount);
  }

  String get formattedOrderedAt {
    return DateFormat('dd/MM/yyyy HH:mm').format(orderedAt);
  }

  String get firstProductName {
    return items.isNotEmpty ? items.first.variant.variantName : 'Sản phẩm không xác định';
  }

  String get firstProductImage {
    return items.isNotEmpty ? AppConstants.getFullImageUrl(items.first.variant.imageUrl) : AppConstants.getFullImageUrl(null);
  }

  String get extraItemsText {
    if (items.length > 1) {
      return "và ${items.length - 1} sản phẩm khác";
    }
    return '';
  }
}

class OrderItemModel {
  final int variantId;
  final int quantity;
  final int orderItemId;
  final double priceAtPurchase;
  final ProductVariantModel variant;

  OrderItemModel({
    required this.variantId,
    required this.quantity,
    required this.orderItemId,
    required this.priceAtPurchase,
    required this.variant,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      variantId: json['variant_id'] as int,
      quantity: json['quantity'] as int,
      orderItemId: json['order_item_id'] as int,
      priceAtPurchase: double.parse(json['price_at_purchase'].toString()),
      variant: ProductVariantModel.fromJson(json['variant'] as Map<String, dynamic>),
    );
  }
}

class ProductVariantModel {
  final String variantName;
  final String? imageUrl; // API trả về "img/product_thumnail/53.jpg"
  final int variantId;
  final int productId;

  ProductVariantModel({
    required this.variantName,
    this.imageUrl,
    required this.variantId,
    required this.productId,
  });

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    return ProductVariantModel(
      variantName: json['variant_name'] as String,
      imageUrl: json['image_url'] as String?,
      variantId: json['variant_id'] as int,
      productId: json['product_id'] as int,
    );
  }
}

class OrderStatusHistoryModel {
  final String status;
  final DateTime changedAt;

  OrderStatusHistoryModel({required this.status, required this.changedAt});

  factory OrderStatusHistoryModel.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistoryModel(
      status: json['status'] as String,
      changedAt: DateTime.parse(json['changed_at'] as String),
    );
  }
}

class InvoiceModel {
  final String invoiceNumber;
  final DateTime issuedAt;

  InvoiceModel({required this.invoiceNumber, required this.issuedAt});

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      invoiceNumber: json['invoice_number'] as String,
      issuedAt: DateTime.parse(json['issued_at'] as String),
    );
  }
}