// gridview_homescreen.dart
import 'package:cross_platform_mobile_app_development/models/gridview_product_model.dart';
import 'package:cross_platform_mobile_app_development/widgets/gridview_item.dart'; // Bạn cần sửa file này
import 'package:flutter/material.dart';

class GridviewHomescreen extends StatelessWidget {
  final List<GridviewProductModel> listProductInfoInHomescreen;
  // Bỏ selectedCategory nếu không dùng
  // final String? selectedCategory;

  const GridviewHomescreen({
    super.key,
    required this.listProductInfoInHomescreen,
    // this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    // --- THÊM LAYOUTBUILDER ĐỂ RESPONSIVE ---
    return LayoutBuilder(
      builder: (context, constraints) {
        // Tính toán số cột dựa trên chiều rộng màn hình
        int crossAxisCount = 2; // Mặc định cho điện thoại
        double screenWidth = constraints.maxWidth;
        if (screenWidth > 1200) {
          crossAxisCount = 5; // Màn hình rất lớn
        } else if (screenWidth > 900) {
          crossAxisCount = 4; // Màn hình lớn
        } else if (screenWidth > 600) {
          crossAxisCount = 3; // Màn hình trung bình / tablet dọc
        }
        // Điều chỉnh tỷ lệ khung hình để item không quá cao/thấp
        double childAspectRatio = (screenWidth / crossAxisCount) / (screenWidth / crossAxisCount * 1.4); // Chiều cao lớn hơn chiều rộng một chút


        // --- SỬ DỤNG GRIDVIEW.BUILDER ---
        return GridView.builder(
          // primary: false, // Không cần thiết trong TabBarView
          padding: const EdgeInsets.all(16), // Tăng padding
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount, // Số cột động
            crossAxisSpacing: 16, // Tăng khoảng cách
            mainAxisSpacing: 16, // Tăng khoảng cách
            childAspectRatio: childAspectRatio, // Tỷ lệ động
          ),
          itemCount: listProductInfoInHomescreen.length,
          itemBuilder: (context, index) {
            final element = listProductInfoInHomescreen[index];
            // --- GỌI GridviewItem (CẦN SỬA FILE GridviewItem.dart) ---
            return GridviewItem(
              gridviewProductModel: element,
              // Bỏ category nếu GridviewItem không dùng
              // category: element.category,
            );
          },
        );
      },
    );
  }
}