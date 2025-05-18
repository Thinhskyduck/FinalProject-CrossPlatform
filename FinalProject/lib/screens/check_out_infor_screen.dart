// Trong file: CheckoutInfoScreen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Cần cho utf8 và jsonEncode/jsonDecode

// Giả sử CheckoutPaymentScreen được import đúng
import 'check_out_screen.dart';
import '../widgets/header.dart'; // Đảm bảo đường dẫn đúng

// --- Models cho API Địa chỉ ---
class Province {
  final int code;
  final String name;
  List<District> districts;

  Province({required this.code, required this.name, this.districts = const []});

  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      code: json['code'] as int,
      name: json['name'] as String,
      districts: (json['districts'] as List<dynamic>?)
          ?.map((dJson) => District.fromJson(dJson as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
  @override
  String toString() => name;
}

class District {
  final int code;
  final String name;
  List<Ward> wards;

  District({required this.code, required this.name, this.wards = const []});

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      code: json['code'] as int,
      name: json['name'] as String,
      wards: (json['wards'] as List<dynamic>?)
          ?.map((wJson) => Ward.fromJson(wJson as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
  @override
  String toString() => name;
}

class Ward {
  final int code;
  final String name;
  Ward({required this.code, required this.name});

  factory Ward.fromJson(Map<String, dynamic> json) {
    return Ward(
      code: json['code'] as int,
      name: json['name'] as String,
    );
  }
  @override
  String toString() => name;
}
// --- Kết thúc Models ---


class CheckoutInfoScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUserData; // Dữ liệu người dùng từ CartScreen
  final int userId; // User ID từ CartScreen

  const CheckoutInfoScreen({
    super.key,
    this.currentUserData,
    required this.userId,
  });

  @override
  State<CheckoutInfoScreen> createState() => _CheckoutInfoScreenState();
}

class _CheckoutInfoScreenState extends State<CheckoutInfoScreen> {
  final List<Map<String, dynamic>> _categories = [
    {'category_id': 1, 'name': 'Điện thoại'},
    {'category_id': 2, 'name': 'Laptop'},
  ];

  // Giả sử _cartItemCount sẽ được lấy từ nơi khác nếu cần hiển thị,
  // hiện tại không dùng trực tiếp trong logic chính của màn hình này
  int get _cartItemCount => 0;

  bool _receiveUpdates = false;
  bool _requestInvoice = false;
  bool _isLoading = false; // Loading chung cho nút "Tiếp tục" (API preview)
  String? _errorMessage;

  // State cho việc chọn địa chỉ
  List<Province> _provinces = [];
  Province? _selectedProvince;
  bool _isLoadingProvinces = false;

  List<District> _currentDistricts = [];
  District? _selectedDistrict;
  bool _isLoadingDistricts = false;

  List<Ward> _currentWards = [];
  Ward? _selectedWard;
  bool _isLoadingWards = false;
  // --- Hết State cho địa chỉ ---

  String _selectedPaymentMethod = 'Tiền mặt'; // Giá trị mặc định

  final TextEditingController _recipientNameController = TextEditingController();
  final TextEditingController _recipientPhoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _shippingAddressDetailController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _loyaltyPointsController = TextEditingController(text: '0');

  final List<String> _paymentMethods = ['Tiền mặt', 'Chuyển khoản', 'Thẻ tín dụng'];

  @override
  void initState() {
    super.initState();
    _fetchProvinces();

    // Điền thông tin người dùng nếu có
    _recipientNameController.text = widget.currentUserData?['full_name'] ?? '';
    _recipientPhoneController.text = widget.currentUserData?['phone'] ?? '';
    // Email có thể lấy từ currentUserData nếu có, hoặc để trống cho guest
    _emailController.text = widget.currentUserData?['email'] ?? '';
    _selectedPaymentMethod = _paymentMethods.first;
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _emailController.dispose();
    _shippingAddressDetailController.dispose();
    _noteController.dispose();
    _couponController.dispose();
    _loyaltyPointsController.dispose();
    super.dispose();
  }

  Future<void> _fetchProvinces() async {
    if (!mounted) return;
    setState(() { _isLoadingProvinces = true; _errorMessage = null; });
    try {
      final response = await http.get(Uri.parse('https://provinces.open-api.vn/api/p/'), headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 15));
      if (mounted) {
        if (response.statusCode == 200) {
          final decodedBody = utf8.decode(response.bodyBytes); // ĐÃ CÓ UTF-8
          final List<dynamic> data = jsonDecode(decodedBody);
          setState(() {
            _provinces = data.map((json) => Province.fromJson(json as Map<String, dynamic>)).toList();
            _isLoadingProvinces = false;
          });
        } else {
          final decodedErrorBody = utf8.decode(response.bodyBytes); // UTF-8 cho lỗi
          setState(() { _errorMessage = 'Không tải được tỉnh/thành (Lỗi ${response.statusCode}: $decodedErrorBody)'; _isLoadingProvinces = false; });
        }
      }
    } catch (e) {
      if (mounted) { setState(() { _errorMessage = 'Lỗi kết nối khi tải tỉnh/thành: $e'; _isLoadingProvinces = false; }); }
    }
  }

  Future<void> _fetchDistrictsForProvince(int provinceCode) async {
    if (!mounted) return;
    setState(() { _isLoadingDistricts = true; _currentDistricts = []; _selectedDistrict = null; _currentWards = []; _selectedWard = null; _errorMessage = null; });
    try {
      final response = await http.get(Uri.parse('https://provinces.open-api.vn/api/p/$provinceCode?depth=2'), headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 15));
      if (mounted) {
        if (response.statusCode == 200) {
          final decodedBody = utf8.decode(response.bodyBytes); // ĐÃ CÓ UTF-8
          final Map<String, dynamic> data = jsonDecode(decodedBody);
          final Province provinceWithDistricts = Province.fromJson(data);
          setState(() { _currentDistricts = provinceWithDistricts.districts; _isLoadingDistricts = false; });
        } else {
          final decodedErrorBody = utf8.decode(response.bodyBytes); // UTF-8 cho lỗi
          setState(() { _errorMessage = 'Không tải được quận/huyện (Lỗi ${response.statusCode}: $decodedErrorBody)'; _isLoadingDistricts = false; });
        }
      }
    } catch (e) {
      if (mounted) { setState(() { _errorMessage = 'Lỗi kết nối khi tải quận/huyện: $e'; _isLoadingDistricts = false; }); }
    }
  }

  Future<void> _fetchWardsForDistrict(int districtCode) async {
    if (!mounted) return;
    setState(() { _isLoadingWards = true; _currentWards = []; _selectedWard = null; _errorMessage = null; });
    try {
      final response = await http.get(Uri.parse('https://provinces.open-api.vn/api/d/$districtCode?depth=2'), headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 15));
      if (mounted) {
        if (response.statusCode == 200) {
          final decodedBody = utf8.decode(response.bodyBytes); // ĐÃ CÓ UTF-8
          final Map<String, dynamic> data = jsonDecode(decodedBody);
          final District districtWithWards = District.fromJson(data);
          setState(() { _currentWards = districtWithWards.wards; _isLoadingWards = false; });
        } else {
          final decodedErrorBody = utf8.decode(response.bodyBytes); // UTF-8 cho lỗi
          setState(() { _errorMessage = 'Không tải được phường/xã (Lỗi ${response.statusCode}: $decodedErrorBody)'; _isLoadingWards = false; });
        }
      }
    } catch (e) {
      if (mounted) { setState(() { _errorMessage = 'Lỗi kết nối khi tải phường/xã: $e'; _isLoadingWards = false; }); }
    }
  }

  Future<void> _proceedToPaymentScreen() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    // --- Validations ---
    if (_recipientNameController.text.trim().isEmpty) {
      if (mounted) setState(() { _errorMessage = "Vui lòng nhập họ tên người nhận."; _isLoading = false; }); return;
    }
    if (_recipientPhoneController.text.trim().isEmpty) {
      if (mounted) setState(() { _errorMessage = "Vui lòng nhập số điện thoại người nhận."; _isLoading = false; }); return;
    }
    if (_selectedProvince == null) {
      if (mounted) setState(() { _errorMessage = "Vui lòng chọn Tỉnh/Thành phố."; _isLoading = false; }); return;
    }
    if (_selectedDistrict == null) {
      if (mounted) setState(() { _errorMessage = "Vui lòng chọn Quận/Huyện."; _isLoading = false; }); return;
    }
    if (_shippingAddressDetailController.text.trim().isEmpty) {
      if (mounted) setState(() { _errorMessage = "Vui lòng nhập chi tiết địa chỉ (số nhà, tên đường...)."; _isLoading = false; }); return;
    }
    // --- End Validations ---

    String fullAddress = _shippingAddressDetailController.text.trim();
    if (_selectedWard != null) {
      fullAddress += ", ${_selectedWard!.name}";
    }
    // Luôn thêm quận/huyện và tỉnh/thành phố
    fullAddress += ", ${_selectedDistrict!.name}, ${_selectedProvince!.name}";

    // Request body cho API /orders/preview
    // API này có thể không cần trường 'items' nếu nó tự lấy từ giỏ hàng của user
    // qua X-User-ID. Nếu cần, bạn phải truyền selectedItems từ CartScreen qua.
    final requestBody = {
      'recipient_name': _recipientNameController.text.trim(),
      'recipient_phone': _recipientPhoneController.text.trim(),
      'shipping_address': fullAddress,
      'notes': _noteController.text.trim(),
      'payment_method': _selectedPaymentMethod,
      'coupon_code': _couponController.text.trim(),
      'use_loyalty_points': int.tryParse(_loyaltyPointsController.text.trim()) ?? 0,
      // 'items': widget.selectedItemsForPreview, // BỎ COMMENT NẾU API CẦN
    };

    try {
      final response = await http.post(
        Uri.parse('https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/orders/preview'),
        headers: {
          'X-User-ID': widget.userId.toString(),
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody), // jsonEncode mặc định là UTF-8
      ).timeout(const Duration(seconds: 20)); // Tăng timeout một chút cho API này

      if (mounted) {
        final decodedBody = utf8.decode(response.bodyBytes); // LUÔN DECODE CHO CẢ THÀNH CÔNG VÀ LỖI

        if (response.statusCode == 200) {
          final previewData = jsonDecode(decodedBody) as Map<String, dynamic>;
          final guestEmailForCheckout = _emailController.text.trim();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CheckoutPaymentScreen(
                previewOrderData: previewData,
                guestEmail: guestEmailForCheckout.isNotEmpty ? guestEmailForCheckout : null, // Gửi email nếu có
                userId: widget.userId,
              ),
            ),
          );
        } else {
          print('Lỗi xem trước đơn hàng (Preview API): ${response.statusCode} - $decodedBody');
          String apiErrorMessage = 'Lỗi xem trước đơn hàng.';
          try {
            final errorJson = jsonDecode(decodedBody);
            if (errorJson is Map && errorJson.containsKey('detail')) {
              apiErrorMessage = errorJson['detail'] as String;
            } else {
              apiErrorMessage += ' (Code: ${response.statusCode})';
            }
          } catch (_) {
            apiErrorMessage += ' (Code: ${response.statusCode})';
          }
          setState(() { _errorMessage = apiErrorMessage; });
        }
      }
    } catch (e) {
      print('Lỗi kết nối khi xem trước đơn hàng: $e');
      if (mounted) { setState(() { _errorMessage = 'Lỗi kết nối hoặc timeout khi xem trước đơn hàng.'; }); }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  void _navigateToCatalog(int categoryId, String categoryName) {
    print('CheckoutInfo: Navigating to category: $categoryName (ID: $categoryId)');
    // Navigator.push(context, MaterialPageRoute(builder: (context) => YourCatalogScreen(...)));
  }
  void _onCartPressed() {
    // Nếu màn hình này được push từ Cart, pop sẽ quay lại Cart
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      // Xử lý trường hợp không thể pop (ví dụ: điều hướng về trang chủ hoặc cart)
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => CartScreen()));
      print("Cannot pop, maybe navigate to CartScreen or HomeScreen");
    }
  }
  void _onAccountPressed() {
    print('CheckoutInfo: Account pressed');
    // Navigator.push(context, MaterialPageRoute(builder: (context) => YourAccountScreen(...)));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.themePageBackground,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(
                kIsWeb ? (screenWidth > 900 ? 60 : 50) : 45 + MediaQuery.of(context).padding.top),
            child: CustomHeader(
              categories: _categories,
              currentUserData: widget.currentUserData,
              cartItemCount: _cartItemCount, // Cần cập nhật nếu muốn hiển thị đúng
              onCartPressed: _onCartPressed,
              onAccountPressed: _onAccountPressed,
              onCategorySelected: (Map<String, dynamic> selectedCategory) {
                final categoryId = selectedCategory['category_id'] as int?;
                final categoryName = selectedCategory['name'] as String?;
                if (categoryId != null && categoryName != null) {
                  _navigateToCatalog(categoryId, categoryName);
                }
              },
              onLogoTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
              onSearchSubmitted: (value) => print('CheckoutInfo: Search submitted: $value'),
            ),
          ),
          body: SingleChildScrollView( // Cho phép cuộn toàn bộ nội dung
            // controller: _scrollController, // Nếu bạn muốn nút "Lên đầu" hoạt động
            child: Center(
              child: Container(
                width: isDesktop ? 800 : double.infinity, // Giới hạn chiều rộng trên desktop
                padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 0 : 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepIndicator(),
                    const SizedBox(height: 24),
                    _buildSectionTitle("THÔNG TIN KHÁCH HÀNG"),
                    _buildCustomerInfoCard(),
                    const SizedBox(height: 24),
                    _buildSectionTitle("ĐỊA CHỈ GIAO HÀNG"),
                    _buildDeliveryDetailsCard(),
                    const SizedBox(height: 16),
                    _buildSectionTitle("THANH TOÁN & ƯU ĐÃI"),
                    _buildPaymentAndPromoCard(),
                    const SizedBox(height: 16),
                    _buildProceedButton(),
                    // Hiển thị lỗi nếu có, không phải dạng Toast chồng lên
                    if (_errorMessage != null && !(_isLoadingProvinces || _isLoadingDistricts || _isLoadingWards || _isLoading))
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Center(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.montserrat(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Nút scroll to top có thể không cần thiết nếu nội dung không quá dài
          // hoặc bạn có thể sử dụng ScrollController để kích hoạt nó.
          // floatingActionButton: _buildScrollToTopButton(),
        ),
        // Overlay loading chung cho các API địa chỉ và API preview
        if (_isLoadingProvinces || _isLoadingDistricts || _isLoadingWards || _isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
          ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepItem("1. THÔNG TIN", isActive: true),
          Container(
            width: 60, // Điều chỉnh độ rộng của đường kẻ
            height: 1,
            color: AppColors.borderGrey,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          _buildStepItem("2. THANH TOÁN", isActive: false), // Bước này chưa active
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
          Container(width: 60, height: 2, color: AppColors.primaryRed), // Đường gạch chân cho bước active
        ]
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textBlack,
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    String sMemberRank = widget.currentUserData?['s_member_rank'] ?? "";
    // Hoặc nếu bạn lưu rank là int:
    // int memberRankId = widget.currentUserData?['member_rank_id'] ?? 0;
    // String sMemberRank = getRankNameFromId(memberRankId); // Hàm helper để lấy tên rank

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "THÔNG TIN LIÊN HỆ",
                  style: GoogleFonts.montserrat(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textBlack),
                ),
                if (sMemberRank.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.sNullTagBackground, // Sử dụng màu đã định nghĩa
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sMemberRank,
                      style: GoogleFonts.montserrat(
                          fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.sNullTagText), // Sử dụng màu đã định nghĩa
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text("Họ và tên người nhận *",
                style: GoogleFonts.montserrat(
                    fontSize: 13, color: AppColors.textLightGrey, fontWeight: FontWeight.w500)),
            TextFormField(
              controller: _recipientNameController,
              style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textBlack),
              decoration: InputDecoration(
                hintText: "Nhập họ và tên",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.borderGrey)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryRed)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Text("Số điện thoại người nhận *",
                style: GoogleFonts.montserrat(
                    fontSize: 13, color: AppColors.textLightGrey, fontWeight: FontWeight.w500)),
            TextFormField(
              controller: _recipientPhoneController,
              style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textBlack),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "Nhập số điện thoại",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.borderGrey)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryRed)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Text("Email (dùng cho hóa đơn VAT và guest checkout nếu có)",
                style: GoogleFonts.montserrat(
                    fontSize: 13, color: AppColors.textLightGrey, fontWeight: FontWeight.w500)),
            TextFormField(
              controller: _emailController,
              style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textBlack),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: "Nhập email",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.borderGrey)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryRed)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDeliveryDetailsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdownField<Province>(
              label: "Tỉnh / Thành Phố *",
              value: _selectedProvince,
              items: _provinces,
              onChanged: (Province? newValue) {
                if (newValue != null) { // Không cần kiểm tra isLoading ở đây vì DropdownButtonFormField tự disable
                  setState(() {
                    _selectedProvince = newValue;
                    // Reset quận/huyện và phường/xã khi tỉnh thay đổi
                    _selectedDistrict = null; _currentDistricts = [];
                    _selectedWard = null; _currentWards = [];
                    if(mounted) _fetchDistrictsForProvince(newValue.code);
                  });
                }
              },
              hint: _isLoadingProvinces ? "Đang tải tỉnh/thành..." : "Chọn tỉnh / thành phố",
              disabled: _isLoadingProvinces,
            ),
            const SizedBox(height: 16),

            _buildDropdownField<District>(
              label: "Quận / Huyện *",
              value: _selectedDistrict,
              items: _currentDistricts,
              onChanged: (District? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedDistrict = newValue;
                    // Reset phường/xã khi quận/huyện thay đổi
                    _selectedWard = null; _currentWards = [];
                    if(mounted) _fetchWardsForDistrict(newValue.code);
                  });
                }
              },
              hint: _isLoadingDistricts ? "Đang tải quận/huyện..." : (_selectedProvince == null ? "Vui lòng chọn Tỉnh/Thành" : "Chọn quận / huyện"),
              disabled: _isLoadingDistricts || _selectedProvince == null || _provinces.isEmpty, // Thêm kiểm tra _provinces.isEmpty
            ),
            const SizedBox(height: 16),

            _buildDropdownField<Ward>(
              label: "Phường / Xã", // Không còn dấu * vì có thể không bắt buộc
              value: _selectedWard,
              items: _currentWards,
              onChanged: (Ward? newValue) {
                if (newValue != null) {
                  setState(() { _selectedWard = newValue; });
                }
              },
              hint: _isLoadingWards ? "Đang tải phường/xã..." : (_selectedDistrict == null ? "Vui lòng chọn Quận/Huyện" : "Chọn phường / xã"),
              disabled: _isLoadingWards || _selectedDistrict == null || _currentDistricts.isEmpty, // Thêm kiểm tra _currentDistricts.isEmpty
            ),
            const SizedBox(height: 16),
            Text("Số nhà, tên đường, chi tiết khác *",
                style: GoogleFonts.montserrat(fontSize: 13, color: AppColors.textLightGrey, fontWeight: FontWeight.w500)),
            TextFormField(
              controller: _shippingAddressDetailController,
              style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textBlack),
              decoration: InputDecoration(
                hintText: "Nhập số nhà, tên đường, tòa nhà...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderGrey)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primaryRed)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2, // Cho phép nhập nhiều dòng hơn
            ),
            const SizedBox(height: 16),
            Text("Ghi chú (nếu có)", style: GoogleFonts.montserrat(fontSize: 13, color: AppColors.textLightGrey, fontWeight: FontWeight.w500)),
            TextFormField(
              controller: _noteController,
              style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textBlack),
              decoration: InputDecoration(
                hintText: "Nhập ghi chú cho đơn hàng (vd: giao vào giờ hành chính,...)", // Gợi ý rõ hơn
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderGrey)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primaryRed)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String hint,
    bool disabled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.montserrat(
                fontSize: 13, color: AppColors.textLightGrey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          value: value,
          items: items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString(), // Tên sẽ được lấy từ hàm toString() của model
                style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textBlack),
                overflow: TextOverflow.ellipsis, // Tránh tràn text
              ),
            );
          }).toList(),
          onChanged: disabled ? null : onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.montserrat(
                fontSize: 14, color: AppColors.textLightGrey.withOpacity(0.7)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderGrey)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primaryRed)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: disabled, // Nền mờ khi disabled
            fillColor: disabled ? Theme.of(context).disabledColor.withOpacity(0.05) : null,
          ),
          isExpanded: true, // Cho dropdown chiếm hết chiều ngang
          icon: Icon(Icons.arrow_drop_down, // Icon mũi tên
              color: disabled ? AppColors.textLightGrey.withOpacity(0.5) : AppColors.textGrey),
        ),
      ],
    );
  }

  Widget _buildPaymentAndPromoCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Phương thức thanh toán",
              style: GoogleFonts.montserrat(
                  fontSize: 13, color: AppColors.textLightGrey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _selectedPaymentMethod,
              items: _paymentMethods.map((method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(method, style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textBlack)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (mounted) {
                  setState(() {
                    _selectedPaymentMethod = newValue ?? _paymentMethods.first;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: "Chọn phương thức thanh toán",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.borderGrey)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryRed)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              isExpanded: true,
            ),
            const SizedBox(height: 16),
            Text(
              "Mã giảm giá",
              style: GoogleFonts.montserrat(
                  fontSize: 13, color: AppColors.textLightGrey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _couponController,
              style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textBlack),
              decoration: InputDecoration(
                hintText: "Nhập mã giảm giá (nếu có)", // Thêm gợi ý
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.borderGrey)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryRed)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Sử dụng điểm tích lũy",
              style: GoogleFonts.montserrat(
                  fontSize: 13, color: AppColors.textLightGrey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _loyaltyPointsController,
              style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textBlack),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "Nhập số điểm muốn sử dụng (mặc định là 0)", // Thêm gợi ý
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.borderGrey)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryRed)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildProceedButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16), // Khoảng cách trên dưới cho nút
      child: SizedBox(
        width: double.infinity, // Nút chiếm hết chiều ngang
        child: ElevatedButton(
          onPressed: _isLoading ? null : _proceedToPaymentScreen, // Disable khi đang loading
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12), // Tăng chiều cao nút
            textStyle: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            disabledBackgroundColor: AppColors.primaryRed.withOpacity(0.5), // Màu khi disable
          ),
          child: const Text("Tiếp tục"),
        ),
      ),
    );
  }

  // Cần ScrollController để nút này hoạt động đúng
  // final ScrollController _scrollController = ScrollController();
  Widget _buildScrollToTopButton() {
    return FloatingActionButton(
      onPressed: () {
        // _scrollController.animateTo(
        //   0.0,
        //   duration: Duration(milliseconds: 500),
        //   curve: Curves.easeInOut,
        // );
      },
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
}