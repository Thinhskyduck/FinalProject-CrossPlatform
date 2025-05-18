import 'dart:async';

import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiCartItem {
  final int cartItemId;
  final int variantId;
  final int quantity;
  final String variantName;
  final String? imageUrl;
  final String? variantCode;
  final double currentPrice;
  final List<String> tags;

  ApiCartItem({
    required this.cartItemId,
    required this.variantId,
    required this.quantity,
    required this.variantName,
    this.imageUrl,
    this.variantCode,
    required this.currentPrice,
    this.tags = const [],
  });

  factory ApiCartItem.fromJson(Map<String, dynamic> json) {
    final variant = json['variant'] as Map<String, dynamic>? ?? {};
    final additionalPriceStr = variant['additional_price'] as String? ?? '0.00';
    final currentPrice = double.tryParse(additionalPriceStr) ?? 0.0;
    final tagsList = json['tags'] as List<dynamic>? ?? [];

    return ApiCartItem(
      cartItemId: json['cart_item_id'] as int? ?? 0,
      variantId: json['variant_id'] as int? ?? 0,
      quantity: json['quantity'] as int? ?? 1,
      variantName: variant['variant_name'] as String? ?? 'Unknown Product',
      imageUrl: variant['image_url'] as String?,
      variantCode: variant['variant_code'] as String?,
      currentPrice: currentPrice,
      tags: tagsList.map((tag) => tag.toString()).toList(),
    );
  }
}

class CartApiService {
  static const String _baseUrl = 'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1';

  String getFullImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty || relativePath == "string") {
      return 'images/placeholder.png'; // Đường dẫn placeholder trong assets
    }
    if (!relativePath.startsWith('http')) {
      // Thay \ thành / để xử lý đường dẫn không chuẩn
      String normalizedPath = relativePath.replaceAll('\\', '/');
      // Loại bỏ dấu / đầu tiên nếu có
      if (normalizedPath.startsWith('/')) {
        normalizedPath = normalizedPath.substring(1);
      }
      return normalizedPath; // Trả về nguyên gốc: img/product_thumnail/4.jpg
    }
    return relativePath; // Giữ nguyên nếu là URL
  }

  Future<List<ApiCartItem>> getCart({required int userId}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/cart'),
        headers: {
          'accept': 'application/json',
          'X-User-ID': userId.toString(),
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        return items.map((item) => ApiCartItem.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        print('Failed to fetch cart: ${response.statusCode} - ${response.body}');
        String errorDetail = 'Status code: ${response.statusCode}';
        try {
          final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorBody is Map && errorBody.containsKey('detail')) {
            errorDetail += '. Detail: ${errorBody['detail']}';
          } else {
            errorDetail += '. Body: ${response.body}';
          }
        } catch (_) {
          errorDetail += '. Body: ${response.body}';
        }
        throw Exception('Failed to fetch cart: $errorDetail');
      }
    } catch (e) {
      print('Error fetching cart: $e');
      throw Exception('Failed to fetch cart: $e');
    }
  }

  Future<bool> updateCartItemQuantity(int cartItemId, int quantity, {required int userId}) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/cart/items/$cartItemId'),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
          'X-User-ID': userId.toString(),
        },
        body: jsonEncode({
          'quantity': quantity,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 404) {
        print('Cart item not found when updating quantity: ${response.body}');
        // Ném lỗi cụ thể hơn
        throw Exception('Sản phẩm không tồn tại trong giỏ hàng.');
      } else if (response.statusCode == 400) { // <-- BẮT LỖI 400
        print('Bad Request updating cart item: ${response.statusCode} - ${response.body}');
        try {
          // Cố gắng đọc nội dung lỗi 'detail'
          final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorBody is Map && errorBody.containsKey('detail')) {
            final detailMessage = errorBody['detail'] as String;
            // Ném Exception với thông báo từ API
            throw Exception(detailMessage);
          } else {
            throw Exception('Yêu cầu không hợp lệ (400).');
          }
        } catch (e) {
          // Nếu không parse được JSON hoặc không có detail
          print('Could not parse 400 error body: $e');
          throw Exception('Yêu cầu không hợp lệ (400).');
        }
      }
      else { // Các lỗi khác (500, etc.)
        print('Failed to update cart item: ${response.statusCode} - ${response.body}');
        throw Exception('Lỗi máy chủ khi cập nhật giỏ hàng (${response.statusCode}).');
      }
    } on TimeoutException {
      print('Timeout updating cart item quantity for $cartItemId');
      throw Exception('Hết thời gian chờ khi cập nhật số lượng.');
    } catch (e) {
      // Bắt các Exception đã ném ở trên hoặc lỗi mạng khác
      print('Error updating cart item quantity: $e');
      // Ném lại lỗi để lớp UI xử lý, tránh trả về false mơ hồ
      // Nếu không phải là Exception đã có thông báo rõ ràng, thì tạo thông báo chung
      if (e is Exception) {
        throw e; // Ném lại lỗi đã có thông báo
      } else {
        throw Exception('Không thể cập nhật số lượng: $e');
      }
    }
  }

  Future<bool> deleteCartItem(int cartItemId, {required int userId}) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/cart/items/$cartItemId'),
        headers: {
          'accept': 'application/json',
          'X-User-ID': userId.toString(),
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 404) {
        print('Cart item not found: ${response.body}');
        throw Exception('Cart item not found');
      } else {
        print('Failed to delete cart item: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error deleting cart item: $e');
      throw Exception('Failed to delete cart item: $e');
    }
  }

  Future<bool> deleteCart({required int userId}) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/cart'),
        headers: {
          'accept': '*/*',
          'X-User-ID': userId.toString(),
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 204) {
        return true;
      } else {
        print('Failed to delete cart: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error deleting cart: $e');
      throw Exception('Failed to delete cart: $e');
    }
  }

  Future<Map<int, Map<String, dynamic>>> getLatestVariantDetails(List<int> variantIds, {required int userId}) async {
    final uniqueIds = variantIds.where((id) => id > 0).toSet();
    if (uniqueIds.isEmpty) {
      return {};
    }

    // Thay đổi kiểu của map kết quả
    final Map<int, Map<String, dynamic>> variantDetails = {};
    final List<Future<void>> detailFutures = [];

    final headers = {
      'accept': 'application/json',
      'X-User-ID': userId.toString(),
    };

    print('Starting to fetch details for variants: $uniqueIds');

    for (final variantId in uniqueIds) {
      final url = Uri.parse('$_baseUrl/variants/$variantId/price'); // Endpoint vẫn là /price nhưng trả về nhiều hơn
      detailFutures.add(
              () async {
            try {
              final response = await http.get(url, headers: headers)
                  .timeout(const Duration(seconds: 8));

              if (response.statusCode == 200) {
                final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
                // Lưu toàn bộ map data nhận được
                variantDetails[variantId] = data;
                // print('Success: Received details for variant $variantId: $data');
              } else {
                print('Warning: Failed to fetch details for variant $variantId. Status: ${response.statusCode}, Body: ${response.body}');
              }
            } catch (e) {
              print('Error fetching details for variant $variantId: $e');
              if (e is TimeoutException) {
                print('Timeout fetching details for variant $variantId');
              }
            }
          }()
      );
    }

    await Future.wait(detailFutures);

    print('Finished fetching details. Final aggregated details count: ${variantDetails.length}');
    return variantDetails; // Trả về map chứa toàn bộ thông tin chi tiết
  }
}