class AppConstants {
  static const String baseUrl = 'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com'; // Thay thế nếu URL của bạn khác
  static const String apiPrefix = '/api/v1';
  static const String currentUserId = '2'; // Hardcoded User ID

  // Helper để tạo URL đầy đủ cho hình ảnh
  static String getFullImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) {
      return 'https://via.placeholder.com/150/CCCCCC/FFFFFF?Text=NoImage'; // Ảnh mặc định
    }
    // Kiểm tra xem relativePath đã có http chưa (một số API có thể trả về URL đầy đủ)
    if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
      return relativePath;
    }
    return '$baseUrl/$relativePath';
  }

  // Mapping trạng thái đơn hàng từ tiếng Việt sang API
  static String? mapOrderStatusToApi(String vietnameseStatus) {
    switch (vietnameseStatus) {
      case 'Tất cả':
        return null; // Hoặc không truyền param status
      case 'Chờ xác nhận':
        return 'Pending';
      case 'Đã xác nhận':
        return 'Confirmed';
      case 'Đang vận chuyển':
        return 'Shipping';
      case 'Đã giao hàng':
        return 'Completed';
      case 'Đã huỷ':
        return 'Cancelled';
    // Thêm 'Returned' nếu cần
      default:
        return null;
    }
  }
}