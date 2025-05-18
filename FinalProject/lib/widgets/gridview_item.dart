// gridview_item.dart
import 'package:flutter/material.dart';
import 'package:cross_platform_mobile_app_development/models/gridview_product_model.dart';

class GridviewItem extends StatelessWidget {
  final GridviewProductModel gridviewProductModel;
  // Bỏ 'category' nếu không dùng đến trong widget này
  // final String category;

  const GridviewItem({
    super.key,
    required this.gridviewProductModel,
    // required this.category, // Bỏ nếu không dùng
  });

  @override
  Widget build(BuildContext context) {
    // Định nghĩa màu sắc hoặc lấy từ Theme
    final Color primaryColor = Colors.blue[700]!;
    final Color cardBackgroundColor = Colors.white;
    final Color textColor = Colors.black87;

    return Card( // Sử dụng Card cho hiệu ứng và bo góc
      elevation: 2.5, // Độ nổi nhẹ nhàng hơn
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0), // Bo góc mềm mại hơn
        // Có thể thêm viền nếu muốn, nhưng thường Card không cần viền rõ
        // side: BorderSide(color: primaryColor.withOpacity(0.3), width: 1),
      ),
      clipBehavior: Clip.antiAlias, // Quan trọng để bo góc nội dung bên trong (ảnh)
      child: InkWell( // Thêm hiệu ứng khi nhấn
        onTap: gridviewProductModel.onTap, // Giữ nguyên logic onTap
        splashColor: primaryColor.withOpacity(0.1), // Màu splash xanh nhạt
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Kéo giãn các thành phần con
          children: [
            // --- Phần hiển thị ảnh ---
            Expanded(
              flex: 3, // Cho ảnh chiếm tỷ lệ lớn hơn
              child: Container( // Container chứa ảnh để dễ dàng thêm padding/margin nếu cần
                color: Colors.grey[100], // Màu nền nhẹ cho khu vực ảnh
                child: Padding(
                  padding: const EdgeInsets.all(8.0), // Khoảng đệm quanh ảnh
                  child: Image.asset(
                    gridviewProductModel.imageUrl,
                    fit: BoxFit.contain, // Hiển thị toàn bộ ảnh, không bị cắt xén/méo
                    // Xử lý lỗi tải ảnh
                    errorBuilder: (context, error, stackTrace) {
                      print("Lỗi tải ảnh item: ${gridviewProductModel.imageUrl} - $error");
                      return Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey[400],
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // --- Loại bỏ lớp phủ màu đỏ chéo ---
            // Phần code tạo màu đỏ đã được xóa bỏ hoàn toàn.

            // --- Phần hiển thị tiêu đề ---
            Expanded(
              flex: 2, // Cho text chiếm tỷ lệ nhỏ hơn
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // Padding cho text
                // Có thể thêm màu nền nhẹ nếu muốn tách biệt khỏi ảnh
                // color: cardBackgroundColor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // Căn giữa text
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gridviewProductModel.title, // Hiển thị đầy đủ tiêu đề
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14, // Cỡ chữ phù hợp
                        fontWeight: FontWeight.w600, // Đậm vừa phải
                      ),
                      maxLines: 2, // Giới hạn 2 dòng
                      overflow: TextOverflow.ellipsis, // Hiển thị ... nếu quá dài
                      textAlign: TextAlign.start, // Căn lề trái
                    ),
                    // Có thể thêm giá hoặc thông tin khác ở đây
                    // const SizedBox(height: 4),
                    // Text("\$XXX", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}