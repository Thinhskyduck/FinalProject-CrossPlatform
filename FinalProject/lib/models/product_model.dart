import 'dart:convert';

import 'package:intl/intl.dart';

// Hàm tiện ích để parse danh sách sản phẩm từ JSON
List<Product> productFromJson(String str) =>
    List<Product>.from(json.decode(str).map((x) => Product.fromJson(x)));

String productToJson(List<Product> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class Product {
  final bool isOnSale;
  final String salePriceText; // Ví dụ: "Còn 25.990.000đ"
  final String originalPriceText;
  final int productId;
  final String name;
  final String code;
  final double basePrice;
  final String? description;
  final String? thumbnailUrl;
  final Category? category; // *** THAY ĐỔI: Cho phép Category là null ***
  final Brand? brand;     // *** THAY ĐỔI: Cho phép Brand là null ***
  final Discount? discount;

  final String discountBadgeText;
  final String installmentBadgeText;
  final List<String> additionalInfoTags;
  final double starRating;
  bool isLiked;

  Product({
    required this.productId,
    required this.name,
    required this.code,
    required this.basePrice,
    this.description,
    this.thumbnailUrl,
    this.category, // *** THAY ĐỔI ***
    this.brand,    // *** THAY ĐỔI ***
    this.discount,
    this.discountBadgeText = '',
    this.installmentBadgeText = '',
    this.additionalInfoTags = const [],
    this.starRating = 0.0,
    this.isLiked = false,
    this.isOnSale = false, // Thêm tham số
    this.salePriceText = '',
    this.originalPriceText = '',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    double parsedPrice = 0.0;
    if (json["base_price"] != null) {
      parsedPrice = double.tryParse(json["base_price"].toString()) ?? 0.0;
    }

    String discountText = '';

    Discount? parsedDiscount;
    if (json["discount"] != null && json["discount"] is Map<String, dynamic>) {
      parsedDiscount = Discount.fromJson(json["discount"]);
    }

    bool productIsOnSale = false;
    String currentSalePriceText = '';
    String currentOriginalPriceText = NumberFormat("#,##0₫", "vi_VN").format(parsedPrice); // Giá gốc ban đầu
    String currentDiscountBadgeText = '';


    if (parsedDiscount != null && parsedDiscount.isCurrentlyActive && parsedDiscount.discountPercent > 0) {
      productIsOnSale = true;
      double discountedPrice = parsedPrice * (1 - (parsedDiscount.discountPercent / 100));
      currentSalePriceText = NumberFormat("#,##0₫", "vi_VN").format(discountedPrice);
      // originalPriceText đã là giá gốc rồi.
      currentDiscountBadgeText = "Giảm ${parsedDiscount.discountPercent.toStringAsFixed(0)}%";
    } else {
      // Nếu không có discount hoặc discount không active, salePriceText sẽ giống originalPriceText (hoặc trống)
      currentSalePriceText = currentOriginalPriceText; // Hoặc để trống tùy thiết kế
    }
    // ... (logic tạo discountText giữ nguyên) ...

    // *** THAY ĐỔI QUAN TRỌNG: Kiểm tra null cho category và brand ***
    Category? parsedCategory;
    if (json["category"] != null && json["category"] is Map<String, dynamic>) { // Kiểm tra kiểu nữa cho chắc
      parsedCategory = Category.fromJson(json["category"]);
    } else {
      // Cung cấp một Category mặc định nếu API không trả về hoặc trả về null
      // Điều này quan trọng để tránh lỗi khi truy cập product.category.name sau này
      // Bạn có thể tạo một Category "Chưa phân loại"
      parsedCategory = Category(categoryId: 0, name: "Chưa phân loại");
      print("Warning: Product ID ${json["product_id"]} has null or invalid category. Using default.");
    }

    Brand? parsedBrand;
    if (json["brand"] != null && json["brand"] is Map<String, dynamic>) {
      parsedBrand = Brand.fromJson(json["brand"]);
    } else {
      // Cung cấp một Brand mặc định
      parsedBrand = Brand(brandId: 0, name: "Không rõ");
      print("Warning: Product ID ${json["product_id"]} has null or invalid brand. Using default.");
    }

    return Product(
      productId: json["product_id"] ?? 0,
      name: json["name"] ?? "Sản phẩm không tên",
      code: json["code"] ?? "",
      basePrice: parsedPrice, // Đây là giá gốc trước giảm
      thumbnailUrl: json["thumbnail_url"] == "string" ? null : json["thumbnail_url"],
      category: parsedCategory,
      brand: parsedBrand,
      discount: parsedDiscount,
      description: json["description"] as String?,

      // Dữ liệu được tính toán
      isOnSale: productIsOnSale,
      salePriceText: currentSalePriceText, // Giá hiển thị chính
      originalPriceText: productIsOnSale ? currentOriginalPriceText : '', // Giá gốc gạch ngang chỉ khi có sale
      discountBadgeText: currentDiscountBadgeText, // Cập nhật từ discount

      // Các trường giả lập khác
      installmentBadgeText: parsedPrice > 10000000 ? 'Trả góp 0%' : '',
      additionalInfoTags: ['Hàng chính hãng'],
      starRating: ((json["product_id"] ?? 0) % 5) + 3.5,
      isLiked: false,
    );
  }

  Map<String, dynamic> toJson() => {
    "product_id": productId,
    "name": name,
    "code": code,
    "base_price": basePrice.toStringAsFixed(2),
    "thumbnail_url": thumbnailUrl,
    "category": category?.toJson(), // *** THAY ĐỔI: Sử dụng toán tử ?. (null-aware) ***
    "brand": brand?.toJson(),
    "description": description,// *** THAY ĐỔI: Sử dụng toán tử ?. (null-aware) ***
    "discount": discount?.toJson(),
  };
}

class Category {
  final int categoryId;
  final String name;
  final String? imageUrl;
  final String? description;
  final DateTime? createdAt;

  Category({
    required this.categoryId,
    required this.name,
    this.imageUrl,
    this.description,
    this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    categoryId: json["category_id"],
    name: json["name"] ?? "Chưa phân loại",
    imageUrl: json["image_url"],
    description: json["description"],
    createdAt: json["created_at"] == null ? null : DateTime.tryParse(json["created_at"]),
  );

  Map<String, dynamic> toJson() => {
    "category_id": categoryId,
    "name": name,
    "image_url": imageUrl,
    "description": description,
    "created_at": createdAt?.toIso8601String(),
  };
}

class Brand {
  final int brandId;
  final String name;
  final String? logoUrl;
  final DateTime? createdAt;

  Brand({
    required this.brandId,
    required this.name,
    this.logoUrl,
    this.createdAt,
  });

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
    brandId: json["brand_id"],
    name: json["name"] ?? "Không rõ thương hiệu",
    logoUrl: json["logo_url"],
    createdAt: json["created_at"] == null ? null : DateTime.tryParse(json["created_at"]),
  );

  Map<String, dynamic> toJson() => {
    "brand_id": brandId,
    "name": name,
    "logo_url": logoUrl,
    "created_at": createdAt?.toIso8601String(),
  };
}

class Discount {
  final int discountId;
  final int productId;
  final double discountPercent; // Chuyển thành double
  final bool isActive;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Discount({
    required this.discountId,
    required this.productId,
    required this.discountPercent,
    required this.isActive,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      discountId: json["discount_id"] ?? 0,
      productId: json["product_id"] ?? 0,
      discountPercent: double.tryParse(json["discount_percent"].toString()) ?? 0.0,
      isActive: json["is_active"] ?? false,
      startDate: DateTime.tryParse(json["start_date"] ?? "") ?? DateTime.now(),
      endDate: DateTime.tryParse(json["end_date"] ?? "") ?? DateTime.now().add(const Duration(days: 1)), // Thêm ngày nếu parse lỗi
      createdAt: DateTime.tryParse(json["created_at"] ?? "") ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json["updated_at"] ?? "") ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    "discount_id": discountId,
    "product_id": productId,
    "discount_percent": discountPercent.toStringAsFixed(2),
    "is_active": isActive,
    "start_date": startDate.toIso8601String(),
    "end_date": endDate.toIso8601String(),
    "created_at": createdAt.toIso8601String(),
    "updated_at": updatedAt.toIso8601String(),
  };

  // Helper để kiểm tra xem discount có còn hiệu lực không
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }
}

