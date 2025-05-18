import 'dart:convert';
import 'product_detail_model.dart';

String? buildFullImageUrlHelper(String? relativePath) {
  if (relativePath == null || relativePath.isEmpty) return null;
  const String baseUrl = "https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/";
  if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
    return relativePath;
  }
  // Adjust the path replacement based on actual server structure for product_thumbnail vs assets/img
  if (relativePath.startsWith('img/product_thumnail/')) {
    return baseUrl + relativePath.replaceFirst('img/', 'static/img/');
  } else if (relativePath.startsWith('assets/img/')) {
    return baseUrl + relativePath.replaceFirst('assets/img/', 'static/assets/img/');
  }
  return baseUrl + relativePath; // Fallback, might need adjustment
}

class ProductListItem {
  final String? thumbnailUrl;
  final int productId;
  final String name;
  final String code;
  final String basePrice;
  final ProductCategorySummary category;
  final ProductBrandSummary brand;
  final ProductDiscount? discount;

  ProductListItem({
    required this.productId,
    required this.name,
    required this.code,
    required this.basePrice,
    this.thumbnailUrl,
    required this.category,
    required this.brand,
    this.discount,
  });

  factory ProductListItem.fromJson(Map<String, dynamic> json) {
    return ProductListItem(
      thumbnailUrl: json['thumbnail_url'],
      productId: json['product_id'],
      name: json['name'],
      code: json['code'],
      basePrice: json['base_price'],
      category: ProductCategorySummary.fromJson(json['category']),
      brand: ProductBrandSummary.fromJson(json['brand']),
      discount: json['discount'] != null
          ? ProductDiscount.fromJson(json['discount'])
          : null,
    );
  }
}

class ProductCategorySummary {
  final String name;
  final String? imageUrl;
  final String description;
  final int categoryId;
  // final DateTime createdAt; // Not always needed for list display

  ProductCategorySummary({
    required this.name,
    this.imageUrl,
    required this.description,
    required this.categoryId,
  });

  factory ProductCategorySummary.fromJson(Map<String, dynamic> json) {
    return ProductCategorySummary(
      name: json['name'],
      imageUrl: buildFullImageUrlHelper(json['image_url']),
      description: json['description'],
      categoryId: json['category_id'],
    );
  }
}

class ProductBrandSummary {
  final String name;
  final String? logoUrl;
  final int brandId;
  // final DateTime createdAt; // Not always needed for list display

  ProductBrandSummary({
    required this.name,
    this.logoUrl,
    required this.brandId,
  });

  factory ProductBrandSummary.fromJson(Map<String, dynamic> json) {
    return ProductBrandSummary(
      name: json['name'],
      logoUrl: buildFullImageUrlHelper(json['logo_url']),
      brandId: json['brand_id'],
    );
  }
}