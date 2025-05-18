import 'dart:convert'; // Quan trọng: import dart:convert để có utf8
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/product_detail_model.dart';
import '../models/product_list_item_model.dart';
import '../models/product_model.dart'; // Giả sử Product model có tồn tại
import '../models/review_model.dart';

class ApiService {
  static const String _baseUrl =
      'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1';
  static const String _baseImageUrl =
      'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com';
  static String getFullImageUrl(String? relativePath) {
    if (relativePath == null ||
        relativePath.isEmpty ||
        relativePath == "string") {
      return 'https://via.placeholder.com/200x200/F0F0F0/B0B0B0?text=No+Image';
    }
    if (relativePath.startsWith('http')) {
      return relativePath; // Đã là URL tuyệt đối
    }
    return _baseImageUrl +
        (relativePath.startsWith('/') ? relativePath : '/$relativePath');
  }

  dynamic _handleHttpResponse(http.Response response,
      {String? errorMessagePrefix}) {
    final prefix = errorMessagePrefix ?? 'API Request Failed';
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        // Giải mã UTF-8 trước khi parse JSON
        final decodedBody = utf8.decode(response.bodyBytes);
        if (decodedBody.isNotEmpty) {
          return jsonDecode(decodedBody);
        } else {
          return null; // Body rỗng nhưng thành công (e.g., 204 No Content)
        }
      } catch (e) {
        print('$prefix: Error decoding JSON: $e');
        print("Raw Response Body: ${response.body}"); // Log raw body để debug
        throw Exception('Failed to decode JSON response.');
      }
    } else {
      print('$prefix: Status ${response.statusCode}, Body: ${response.body}');
      // Cung cấp thông tin lỗi cụ thể hơn nếu có thể
      String errorDetail = 'Status code: ${response.statusCode}';
      try {
        final decodedBody = utf8.decode(response.bodyBytes);
        if (decodedBody.isNotEmpty) {
          final errorJson = jsonDecode(decodedBody);
          if (errorJson is Map && errorJson.containsKey('detail')) {
            errorDetail += '. Detail: ${errorJson['detail']}';
          } else {
            errorDetail += '. Body: $decodedBody';
          }
        }
      } catch (_) {
        // Nếu không decode được body lỗi thì dùng body raw
        errorDetail += '. Body: ${response.body}';
      }
      throw Exception('$prefix. $errorDetail');
    }
  }

  // Trong class ApiService
  Future<List<Product>> fetchBestSellerProducts({int limit = 10}) async {
    print(
        "Attempting to fetch best seller products (currently using random products as placeholder)");
    // Lấy ngẫu nhiên hoặc một bộ sản phẩm cố định để test UI
    // Ví dụ: Lấy sản phẩm từ trang thứ 2 hoặc 3
    try {
      return await fetchProducts(
          skip: 20,
          limit: limit,
          sortBy: 'name_asc'); // Thay đổi sortBy nếu muốn
    } catch (e) {
      print("Fallback for best sellers failed: $e");
      return []; // Trả về rỗng nếu có lỗi
    }
  }

  Future<ProductDetail> getProductDetails(int productId) async {
    final response = await http.get(Uri.parse('$_baseUrl/products/$productId'));
    if (response.statusCode == 200) {
      return ProductDetail.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print(
          'Failed to load product details: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load product details');
    }
  }

  Future<List<Review>> getProductReviews(int productId,
      {int skip = 0, int limit = 20}) async {
    final response = await http.get(Uri.parse(
        '$_baseUrl/reviews/product/$productId?skip=$skip&limit=$limit'));

    if (response.statusCode == 200) {
      // SỬA Ở ĐÂY
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      List<Review> reviews =
          body.map((dynamic item) => Review.fromJson(item)).toList();
      return reviews;
    } else {
      print('Failed to load reviews: ${response.statusCode} ${response.body}');
      if (response.statusCode == 404 &&
          (response.body.trim() == "[]" || response.body.trim().isEmpty)) {
        return []; // Return empty list if product not found or no reviews
      }
      throw Exception('Failed to load reviews');
    }
  }

  Future<Review> postProductReview(
      int productId, int userId, int rating, String comment) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/reviews/product/$productId'),
      headers: <String, String>{
        'Content-Type':
            'application/json; charset=UTF-8', // Đảm bảo request body là UTF-8
        'X-User-ID': userId.toString(),
      },
      body: jsonEncode(<String, dynamic>{
        // jsonEncode mặc định tạo ra chuỗi UTF-8
        'rating': rating,
        'comment': comment,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      // 201 for created
      // SỬA Ở ĐÂY (cho response body)
      return Review.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print('Failed to post review: ${response.statusCode} ${response.body}');
      throw Exception('Failed to post review: ${response.body}');
    }
  }

  Future<List<Product>> fetchProducts({
    int skip = 0,
    int limit = 20,
    int? categoryId,
    int? brandId,
    double? minPrice,
    double? maxPrice,
    String? search,
    String? sortBy,
    bool? isDiscounted,
  }) async {
    final Map<String, String> queryParams = {
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (categoryId != null) queryParams['category_id'] = categoryId.toString();
    if (brandId != null) queryParams['brand_id'] = brandId.toString();
    if (minPrice != null) queryParams['min_price'] = minPrice.toString();
    if (maxPrice != null) queryParams['max_price'] = maxPrice.toString();
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (sortBy != null && sortBy.isNotEmpty) queryParams['sort_by'] = sortBy;
    if (isDiscounted != null)
      queryParams['is_discounted'] = isDiscounted.toString();
    final uri =
        Uri.parse('$_baseUrl/products').replace(queryParameters: queryParams);
    try {
      final response = await http.get(
        uri,
        headers: {'accept': 'application/json'},
      ).timeout(const Duration(seconds: 15)); // Thêm timeout
      if (response.statusCode == 200) {
        List<dynamic> body =
            jsonDecode(utf8.decode(response.bodyBytes)); //Sử dụng utf8.decode
        List<Product> products = body
            .map((dynamic item) =>
                Product.fromJson(item as Map<String, dynamic>))
            .toList();
        return products;
      } else {
        throw Exception(
            'Failed to load products. Status code: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching products: $e');
      throw Exception('Error fetching products: $e');
    }
  }

  Future<Product> fetchProductById(int productId) async {
    final uri = Uri.parse('$_baseUrl/products/$productId');
    try {
      final response = await http.get(
        uri,
        headers: {'accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // API trả về một object sản phẩm đơn lẻ, không phải list
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        return Product.fromJson(body as Map<String, dynamic>);
      } else {
        throw Exception(
            'Failed to load product details. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching product by ID $productId: $e');
      throw Exception('Error fetching product details: $e');
    }
  }

  Future<List<ProductListItem>> getProducts({
    int skip = 0,
    int limit = 20,
    int? categoryId,
    int? brandId,
    double? minPrice,
    double? maxPrice,
    String? search,
    String? sortBy,
  }) async {
    Map<String, String> queryParams = {
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (categoryId != null) queryParams['category_id'] = categoryId.toString();
    if (brandId != null) queryParams['brand_id'] = brandId.toString();
    if (minPrice != null) queryParams['min_price'] = minPrice.toString();
    if (maxPrice != null) queryParams['max_price'] = maxPrice.toString();
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (sortBy != null && sortBy.isNotEmpty) queryParams['sort_by'] = sortBy;
    final uri =
        Uri.parse('$_baseUrl/products').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      // SỬA Ở ĐÂY
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      List<ProductListItem> products =
          body.map((dynamic item) => ProductListItem.fromJson(item)).toList();
      return products;
    } else {
      print('Failed to load products: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load products');
    }
  }

  Future<bool> addToCart(int variantId, int quantity, int userId) async {
    final url = Uri.parse('$_baseUrl/cart/items');
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'X-User-ID': userId.toString(), // Header chứa ID người dùng
    };
    final body = jsonEncode(<String, dynamic>{
      'variant_id': variantId,
      'quantity': quantity,
    });

    print("--> POST $url");
    print("Headers: $headers");
    print("Body: $body");

    try {
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 15)); // Thêm timeout

      // Kiểm tra mã trạng thái thành công (200 hoặc 201)
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Add to cart successful for variant $variantId (User: $userId)');
        // Bạn có thể muốn decode body nếu API trả về thông tin giỏ hàng mới nhất
        // final jsonResponse = _handleHttpResponse(response);
        // print('Cart update response: $jsonResponse');
        return true; // Thành công
      } else {
        // Nếu mã trạng thái không thành công, log lỗi và trả về false
        print(
            'Failed to add to cart: Status ${response.statusCode}, Body: ${response.body}');
        try {
          _handleHttpResponse(response,
              errorMessagePrefix: 'Failed to add to cart');
        } catch (e) {
          print("Error detail from _handleHttpResponse: $e");
        }
        return false; // Thất bại
      }
    } on SocketException {
      // Lỗi mạng
      print("Network Error adding variant $variantId to cart (User: $userId)");
      // Không throw Exception ở đây để trả về false cho UI xử lý
      // throw Exception('Network Error. Please check connection.');
      return false;
    } catch (e) {
      // Các lỗi khác (timeout, lỗi decode nếu gọi _handleHttpResponse,...)
      print('Error adding variant $variantId to cart (User: $userId): $e');
      return false; // Thất bại
    }
  }

  // HÀM MỚI: Lấy sản phẩm mới nhất
  Future<List<Product>> fetchNewestProducts({int limit = 5}) async {
    try {
      // Giới hạn limit trong khoảng [1, 10] theo API
      final clampedLimit = limit.clamp(1, 10);

      // Tạo URL với query parameter
      final uri = Uri.parse('$_baseUrl/products/newest?limit=$clampedLimit');

      // Gửi yêu cầu GET
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      // Kiểm tra mã trạng thái
      if (response.statusCode == 200) {
        // Parse JSON thành danh sách Product
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((json) => Product.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to fetch newest products: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error fetching newest products: $e');
      throw Exception('Error fetching newest products: $e');
    }
  }

  // HÀM MỚI: Lấy sản phẩm đang giảm giá
  Future<List<Product>> fetchPromotionalProducts({int limit = 5}) async {
    try {
      // Giới hạn limit trong khoảng [1, 10] theo API
      final clampedLimit = limit.clamp(1, 10);

      // Tạo URL với query parameter
      final uri =
          Uri.parse('$_baseUrl/products/promotional?limit=$clampedLimit');

      // Gửi yêu cầu GET
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      // Kiểm tra mã trạng thái
      if (response.statusCode == 200) {
        // Parse JSON thành danh sách Product
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((json) => Product.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to fetch promotional products: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error fetching promotional products: $e');
      throw Exception('Error fetching promotional products: $e');
    }
  }

  // HÀM MỚI: Lấy sản phẩm bán chạy nhất
  Future<List<Product>> fetchBestSellingProducts(
      {int limit = 5, int? daysPeriod}) async {
    // API backend của bạn cần có endpoint riêng cho cái này, ví dụ: /products/best-sellers
    // Hoặc một tham số đặc biệt trong /products, ví dụ: sort_by=best_sellers
    // Hiện tại, tôi sẽ giả sử bạn có endpoint /products/best-sellers
    final Map<String, String> queryParams = {'limit': limit.toString()};
    if (daysPeriod != null) {
      queryParams['days_period'] = daysPeriod.toString();
    }
    final uri = Uri.parse('$_baseUrl/products/best-sellers')
        .replace(queryParameters: queryParams);
    print("Fetching best selling products from: $uri");

    try {
      final response = await http.get(
        uri,
        headers: {'accept': 'application/json'},
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        List<Product> products = body
            .map((dynamic item) =>
                Product.fromJson(item as Map<String, dynamic>))
            .toList();
        return products;
      } else {
        // Có thể trả về list rỗng nếu API lỗi hoặc không có sản phẩm bán chạy
        print(
            'Failed to load best selling products. Status code: ${response.statusCode}, Body: ${response.body}');
        return []; // Trả về rỗng thay vì throw Exception để UI không bị crash hoàn toàn nếu mục này lỗi
        // throw Exception('Failed to load best selling products. Status code: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching best selling products: $e');
      return []; // Trả về rỗng
      // throw Exception('Error fetching best selling products: $e');
    }
  }

  Future<List<ProductListItem>> fetchProductSuggestions(String query,
      {int limit = 5}) async {
    if (query.trim().isEmpty) {
      return [];
    }
    final uri =
        Uri.parse('$_baseUrl/products/suggestions').replace(queryParameters: {
      'search': query.trim(),
      'limit': limit.toString(),
    });

    try {
      final response = await http.get(
        uri,
        headers: {'accept': 'application/json'},
      ).timeout(const Duration(seconds: 7)); // Timeout ngắn hơn cho suggestions

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        // Sử dụng ProductListItem vì nó đã có các trường cơ bản
        List<ProductListItem> products = body
            .map((dynamic item) =>
                ProductListItem.fromJson(item as Map<String, dynamic>))
            .toList();
        return products;
      } else {
        print(
            'Failed to load product suggestions: ${response.statusCode} ${response.body}');
        // Không ném Exception ở đây để UI có thể xử lý mềm mượt hơn
        return [];
      }
    } catch (e) {
      print('Error fetching product suggestions for "$query": $e');
      return [];
    }
  }
}
