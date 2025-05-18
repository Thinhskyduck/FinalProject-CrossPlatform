import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../models/order.dart';
// Import model đã tạo ở Bước 1
// import 'path/to/your/models/order_preview_response.dart';

class OrderApiService {
  // Giả sử bạn có baseUrl tương tự CartApiService
  static const String _baseUrl = 'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1';

  Future<OrderPreviewResponse> getOrderPreview({
    required int userId,
    required String recipientName,
    required String recipientPhone,
    required String shippingAddress,
    String? notes,
    String paymentMethod = "COD", // Giá trị mặc định hoặc lấy từ state
    String? couponCode,
    int useLoyaltyPoints = 0, // Mặc định không dùng
  }) async {
    final url = Uri.parse('$_baseUrl/orders/preview');
    final headers = {
      'Content-Type': 'application/json',
      'accept': 'application/json',
      'X-User-ID': userId.toString(),
    };
    final body = jsonEncode({
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'shipping_address': shippingAddress,
      'notes': notes ?? "", // Gửi chuỗi rỗng nếu null
      'payment_method': paymentMethod,
      'coupon_code': couponCode ?? "", // Gửi chuỗi rỗng nếu null
      'use_loyalty_points': useLoyaltyPoints,
    });

    try {
      print('Calling Order Preview API...');
      print('Request body: $body');
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        print('Order Preview Success: ${response.body}');
        // Parse dữ liệu bằng Model Class
        return OrderPreviewResponse.fromJson(responseData);
      } else {
        // Xử lý lỗi cụ thể hơn nếu cần (ví dụ: 400 Bad Request, 404 Cart empty,...)
        print('Order Preview Failed: ${response.statusCode} - ${response.body}');
        String errorMessage = 'Lỗi khi xem trước đơn hàng (${response.statusCode}).';
        try {
          final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorBody is Map && errorBody.containsKey('detail')) {
            errorMessage = errorBody['detail'] as String;
          }
        } catch(_){}
        throw Exception(errorMessage);
      }
    } on TimeoutException {
      print('Order Preview Timeout');
      throw Exception('Hết thời gian chờ khi xem trước đơn hàng.');
    } catch (e) {
      print('Error calling Order Preview: $e');
      // Ném lại lỗi hoặc Exception đã có thông báo
      if (e is Exception) {
        throw e;
      }
      throw Exception('Không thể xem trước đơn hàng: $e');
    }
  }

  String getFullImageUrl(String? relativePath) {
    // Trường hợp không có ảnh hoặc đường dẫn không hợp lệ
    if (relativePath == null || relativePath.isEmpty || relativePath.toLowerCase() == "string") {
      // Trả về ảnh placeholder
      // Bạn có thể dùng URL placeholder online hoặc đường dẫn tới ảnh trong assets
      // Ví dụ URL online:
      return 'https://via.placeholder.com/150/CCCCCC/FFFFFF?text=No+Image';
      // Ví dụ ảnh trong assets (yêu cầu có thư mục assets/images trong dự án):
      // return 'assets/images/placeholder_product.png';
    }

    // Nếu đã là URL đầy đủ (bắt đầu bằng http)
    if (relativePath.startsWith('http')) {
      return relativePath;
    }

    // Xử lý đường dẫn tương đối (ví dụ: 'img/product_thumnail/7.jpg')
    // 1. Chuẩn hóa dấu phân cách (thay \ thành /)
    String normalizedPath = relativePath.replaceAll('\\', '/');
    // 2. Xóa dấu / ở đầu nếu có (để tránh thành // khi nối chuỗi)
    if (normalizedPath.startsWith('/')) {
      normalizedPath = normalizedPath.substring(1);
    }

    // 3. Nối với Base URL phù hợp cho ảnh
    //    Logic này phụ thuộc vào cách server của bạn phục vụ ảnh.
    //    Ví dụ 1: Ảnh được phục vụ từ cùng domain API nhưng không có /api/v1
    //    final imageBaseUrl = _baseUrl.replaceAll("/api/v1", "");
    //    return '$imageBaseUrl/$normalizedPath';

    //    Ví dụ 2: Ảnh được phục vụ từ một CDN hoặc domain khác hoàn toàn
    //    final imageCdnUrl = "https://your-image-cdn.com";
    //    return '$imageCdnUrl/$normalizedPath';

    //    Ví dụ 3: Nếu chưa chắc chắn, dùng placeholder để tránh lỗi
    print("Warning: Relative image path detected ('$relativePath'), but image base URL logic needs verification. Using placeholder.");
    return 'https://via.placeholder.com/150/EEEEEE/AAAAAA?text=CheckURL'; // Placeholder khác để dễ nhận biết
  }
}