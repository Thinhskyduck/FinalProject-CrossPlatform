import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; // Nếu cần gọi API /checkout
import 'package:intl/intl.dart';
import 'dart:convert'; // Nếu cần gọi API /checkout

import '../widgets/header.dart';
// import '../services/api_service.dart'; // Nếu có service cho API /checkout

// Giữ AppColors ở đây hoặc chuyển ra file riêng
class AppColors {
  static const Color themePageBackground = Color(0xFFF0F2F5);
  static const Color primaryRed = Color(0xFF007BFF); // Đã đổi màu
  static const Color textBlack = Color(0xFF222222);
  static const Color textGrey = Color(0xFF4A4A4A);
  static const Color textLightGrey = Color(0xFF757575);
  static const Color borderGrey = Color(0xFFE0E0E0);
  static const Color lightGreyBackground = Color(0xFFF8F8F8);
  static const Color sNullTagBackground = Color(0xFFFFE0E6); // Giữ màu cũ hoặc đổi
  static const Color sNullTagText = Color(0xFFD32F2F); // Giữ màu cũ hoặc đổi
  static const Color linkBlue = Color(0xFF007AFF);
}




class CheckoutPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> previewOrderData; // Nhận response từ /preview
  final String? guestEmail; // Nhận từ CheckoutInfoScreen
  final int userId;
  // Nhận từ CheckoutInfoScreen

  // final String paymentMethodForCheckout; // Nếu cần truyền riêng
  // final String notesForCheckout; // Nếu cần
  // final String couponCodeForCheckout; // Nếu cần
  // final int loyaltyPointsUsedForCheckout; // Nếu cần


  const CheckoutPaymentScreen({
    super.key,
    required this.previewOrderData,
    this.guestEmail,
    required this.userId,
    // required this.paymentMethodForCheckout,
    // required this.notesForCheckout,
    // required this.couponCodeForCheckout,
    // required this.loyaltyPointsUsedForCheckout,
  });

  @override
  State<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends State<CheckoutPaymentScreen> {
  final List<Map<String, dynamic>> _categories = [
    {'category_id': 1, 'name': 'Điện thoại'},
    {'category_id': 2, 'name': 'Laptop'},
  ];
  Map<String, dynamic>? _currentUserData; // Sẽ lấy một phần từ previewOrderData

  // Các thông tin đơn hàng sẽ lấy từ widget.previewOrderData
  // late Map<String, dynamic> _orderSummary;
  // late Map<String, dynamic> _shippingInfo;

  List<dynamic> get _orderItems => widget.previewOrderData['items'] as List? ?? [];
  List<Map<String, dynamic>> _detailedOrderItems = []; // Sẽ chứa product_name
  bool _isLoadingProductNames = true; // Trạng thái loading cho tên sản phẩm
  int get _cartItemCount => _detailedOrderItems.length; // Dùng _detailedOrderItems

  // String _discountCode = ""; // Sẽ lấy từ previewOrderData nếu có
  bool _agreeToTerms = false;
  bool _isLoadingCheckout = false; // State cho việc gọi API /checkout
  String? _checkoutErrorMessage;


  @override
  void initState() {
    super.initState();
    // _currentUserData có thể được xây dựng một phần từ previewOrderData
    // hoặc nếu CustomHeader cần nhiều thông tin hơn, bạn cần có cách lấy nó.
    // Tạm thời để null nếu không có sẵn đầy đủ.
    _currentUserData = {
      'full_name': widget.previewOrderData['recipient_name'] ?? 'Khách hàng',
      'phone': widget.previewOrderData['recipient_phone'] ?? '',
      'email': widget.guestEmail ?? '', // Sử dụng guestEmail đã truyền
      // 's_member_rank': widget.previewOrderData['user_rank'] ?? '', // Nếu API trả về
      'avatar_url': null, // Nếu API trả về
    };
    _initializeOrderItemsWithProductNames();

    // Thông tin tóm tắt và giao hàng giờ đã có sẵn trong widget.previewOrderData
  }

  Future<void> _initializeOrderItemsWithProductNames() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProductNames = true;
    });

    final rawOrderItems = widget.previewOrderData['items'] as List<dynamic>? ?? [];
    List<Map<String, dynamic>> tempDetailedItems = [];

    for (var rawItem in rawOrderItems) {
      if (rawItem is Map<String, dynamic>) {
        final variantId = rawItem['variant_id'] as int?;
        String? productName;
        String variantName = (rawItem['variant'] as Map<String, dynamic>?)?['variant_name'] ?? 'N/A';

        if (variantId != null) {
          try {
            // Gọi API lấy chi tiết variant (bao gồm product_name)
            final response = await http.get(
              Uri.parse('https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/variants/$variantId/price'),
              headers: {'accept': 'application/json'},
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body) as Map<String, dynamic>;
              productName = data['product_name'] as String?;
              // Cập nhật variant_name nếu API trả về (để đảm bảo đồng nhất)
              // variantName = data['variant_name'] as String? ?? variantName;
            } else {
              print('Failed to fetch product name for variant $variantId: ${response.statusCode}');
            }
          } catch (e) {
            print('Error fetching product name for variant $variantId: $e');
          }
        }
        // Tạo item mới với product_name
        tempDetailedItems.add({
          ...rawItem, // Giữ lại các trường cũ từ previewOrderData
          'product_name': productName ?? 'Sản phẩm không có tên', // Thêm product_name
          // 'display_name': productName != null ? '$productName - $variantName' : variantName, // Tên để hiển thị
        });
      }
    }

    if (mounted) {
      setState(() {
        _detailedOrderItems = tempDetailedItems;
        _isLoadingProductNames = false;
      });
    }
  }

  void _navigateToCatalog(int categoryId, String categoryName) {
    print('Payment: Navigating to category: $categoryName (ID: $categoryId)');
  }

  void _onCartPressed() {
    // Có thể quay lại màn hình Cart nếu cần, hoặc không làm gì
    int count = 0;
    Navigator.of(context).popUntil((_) => count++ >= 2); // Quay lại 2 màn hình
  }

  void _onAccountPressed() {
    print('Payment: Account pressed');
  }

  // Bỏ _applyDiscountCode vì mã giảm giá đã được áp dụng ở API /preview
  // void _applyDiscountCode() { ... }


  Future<void> _finalizeOrder() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đồng ý với điều khoản sử dụng.')),
      );
      return;
    }

    setState(() {
      _isLoadingCheckout = true;
      _checkoutErrorMessage = null;
    });

    // Lấy coupon_code:
    // Ưu tiên 'applied_coupon.code' nếu có, nếu không thì 'coupon_code' (nếu API preview trả về trực tiếp)
    // Hoặc để rỗng nếu không có coupon nào được áp dụng.
    String couponCodeForCheckout = "";
    if (widget.previewOrderData['applied_coupon'] != null &&
        widget.previewOrderData['applied_coupon'] is Map &&
        widget.previewOrderData['applied_coupon']['code'] != null) {
      couponCodeForCheckout = widget.previewOrderData['applied_coupon']['code'] as String;
    } else if (widget.previewOrderData['coupon_code'] != null && widget.previewOrderData['coupon_code'] is String) {
      // Trường hợp API preview trả về coupon_code trực tiếp mà người dùng đã nhập (kể cả khi không hợp lệ)
      // Nếu API checkout yêu cầu coupon code đã nhập, dù hợp lệ hay không, thì dùng trường này.
      // Nếu API checkout chỉ muốn coupon code HỢP LỆ, thì logic trên với applied_coupon là đủ.
      // Hiện tại, API preview response mẫu không có trường 'coupon_code' ở root level.
      // couponCodeForCheckout = widget.previewOrderData['coupon_code'] as String;
    }


    final checkoutRequestBody = {
      'recipient_name': widget.previewOrderData['recipient_name'] as String? ?? '',
      'recipient_phone': widget.previewOrderData['recipient_phone'] as String? ?? '',
      'shipping_address': widget.previewOrderData['shipping_address'] as String? ?? '',
      'notes': widget.previewOrderData['notes'] as String? ?? 'hello', // Giả sử API preview trả về 'notes'
      'payment_method': widget.previewOrderData['payment_method'] as String? ?? 'Tiền mặt', // Giả sử API preview trả về 'payment_method'
      'guest_email': widget.guestEmail,
      'coupon_code': couponCodeForCheckout,
      'use_loyalty_points': widget.previewOrderData['loyalty_points_used'] as int? ?? 0,
      'shipper_id': 0,
      // 'items' KHÔNG có trong request body của API /checkout này.
    };

    print("Checkout Request Body: ${jsonEncode(checkoutRequestBody)}");

    try {
      const String checkoutApiUrl = 'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/orders/checkout';
      final response = await http.post(
        Uri.parse(checkoutApiUrl),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'X-User-ID': widget.userId.toString(),
        },
        body: jsonEncode(checkoutRequestBody),
      ).timeout(const Duration(seconds: 20));

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) { // 200 OK hoặc 201 Created
          final responseData = jsonDecode(response.body) as Map<String, dynamic>;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đặt hàng thành công! Mã đơn: ${responseData['order_code']}')),
          );
          // Điều hướng đến màn hình cảm ơn hoặc trang chủ
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          String errorMessage = 'Lỗi đặt hàng.';
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map && errorData.containsKey('detail')) {
              errorMessage = 'Lỗi đặt hàng: ${errorData['detail']} (Code: ${response.statusCode})';
            } else {
              errorMessage = 'Lỗi đặt hàng: ${response.reasonPhrase} (Code: ${response.statusCode})';
            }
          } catch (e) {
            // Nếu response body không phải JSON hoặc không có 'detail'
            errorMessage = 'Lỗi đặt hàng: ${response.reasonPhrase} (Code: ${response.statusCode})';
          }
          setState(() {
            _checkoutErrorMessage = errorMessage;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkoutErrorMessage = 'Lỗi kết nối khi đặt hàng: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCheckout = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: AppColors.themePageBackground,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          kIsWeb ? (screenWidth > 900 ? 60 : 50) : 45 + MediaQuery.of(context).padding.top,
        ),
        child: CustomHeader(
          categories: _categories,
          currentUserData: _currentUserData, // Dùng _currentUserData đã khởi tạo
          cartItemCount: _cartItemCount,
          onCartPressed: _onCartPressed,
          onAccountPressed: _onAccountPressed,
          onCategorySelected: (Map<String, dynamic> selectedCategory) {
            final categoryId = selectedCategory['category_id'] as int?;
            final categoryName = selectedCategory['name'] as String?;
            if (categoryId != null && categoryName != null) {
              _navigateToCatalog(categoryId, categoryName);
            }
          },
          onLogoTap: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          onSearchSubmitted: (value) {
            print('Payment: Search submitted: $value');
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            width: isDesktop ? 800 : double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 0 : 16.0,
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row( // Nút Back và Tiêu đề
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textBlack),
                      onPressed: () => Navigator.of(context).pop(), // Quay lại CheckoutInfoScreen
                    ),
                    Expanded(
                      child: Text(
                        "Xác nhận thanh toán", // Hoặc "Xác nhận đơn hàng"
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBlack,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Để cân bằng IconButton
                  ],
                ),
                const SizedBox(height: 16),
                _buildStepIndicator(),
                const SizedBox(height: 24),
                _buildSectionTitle("DANH SÁCH SẢN PHẨM"),
                _isLoadingProductNames // Kiểm tra trạng thái loading
                    ? const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ))
                    : _buildOrderItemsList(), // Giờ sẽ dùng _detailedOrderItems
                const SizedBox(height: 24),
                _buildSectionTitle("TÓM TẮT ĐƠN HÀNG"),
                _buildOrderSummaryCard(),
                const SizedBox(height: 24),
                _buildSectionTitle("THÔNG TIN THANH TOÁN"),
                _buildPaymentMethodDisplayCard(),
                const SizedBox(height: 24),
                _buildSectionTitle("THÔNG TIN NHẬN HÀNG"),
                _buildShippingInfoCard(),
                const SizedBox(height: 24),
                _buildTermsAndConditionsCheckbox(),
                const SizedBox(height: 32),
                _buildFinalizeOrderSection(), // Nút "Thanh toán" / "Đặt hàng"
                if (_checkoutErrorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _checkoutErrorMessage!,
                      style: GoogleFonts.montserrat(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildScrollToTopButton(),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepItem("1. THÔNG TIN", isActive: false),
          Container(
            width: 60,
            height: 1,
            color: AppColors.primaryRed, // Line active
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          _buildStepItem("2. THANH TOÁN", isActive: true),
        ],
      ),
    );
  }

  Widget _buildStepItem(String title, {required bool isActive}) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppColors.primaryRed : AppColors.textGrey,
          ),
        ),
        if (isActive) ...[
          const SizedBox(height: 4),
          Container(width: 80, height: 2, color: AppColors.primaryRed),
        ]
      ],
    );
  }

  Widget _buildOrderItemsList() {
    if (_orderItems.isEmpty) {
      return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          color: AppColors.lightGreyBackground,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Không có sản phẩm nào trong đơn hàng.", style: GoogleFonts.montserrat()),
          )
      );
    }

    if (_detailedOrderItems.isEmpty && !_isLoadingProductNames) { // Chỉ hiển thị "không có SP" nếu đã load xong và rỗng
      return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          color: AppColors.lightGreyBackground,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Không có sản phẩm nào trong đơn hàng.", style: GoogleFonts.montserrat()),
          )
      );
    }
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: AppColors.lightGreyBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _detailedOrderItems.length,
          itemBuilder: (context, index) {
            final item = _detailedOrderItems[index]; // Đây là Map<String, dynamic>
            final variantDataFromPreview = item['variant'] as Map<String, dynamic>?;
            final imageUrl = variantDataFromPreview?['image_url'] ?? 'assets/images/placeholder.png';
            final bool isNetworkImage = imageUrl.startsWith('http');

            // Lấy product_name và variant_name
            final String productName = item['product_name'] as String? ?? "Sản phẩm";
            final String variantName = variantDataFromPreview?['variant_name'] as String? ?? "Không rõ";
            final String displayName = (productName == "Sản phẩm không có tên" || productName.isEmpty)
                ? variantName
                : "$productName - $variantName";

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  isNetworkImage
                      ? Image.network(
                    imageUrl,
                    width: 60, height: 60, fit: BoxFit.contain,
                    errorBuilder: (c,e,s) => Image.asset('assets/images/placeholder.png', width: 60, height: 60, fit: BoxFit.contain),
                  )
                      : Image.asset(
                    imageUrl, // Nếu là asset
                    width: 60, height: 60, fit: BoxFit.contain,
                    errorBuilder: (c,e,s) => Image.asset('assets/images/placeholder.png', width: 60, height: 60, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // API /preview trả về variant_name trong variant object,
                          // nhưng không có product_name. Bạn cần hiển thị tên phù hợp.
                          displayName, // Sử dụng displayName đã kết hợp
                          style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(double.tryParse(item['price_at_purchase']?.toString() ?? '0') ?? 0.0),
                          style: GoogleFonts.montserrat(fontSize: 13, color: AppColors.primaryRed, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "SL: ${item['quantity']}",
                    style: GoogleFonts.montserrat(fontSize: 13),
                  ),
                ],
              ),
            );
          },
          separatorBuilder: (context, index) => const Divider(),
        ),
      ),
    );
  }


  Widget _buildOrderSummaryCard() {
    String formatCurrency(double amount, {bool showSign = false}) {
      String sign = "";
      if (showSign) {
        sign = amount >= 0 ? "" : "- "; // Chỉ thêm dấu trừ
      }
      String value = amount.abs().toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
      return "$sign${value}đ";
    }

    final subtotal = double.tryParse(widget.previewOrderData['subtotal']?.toString() ?? '0') ?? 0.0;
    final shippingFee = double.tryParse(widget.previewOrderData['shipping_fee']?.toString() ?? '0') ?? 0.0;
    final couponDiscount = double.tryParse(widget.previewOrderData['coupon_discount_amount']?.toString() ?? '0') ?? 0.0;
    final loyaltyDiscount = double.tryParse(widget.previewOrderData['loyalty_discount_amount']?.toString() ?? '0') ?? 0.0;
    final totalAmount = double.tryParse(widget.previewOrderData['total_amount']?.toString() ?? '0') ?? 0.0;
    final String? appliedCouponCode = (widget.previewOrderData['applied_coupon'] as Map<String, dynamic>?)?['code'] as String?;


    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: AppColors.lightGreyBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Không cần nhập mã giảm giá ở đây nữa
            // Row(children: [ ... TextFormField ... TextButton("Áp dụng") ... ]),
            // const Divider(height: 20),
            _buildSummaryRow("Số lượng sản phẩm", _cartItemCount.toString()),
            _buildSummaryRow("Tiền hàng (tạm tính)", formatCurrency(subtotal)),
            _buildSummaryRow(
                "Phí vận chuyển",
                shippingFee == 0.0 ? "Miễn phí" : formatCurrency(shippingFee)),

            // Hiển thị giảm giá S-Student nếu API trả về
            // if (widget.previewOrderData['s_student_discount'] != null && widget.previewOrderData['s_student_discount'] != 0.0)
            //   _buildSummaryRow(
            //     "Giảm S-Student",
            //     formatCurrency(widget.previewOrderData['s_student_discount'].toDouble(), showSign: true),
            //     valueColor: AppColors.primaryRed,
            //     subtitle: "Quyền lợi Học sinh - Sinh viên",
            //   ),

            if (couponDiscount > 0.0)
              _buildSummaryRow(
                "Giảm giá coupon ${appliedCouponCode != null ? '($appliedCouponCode)' : ''}",
                formatCurrency(couponDiscount, showSign: true), // couponDiscount đã là số âm hoặc 0 từ API
                valueColor: AppColors.primaryRed,
              ),
            if (loyaltyDiscount > 0.0)
              _buildSummaryRow(
                "Giảm giá điểm tích lũy (${widget.previewOrderData['loyalty_points_used']} điểm)",
                formatCurrency(loyaltyDiscount, showSign: true), // loyaltyDiscount đã là số âm hoặc 0
                valueColor: AppColors.primaryRed,
              ),
            const Divider(height: 20),
            _buildSummaryRow(
              "Tổng tiền",
              formatCurrency(totalAmount),
              isTotal: true,
              subtitle: "(đã gồm VAT)",
            ),
            if (widget.previewOrderData['loyalty_points_earned'] != null && widget.previewOrderData['loyalty_points_earned'] > 0) ...[
              const SizedBox(height: 8),
              _buildSummaryRow(
                "Điểm tích lũy nhận được",
                "${widget.previewOrderData['loyalty_points_earned']} điểm",
                valueColor: Colors.green.shade700,
              ),
            ],
            // Hiển thị mã đơn hàng nếu API /preview trả về (thường thì không, API /checkout mới trả về)
            // if (widget.previewOrderData['order_code'] != null) ...[
            //   const Divider(height: 20),
            //   _buildSummaryRow(
            //     "Mã đơn hàng (tạm)",
            //     widget.previewOrderData!['order_code'],
            //     valueColor: AppColors.textBlack,
            //   ),
            // ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {Color? valueColor, bool isTotal = false, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: isTotal ? 14 : 13,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  color: AppColors.textGrey,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: AppColors.textLightGrey,
                  ),
                ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? (isTotal ? AppColors.primaryRed : AppColors.textBlack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textBlack,
        ),
      ),
    );
  }

  Widget _buildPaymentMethodDisplayCard() {
    final paymentMethod = widget.previewOrderData['payment_method'] as String? ?? "Chưa chọn";
    // Icon có thể dựa trên paymentMethod
    String paymentIconAsset = 'assets/images/payment_icon.png'; // default
    if (paymentMethod.toLowerCase().contains('tiền mặt')) {
      paymentIconAsset = 'assets/images/cash_icon.png'; // Cần có icon này
    } else if (paymentMethod.toLowerCase().contains('chuyển khoản')) {
      paymentIconAsset = 'assets/images/bank_transfer_icon.png'; // Cần có icon này
    } else if (paymentMethod.toLowerCase().contains('thẻ')) {
      paymentIconAsset = 'assets/images/card_icon.png'; // Cần có icon này
    }


    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: AppColors.lightGreyBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Image.asset( // Hoặc Icon
              paymentIconAsset,
              width: 32,
              height: 32,
              errorBuilder: (c, e, s) => Icon(Icons.payment, size: 32, color: AppColors.primaryRed),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paymentMethod,
                    style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryRed),
                  ),
                  // Text( // Thông tin thêm nếu có
                  //   "Giảm thêm tới 1.000.000đ",
                  //   style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textGrey),
                  // ),
                ],
              ),
            ),
            // Không cần Icon chevron_right nếu đây chỉ là hiển thị
            // const Icon(Icons.chevron_right, color: AppColors.textLightGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingInfoCard() {
    // Lấy thông tin từ widget.previewOrderData
    final String name = widget.previewOrderData['recipient_name'] ?? 'N/A';
    final String phone = widget.previewOrderData['recipient_phone'] ?? 'N/A';
    final String email = widget.guestEmail ?? (widget.previewOrderData['guest_email_from_api_if_any'] ?? 'N/A'); // Sử dụng guestEmail
    final String address = widget.previewOrderData['shipping_address'] ?? 'N/A';
    // Xác định deliveryType dựa trên shipping_address
    // Đây là ví dụ, bạn cần logic cụ thể hơn nếu địa chỉ cửa hàng có format đặc biệt
    final bool isStorePickup = address.toLowerCase().contains("cửa hàng") || address.toLowerCase().contains("store");
    final String deliveryTypeLabel = isStorePickup ? 'Nhận hàng tại' : 'Giao hàng đến';


    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: AppColors.lightGreyBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShippingInfoRow("Khách hàng", name, isName: true,/* widget.previewOrderData['s_member_rank'] ?? '' */),
            _buildShippingInfoRow("Số điện thoại", phone),
            _buildShippingInfoRow("Email", email),
            _buildShippingInfoRow(deliveryTypeLabel, address),
            if (widget.previewOrderData['notes'] != null && (widget.previewOrderData['notes'] as String).isNotEmpty)
              _buildShippingInfoRow("Ghi chú", widget.previewOrderData['notes'] ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingInfoRow(String label, String value,
      {bool isName = false, String? sMemberRank}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100, // Điều chỉnh nếu cần
            child: Text(
              label,
              style: GoogleFonts.montserrat(fontSize: 13, color: AppColors.textLightGrey),
            ),
          ),
          Expanded(
            child: Row( // Sử dụng Row để sMemberRank nằm cùng dòng
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded( // Text value có thể dài
                  child: Text(
                    value,
                    style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: AppColors.textBlack,
                        fontWeight: isName ? FontWeight.w600 : FontWeight.normal),
                  ),
                ),
                if (isName && sMemberRank != null && sMemberRank.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.sNullTagBackground, // Cần định nghĩa
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sMemberRank,
                      style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.sNullTagText), // Cần định nghĩa
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsAndConditionsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreeToTerms,
            onChanged: (bool? value) {
              setState(() {
                _agreeToTerms = value ?? false;
              });
            },
            activeColor: AppColors.primaryRed,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textGrey, height: 1.4),
              children: [
                const TextSpan(text: "Hoàn thành kiểm tra thông tin?"),
                // const TextSpan(text: " của CellphoneS.\nVới các giao dịch trên 10 triệu..."), // Phần này có thể không cần ở đây nữa
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinalizeOrderSection() {
    final totalAmount = double.tryParse(widget.previewOrderData['total_amount']?.toString() ?? '0') ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Tổng thanh toán:", // Hoặc "Tổng tiền"
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: AppColors.textBlack,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatCurrency(totalAmount),
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_agreeToTerms && !_isLoadingCheckout) ? _finalizeOrder : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                disabledBackgroundColor: AppColors.primaryRed.withOpacity(0.5),
              ),
              child: _isLoadingCheckout
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                  : const Text("Đặt hàng"), // Hoặc "Hoàn tất đơn hàng"
            ),
          ),
          // Không cần nút "Kiểm tra danh sách sản phẩm" ở đây nữa
          // const SizedBox(height: 8),
          // TextButton(...)
        ],
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return FloatingActionButton(
      onPressed: () { /* Cần ScrollController */ },
      mini: true,
      backgroundColor: AppColors.primaryRed.withOpacity(0.9),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 18),
          Text("Lên đầu", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 7)),
        ],
      ),
      elevation: 4,
    );
  }

  String _formatCurrency(double? amount) {
    if (amount == null) return "0đ";
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }
}

// Helper để format tiền tệ, bạn có thể đã có trong intl
// Hoặc dùng NumberFormat như trong CartScreen cũ
NumberFormat get _currencyFormatter {
  return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
}