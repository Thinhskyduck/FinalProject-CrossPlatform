
class ProductDetail {
  final String? thumbnailUrl; // Sẽ chứa ví dụ: "product_thumnail/4.jpg"
  final List<ProductImage> images;
  final String name;
  final String description;
  final String basePrice;
  final int categoryId;
  final int brandId;
  final String code;
  final int productId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProductCategory category;
  final ProductBrand brand;
  final String? thumbnailUrlFromApi;
  final List<ProductImageFromApi> imagesFromApi;
  final List<ProductVariant> variants;
  final ProductDiscount? discount; // Có thể null

  ProductDetail({
    this.thumbnailUrlFromApi,
    required this.imagesFromApi,
    required this.name,
    required this.description,
    required this.basePrice,
    this.thumbnailUrl,
    required this.categoryId,
    required this.brandId,
    required this.code,
    required this.productId,
    required this.createdAt,
    required this.updatedAt,
    required this.category,
    required this.brand,
    required this.variants,
    required this.images,
    this.discount,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    // Helper function to build full image URL
    print("DEBUG - ProductDetail.fromJson - Raw json['thumbnail_url']: ${json['thumbnail_url']}");
    String? buildFullImageUrl(String? relativePath) {
      if (relativePath == null || relativePath.isEmpty) return null;
      const String baseUrl = "https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/";
      if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
        return relativePath;
      }
      return baseUrl + relativePath.replaceFirst('img/', 'static/img/');
    }

    return ProductDetail(
      thumbnailUrl: json['thumbnail_url'],
      images: (json['images'] as List)
          .map((i) {
        // i ở đây là Map<String, dynamic> cho một ProductImage
        print("DEBUG - ProductDetail.fromJson - Raw image item from json['images']: $i"); // << THÊM
        return ProductImage.fromJson(i);
      })
          .toList(),
      name: json['name'],
      description: json['description'],
      basePrice: json['base_price'],
      categoryId: json['category_id'],
      brandId: json['brand_id'],
      code: json['code'],
      productId: json['product_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      category: ProductCategory.fromJson(json['category']),
      brand: ProductBrand.fromJson(json['brand']),
      variants: (json['variants'] as List)
          .map((v) => ProductVariant.fromJson(v, buildFullImageUrl))
          .toList(),
      thumbnailUrlFromApi: json['thumbnail_url'],
      imagesFromApi: (json['images'] as List)
          .map((i) => ProductImageFromApi.fromJson(i))
          .toList(),
      discount: json['discount'] != null
          ? ProductDiscount.fromJson(json['discount'])
          : null,
    );
  }

  List<String> getAllImageUrls() {
    final urls = <String>{}; // Use a Set to avoid duplicates
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      urls.add(thumbnailUrl!);
    }
    for (var img in images) {
      if (img.imageUrl != null && img.imageUrl!.isNotEmpty) {
        urls.add(img.imageUrl!);
      }
    }
    return urls.toList();
  }

}

class ProductCategory {
  final String name;
  final String? imageUrl;
  final String description;
  final int categoryId;
  final DateTime createdAt;

  ProductCategory({
    required this.name,
    this.imageUrl,
    required this.description,
    required this.categoryId,
    required this.createdAt,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    String? buildFullImageUrl(String? relativePath) {
      if (relativePath == null || relativePath.isEmpty) return null;
      const String baseUrl = "https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/";
      if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
        return relativePath;
      }
      return baseUrl + relativePath.replaceFirst('assets/img/', 'static/assets/img/');
    }
    return ProductCategory(
      name: json['name'],
      imageUrl: buildFullImageUrl(json['image_url']),
      description: json['description'],
      categoryId: json['category_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ProductBrand {
  final String name;
  final String? logoUrl;
  final int brandId;
  final DateTime createdAt;

  ProductBrand({
    required this.name,
    this.logoUrl,
    required this.brandId,
    required this.createdAt,
  });

  factory ProductBrand.fromJson(Map<String, dynamic> json) {
    String? buildFullImageUrl(String? relativePath) {
      if (relativePath == null || relativePath.isEmpty) return null;
      const String baseUrl = "https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/";
      if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
        return relativePath;
      }
      return baseUrl + relativePath.replaceFirst('assets/img/', 'static/assets/img/');
    }
    return ProductBrand(
      name: json['name'],
      logoUrl: buildFullImageUrl(json['logo_url']),
      brandId: json['brand_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ProductVariant {
  final String variantName;
  final String? imageUrl;
  final String additionalPrice;
  final int stockQuantity;
  final int variantId;
  final int productId;
  final String variantCode;

  ProductVariant({
    required this.variantName,
    this.imageUrl,
    required this.additionalPrice,
    required this.stockQuantity,
    required this.variantId,
    required this.productId,
    required this.variantCode,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json, String? Function(String?) buildFullImageUrl) {
    return ProductVariant(
      variantName: json['variant_name'],
      imageUrl: buildFullImageUrl(json['image_url']),
      additionalPrice: json['additional_price'],
      stockQuantity: json['stock_quantity'],
      variantId: json['variant_id'],
      productId: json['product_id'],
      variantCode: json['variant_code'],
    );
  }
}

class ProductImage {
  final String? imageUrl;
  final int imageId;
  final int productId;
  final DateTime createdAt;

  ProductImage({
    this.imageUrl,
    required this.imageId,
    required this.productId,
    required this.createdAt,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    print("DEBUG - ProductImage.fromJson - Raw json['image_url']: ${json['image_url']}"); // << THÊM
    return ProductImage(
      imageUrl: json['image_url'], // Lưu trực tiếp giá trị từ API
      imageId: json['image_id'],
      productId: json['product_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ProductDiscount {
  final String discountPercent;
  final bool isActive;
  final DateTime startDate;
  final DateTime endDate;
  final int discountId;
  final int productId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductDiscount({
    required this.discountPercent,
    required this.isActive,
    required this.startDate,
    required this.endDate,
    required this.discountId,
    required this.productId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductDiscount.fromJson(Map<String, dynamic> json) {
    return ProductDiscount(
      discountPercent: json['discount_percent'],
      isActive: json['is_active'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      discountId: json['discount_id'],
      productId: json['product_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class ProductImageFromApi {
  final String? imageUrlFromApi;
  final int imageId;
  ProductImageFromApi({this.imageUrlFromApi, required this.imageId});

  factory ProductImageFromApi.fromJson(Map<String, dynamic> json) {
    return ProductImageFromApi(
      imageUrlFromApi: json['image_url'],
      imageId: json['image_id'],
    );
  }

}


