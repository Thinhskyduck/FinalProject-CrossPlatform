import 'dart:convert'; // Cần cho utf8 và jsonEncode/jsonDecode

import 'package:cross_platform_mobile_app_development/screens/profile_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/header.dart';
import '../services/cart_api_service.dart';
import 'check_out_infor_screen.dart';
import 'package:http/http.dart' as http;
import '../theme/app_colors.dart';

class CartScreen extends StatefulWidget {
  final int? addedVariantId;
  final double? addedCurrentPrice;

  const CartScreen({super.key, this.addedVariantId, this.addedCurrentPrice});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final CartApiService _cartApiService;
  final List<Map<String, dynamic>> _categories = [
    {'category_id': 1, 'name': 'Điện thoại'},
    {'category_id': 2, 'name': 'Laptop'},
  ];

  Map<String, dynamic>? _currentUserData;
  int? _userId;

  bool _isLoadingUserData = true;

  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _selectAll = false;

  Future<void> _loadUserDataAndInitialize() async {
    if (!mounted) return;
    setState(() {
      _isLoadingUserData = true;
      _errorMessage = null;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? loadedBackendUserIdString = prefs.getString('user_uid');
      final String? loadedFullName = prefs.getString('user_fullName');
      final String? loadedAvatarUrl = prefs.getString('user_avatarUrl');
      final String? loadedPhone = prefs.getString('user_phone');

      if (loadedBackendUserIdString != null && loadedBackendUserIdString.isNotEmpty) {
        _userId = int.tryParse(loadedBackendUserIdString);
        if (_userId == null) {
          print("Lỗi: Không thể parse user_uid '$loadedBackendUserIdString' thành int.");
          _errorMessage = "Lỗi định dạng ID người dùng. Vui lòng thử đăng nhập lại.";
        }
      } else {
        print("Lỗi: Không tìm thấy user_uid hoặc rỗng trong SharedPreferences.");
        _errorMessage = "Không tìm thấy ID người dùng. Vui lòng đăng nhập lại.";
      }

      _currentUserData = {
        'full_name': loadedFullName ?? 'Khách',
        'avatar_url': loadedAvatarUrl,
        'phone': loadedPhone ?? '',
      };
      if (!mounted) return;

      if (_userId != null && _userId! > 0) {
        setState(() {
          _isLoadingUserData = false;
        });
        await _fetchCartData();
      } else {
        setState(() {
          _isLoadingUserData = false;
          _isLoading = false;
        });
      }

    } catch (e) {
      print("Lỗi khi tải dữ liệu người dùng từ SharedPreferences: $e");
      if (!mounted) return;
      setState(() {
        _isLoadingUserData = false;
        _isLoading = false;
        _errorMessage = "Lỗi tải thông tin người dùng. Vui lòng thử lại.";
        _userId = null;
        _currentUserData = { 'full_name': 'Khách', 'avatar_url': null, 'phone': '' };
      });
    }
  }

  Future<Map<String, dynamic>?> _previewOrder() async {
    if (_userId == null || _userId! <= 0) {
      if(mounted) { // Kiểm tra mounted trước khi setState
        setState(() {
          _errorMessage = 'Thông tin người dùng không hợp lệ để xem trước đơn hàng.';
          _isLoading = false;
        });
      }
      return null;
    }

    if(mounted) { // Kiểm tra mounted trước khi setState
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }


    try {
      final selectedItems = _cartItems
          .where((item) => item['isSelected'] as bool? ?? false)
          .toList();

      if (selectedItems.isEmpty) {
        throw Exception('Chưa chọn sản phẩm nào để xem trước.'); // Sửa lại thông báo
      }

      final requestBody = {
        'recipient_name': _currentUserData?['full_name'] ?? 'Khách hàng',
        'recipient_phone': _currentUserData?['phone'] ?? '',
        'shipping_address': '',
        'notes': '',
        'payment_method': '',
        'coupon_code': '',
        'use_loyalty_points': 0,
        'items': selectedItems.map((item) => {
          'variant_id': item['variant_id'],
          'quantity': item['quantity'],
        }).toList(),
      };

      final response = await http.post(
        Uri.parse('https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/orders/preview'),
        headers: {
          'X-User-ID': _userId!.toString(),
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody), // Request body đã được encode
      ).timeout(const Duration(seconds: 15)); // Thêm timeout

      if (!mounted) return null;

      final decodedBody = utf8.decode(response.bodyBytes); // GIẢI MÃ UTF-8 Ở ĐÂY

      if (response.statusCode == 200) {
        return jsonDecode(decodedBody) as Map<String, dynamic>; // Parse JSON từ decodedBody
      } else {
        print('Failed to preview order: ${response.statusCode} - $decodedBody');
        String errorMessage = 'Lỗi xem trước đơn hàng (${response.statusCode}).';
        try {
          final errorBodyJson = jsonDecode(decodedBody); // Thử parse lỗi JSON
          if (errorBodyJson is Map && errorBodyJson.containsKey('detail')) {
            errorMessage = errorBodyJson['detail'] as String; // Ưu tiên thông báo 'detail'
          } else {
            errorMessage += ' Phản hồi: $decodedBody';
          }
        } catch (_) {
          // Nếu không parse được JSON, dùng decodedBody làm thông tin lỗi
          errorMessage += ' Phản hồi: $decodedBody';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (!mounted) return null;
      print("Error in _previewOrder: $e");
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', ''); // Hiển thị lỗi cho người dùng
      });
      return null;
    } finally {
      if (!mounted) return null;
      setState(() {
        _isLoading = false;
      });
    }
  }


  int get _cartItemCount => _selectedItemCount;

  double get _subtotal {
    return _cartItems
        .where((item) => item['isSelected'] as bool? ?? false)
        .fold(0.0, (sum, item) {
      double price = item['currentPrice'] as double? ?? 0.0;
      int quantity = item['quantity'] as int? ?? 1;
      return sum + (price * quantity);
    });
  }

  double get _totalDiscount {
    return _cartItems
        .where((item) => item['isSelected'] as bool? ?? false)
        .fold(0.0, (sum, item) {
      double oldPrice = item['oldPrice'] as double? ?? 0.0;
      double currentPrice = item['currentPrice'] as double? ?? 0.0;
      int quantity = item['quantity'] as int? ?? 1;
      if (oldPrice > currentPrice) {
        return sum + (oldPrice - currentPrice) * quantity;
      }
      return sum;
    });
  }

  String formatCurrency(double? amount) {
    if (amount == null || amount == 0.0) {
      return "Liên hệ";
    }
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  int get _selectedItemCount {
    return _cartItems.where((item) => item['isSelected'] as bool? ?? false).length;
  }

  @override
  void initState() {
    super.initState();
    _cartApiService = CartApiService();
    _loadUserDataAndInitialize();
  }

  Future<void> _fetchCartData({bool showLoading = true}) async {
    if (!mounted) return;

    if (_userId == null || _userId! <= 0) {
      print("Không thể tải giỏ hàng: User ID không hợp lệ hoặc chưa được tải.");
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    // Biến apiCartItems đã được khai báo trong try-catch nên không cần ở đây nữa
    // List<ApiCartItem> apiCartItems = [];

    try {
      Map<int, Map<String, dynamic>> latestVariantDetails = {};
      // Gọi getCart, service đã xử lý utf8
      List<ApiCartItem> apiCartItems = await _cartApiService.getCart(userId: _userId!);
      if (!mounted) return;

      print('Fetched initial cart items: ${apiCartItems.length} items');
      if (apiCartItems.isEmpty) {
        setState(() {
          _cartItems = [];
          _isLoading = false;
          _selectAll = false;
          _errorMessage = null;
        });
        print('Cart is empty or not found.');
        return;
      }


      final List<int> variantIds = apiCartItems
          .map((item) => item.variantId)
          .where((id) => id != 0)
          .toSet()
          .toList();

      bool priceFetchErrorOccurred = false;
      if (variantIds.isNotEmpty) {
        try {
          // Gọi getLatestVariantDetails, service đã xử lý utf8
          latestVariantDetails = await _cartApiService.getLatestVariantDetails(variantIds, userId: _userId!);
        } catch (e) {
          print("Error calling getLatestVariantPrices: $e");
          priceFetchErrorOccurred = true;
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lỗi khi cập nhật giá. Giá hiển thị có thể chưa chính xác.'),
                backgroundColor: Colors.orangeAccent,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }
      if (!mounted) return;

      setState(() {
        _cartItems = apiCartItems.map((apiItem) {
          final existingItem = _cartItems.firstWhere(
                (localItem) => localItem['cart_item_id'] == apiItem.cartItemId,
            orElse: () => {'isSelected': false},
          );
          final bool wasSelected = existingItem['isSelected'] ?? false;
          final Map<String, dynamic>? variantDetailData = latestVariantDetails[apiItem.variantId];
          final String? productNameFromDetail = variantDetailData?['product_name'] as String?;
          final String finalVariantName = (variantDetailData?['variant_name'] as String?) ?? apiItem.variantName;
          final String displayItemName = productNameFromDetail != null
              ? '$productNameFromDetail - $finalVariantName'
              : finalVariantName;
          final String? finalPriceString = variantDetailData?['final_price'] as String?;
          final String? basePriceString = variantDetailData?['base_price'] as String?;
          final double finalCurrentPrice = double.tryParse(finalPriceString ?? '') ?? apiItem.currentPrice;
          final double? basePrice = double.tryParse(basePriceString ?? '');
          double? discountAmount;
          if (basePrice != null && finalCurrentPrice < basePrice) {
            discountAmount = basePrice - finalCurrentPrice;
          }
          return {
            'cart_item_id': apiItem.cartItemId,
            'variant_id': apiItem.variantId,
            'name': displayItemName,
            'product_name': productNameFromDetail,
            'variant_name_only': finalVariantName,
            'image': _cartApiService.getFullImageUrl(apiItem.imageUrl),
            'currentPrice': finalCurrentPrice,
            'base_price': basePrice,
            'oldPrice': basePrice,
            'discountAmount': discountAmount,
            'tags': apiItem.tags,
            'quantity': apiItem.quantity,
            'isSelected': wasSelected,
            'extendedWarrantySelected': false,
          };
        }).toList();

        _updateSelectAllState();
        _isLoading = false;
        _errorMessage = null;
        if(priceFetchErrorOccurred && mounted) { /* SnackBar đã hiển thị */ }
      });

      if (widget.addedVariantId != null) {
        final addedItemExists = _cartItems.any((item) => item['variant_id'] == widget.addedVariantId);
        if (addedItemExists && mounted) { /* Có thể hiện SnackBar ở đây nếu cần */ }
      }

    } catch (e) {
      print("Critical Error in _fetchCartData: $e");
      if (!mounted) return;
      String errorMessageToShow;
      // Ưu tiên hiển thị thông báo lỗi đã được xử lý từ service
      if (e.toString().startsWith('Exception: ')) {
        errorMessageToShow = e.toString().substring('Exception: '.length);
      } else {
        errorMessageToShow = e.toString();
      }
      // Phân tích thêm nếu cần
      // if (e.toString().contains('Failed to fetch cart')) { ... }

      setState(() {
        _isLoading = false;
        _errorMessage = errorMessageToShow;
        _cartItems = [];
        _updateSelectAllState();
      });
    }
  }

  Future<void> _updateQuantity(int index, int newQuantity) async {
    if (newQuantity < 1) return;
    if (!mounted) return;
    if (_userId == null || _userId! <= 0) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi người dùng, không thể cập nhật.')));
      return;
    }

    final item = _cartItems[index];
    final int itemId = item['cart_item_id'] as int;
    final int oldQuantity = item['quantity'] as int;
    final String itemName = item['name'] as String? ?? 'Sản phẩm';

    setState(() {
      _cartItems[index]['quantity'] = newQuantity;
    });

    try {
      // Gọi updateCartItemQuantity, service đã xử lý utf8 cho lỗi
      await _cartApiService.updateCartItemQuantity(itemId, newQuantity, userId: _userId!);
      print('Successfully updated quantity for $itemName to $newQuantity');
    } catch (e) {
      print('Failed to update quantity via API for $itemName: $e');
      if (mounted) {
        setState(() {
          _cartItems[index]['quantity'] = oldQuantity;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteItem(int index) async {
    if (_userId == null || _userId! <= 0) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi người dùng, không thể xóa.')));
      return;
    }
    final item = _cartItems[index];
    final int itemId = item['cart_item_id'] as int;
    final String itemName = item['name'] as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa "$itemName" khỏi giỏ hàng?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Xóa')),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    setState(() {
      _cartItems.removeAt(index);
      _updateSelectAllState();
    });

    try {
      // Gọi deleteCartItem, service đã xử lý utf8 cho lỗi
      // Service sẽ ném Exception nếu không thành công
      await _cartApiService.deleteCartItem(itemId, userId: _userId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa "$itemName".')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa sản phẩm "$itemName": ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
      // Tải lại dữ liệu để đồng bộ trạng thái
      await _fetchCartData(showLoading: false);
    }
  }

  Future<void> _deleteSelectedItems() async {
    if (_userId == null || _userId! <= 0) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi người dùng, không thể xóa.')));
      return;
    }
    final selectedItems = _cartItems.where((item) => item['isSelected'] as bool? ?? false).toList();
    if (selectedItems.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa ${selectedItems.length} sản phẩm đã chọn?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    List<String> successfullyDeletedNames = [];
    List<String> failedDeletionsNames = [];
    bool hasErrors = false;

    for (var item in selectedItems) {
      int itemId = item['cart_item_id'] as int;
      String itemName = item['name'] as String;
      try {
        // Gọi deleteCartItem, service đã xử lý utf8 cho lỗi
        await _cartApiService.deleteCartItem(itemId, userId: _userId!);
        successfullyDeletedNames.add(itemName);
      } catch (e) {
        failedDeletionsNames.add(itemName);
        hasErrors = true;
        print("Lỗi khi xóa $itemName: $e");
      }
    }
    if (!mounted) return;

    if (hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa ${successfullyDeletedNames.length} SP. Lỗi khi xóa: ${failedDeletionsNames.join(', ')}.')),
      );
    } else if (successfullyDeletedNames.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa ${successfullyDeletedNames.length} sản phẩm đã chọn.')),
      );
    }
    // Luôn tải lại dữ liệu để đảm bảo đồng bộ
    await _fetchCartData(showLoading: false);
  }

  Future<void> _clearCart() async {
    if (_cartItems.isEmpty) return;
    if (_userId == null || _userId! <= 0) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi người dùng, không thể xóa.')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa toàn bộ'),
        content: const Text('Bạn có chắc muốn xóa toàn bộ giỏ hàng?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      // Gọi deleteCart, service đã xử lý utf8 cho lỗi
      await _cartApiService.deleteCart(userId: _userId!);
      setState(() {
        _cartItems.clear();
        _selectAll = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa toàn bộ giỏ hàng.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa giỏ hàng: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
      // Tải lại dữ liệu để đồng bộ
      await _fetchCartData(showLoading: false);
    }
  }

  void _updateSelectAllState() {
    if (!mounted) return;
    if (_cartItems.isEmpty) {
      _selectAll = false;
    } else {
      _selectAll = _cartItems.every((item) => item['isSelected'] as bool? ?? false);
    }
    // Không cần setState ở đây vì nó thường được gọi trong setState khác
  }

  void _proceedToCheckout() async {
    final selectedItems = _cartItems
        .where((item) => item['isSelected'] as bool? ?? false)
        .toList();

    if (selectedItems.isEmpty) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn ít nhất một sản phẩm để mua.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
      return;
    }

    if (_userId == null || _userId! <= 0) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thông tin người dùng không hợp lệ. Vui lòng thử lại.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // Gọi hàm _previewOrder để lấy thông tin xem trước
    // final previewData = await _previewOrder();
    // if (!mounted) return;

    // if (previewData != null) {
    //   Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //       builder: (context) => CheckoutInfoScreen(
    //         previewOrderData: previewData, // Truyền dữ liệu xem trước
    //         currentUserData: _currentUserData,
    //         userId: _userId!,
    //       ),
    //     ),
    //   );
    // } else {
    //   // _errorMessage đã được set trong _previewOrder nếu có lỗi
    //   if (_errorMessage != null && mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text(_errorMessage!),
    //         backgroundColor: Colors.redAccent,
    //       ),
    //     );
    //   }
    // }
    // Bỏ qua preview, điều hướng trực tiếp
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutInfoScreen(
            currentUserData: _currentUserData,
            userId: _userId!,
          ),
        ),
      );
    }
  }

  void _toggleSelectAll(bool? value) {
    if (!mounted) return;
    setState(() {
      _selectAll = value ?? false;
      for (var item in _cartItems) {
        item['isSelected'] = _selectAll;
      }
    });
  }

  void _toggleItemSelection(int index, bool? value) {
    if (!mounted) return;
    setState(() {
      _cartItems[index]['isSelected'] = value ?? false;
      _updateSelectAllState();
    });
  }

  void _navigateToCatalog(int categoryId, String categoryName) {
    print('Cart: Navigating to category: $categoryName (ID: $categoryId)');
    // Ví dụ: Navigator.push(context, MaterialPageRoute(builder: (context) => CatalogScreen(categoryId: categoryId, categoryName: categoryName)));
  }

  void _onAccountPressed() {
    print('Cart: Account pressed');
    // Ví dụ: Navigator.push(context, MaterialPageRoute(builder: (context) => AccountScreen()));
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: AppColors.themePageBackground,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kIsWeb ? (screenWidth > 900 ? 60 : 50) : 45 + MediaQuery.of(context).padding.top),
        child:
        CustomHeader(
          categories: _categories,
          currentUserData: _currentUserData, // Đã truyền
          onCartPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
          },
          onAccountPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AccountPage()),
            );
          },
          onCategorySelected: (Map<String, dynamic> selectedCategory) {
            print('Selected category from menu: ${selectedCategory['name']}');
            final categoryId = selectedCategory['category_id'] as int?;
            if (categoryId != null) {
              // TODO: Scroll to category section
            }
          },
          onLogoTap: () {
            // TODO: Navigate to Home
          },
          onSearchSubmitted: (value) {
            print("Search submitted: $value");
            // TODO: Handle search
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (_userId == null || _userId! <= 0) {
                  await _loadUserDataAndInitialize();
                } else {
                  await _fetchCartData(showLoading: false);
                }
              },
              child: _buildBodyContent(isDesktop),
            ),
          ),
          if (!_isLoadingUserData && (_userId != null && _userId! > 0) && !_isLoading && _errorMessage == null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? (screenWidth - 900) / 2 : 0, vertical: 0)
                  .copyWith(bottom: MediaQuery.of(context).padding.bottom > 0 ? 0 : 8),
              child: _buildCheckoutSummary(),
            ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(bool isDesktop) {
    if (_isLoadingUserData) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Đang tải thông tin người dùng...", style: TextStyle(fontSize: 16)),
        ],
      ));
    }

    // Lỗi tải người dùng được ưu tiên hiển thị
    if ((_userId == null || _userId! <= 0) && _errorMessage != null && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined, color: Colors.red, size: 60),
              const SizedBox(height: 15),
              Text(
                _errorMessage!, // Lỗi này từ _loadUserDataAndInitialize
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 16, color: AppColors.textGrey),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: _loadUserDataAndInitialize,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: Colors.white),
                child: Text("Thử lại", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      );
    }

    // Sau đó là trạng thái tải giỏ hàng
    if (_isLoading) { // _isLoading này là của giỏ hàng
      return const Center(child: CircularProgressIndicator());
    }

    // Lỗi tải giỏ hàng
    if (_errorMessage != null) { // _errorMessage này là của giỏ hàng
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 15),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 16, color: AppColors.textGrey),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () => _fetchCartData(), // Thử tải lại giỏ hàng
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: Colors.white),
                child: Text("Thử lại", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      );
    }

    if (_cartItems.isEmpty) {
      return _buildEmptyCart();
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Container(
          width: isDesktop ? 900 : double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 0 : 16.0,
            vertical: 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textBlack),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      "Giỏ hàng của bạn",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textBlack,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Để cân bằng với IconButton
                ],
              ),
              const SizedBox(height: 16),
              _buildCartActionsHeader(),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cartItems.length,
                itemBuilder: (context, index) {
                  return _buildCartItemCard(_cartItems[index], index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartActionsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ElevatedButton(
                onPressed: null, // Chỉ là label
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text("Giỏ hàng", style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: _cartItems.isEmpty ? null : () => _toggleSelectAll(!_selectAll),
                child: Row(
                  children: [
                    Icon(
                      _selectAll ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _cartItems.isEmpty ? AppColors.textLightGrey : AppColors.primaryRed,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectAll ? "Bỏ chọn tất cả" : "Chọn tất cả",
                      style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textBlack),
                    ),
                    Text(
                      _cartItems.isNotEmpty ? ' (${_cartItems.length})' : '',
                      style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: _selectedItemCount > 0 ? _deleteSelectedItems : null,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  "Xóa đã chọn ($_selectedItemCount)",
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: _selectedItemCount > 0 ? Colors.red : AppColors.textLightGrey.withOpacity(0.5),
                    fontWeight: _selectedItemCount > 0 ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: _cartItems.isNotEmpty ? _clearCart : null,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  "Xóa toàn bộ",
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: _cartItems.isNotEmpty ? Colors.red : AppColors.textLightGrey.withOpacity(0.5),
                    fontWeight: _cartItems.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(Map<String, dynamic> item, int index) {
    final int quantity = item['quantity'] as int? ?? 1;
    final double currentPrice = item['currentPrice'] as double? ?? 0.0;
    final double? basePrice = item['base_price'] as double?;
    final bool isSelected = item['isSelected'] as bool? ?? false;
    final String imageUrl = item['image'] as String? ?? 'assets/images/placeholder.png';
    final String displayItemName = item['name'] as String? ?? 'Sản phẩm không xác định';

    final bool showBasePrice = basePrice != null && basePrice != currentPrice;
    final bool hasDiscount = showBasePrice && currentPrice < basePrice;


    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (bool? value) {
                _toggleItemSelection(index, value ?? false);
              },
              activeColor: AppColors.primaryRed,
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset( // Giữ nguyên Image.asset theo yêu cầu
                imageUrl,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Image asset load error for $imageUrl: $error');
                  return Image.asset(
                    'assets/images/placeholder.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayItemName,
                    style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textBlack),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatCurrency(currentPrice),
                    style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                  ),
                  if (showBasePrice) ...[
                    const SizedBox(height: 2),
                    Text(
                      formatCurrency(basePrice),
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: AppColors.textGrey,
                        decoration: hasDiscount ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQuantityControlButton(
                        icon: Icons.remove,
                        onPressed: quantity > 1 ? () => _updateQuantity(index, quantity - 1) : null,
                      ),
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          '$quantity',
                          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      _buildQuantityControlButton(
                        icon: Icons.add,
                        onPressed: () => _updateQuantity(index, quantity + 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.textGrey.withOpacity(0.8)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Xóa sản phẩm',
              onPressed: () => _deleteItem(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControlButton({required IconData icon, VoidCallback? onPressed}) {
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: onPressed != null ? AppColors.borderGrey : AppColors.borderGrey.withOpacity(0.5)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onPressed != null ? AppColors.textBlack : AppColors.textLightGrey.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/empty_cart.png', height: 120, errorBuilder: (c, e, s) => Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.textLightGrey.withOpacity(0.5))),
            const SizedBox(height: 20),
            Text(
              "Giỏ hàng của bạn còn trống",
              style: GoogleFonts.montserrat(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textGrey),
            ),
            const SizedBox(height: 8),
            Text(
              "Thêm sản phẩm vào giỏ để tiến hành mua sắm nhé.",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textLightGrey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text("Tiếp tục mua sắm", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutSummary() {
    bool hasValidPrices = _cartItems.any((item) => (item['isSelected'] as bool? ?? false) && (item['currentPrice'] as double? ?? 0.0) > 0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedItemCount > 0)
                  RichText(
                    text: TextSpan(
                      text: 'Tổng cộng (${_selectedItemCount} SP): ',
                      style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textGrey),
                      children: <TextSpan>[
                        TextSpan(
                          text: formatCurrency(_subtotal),
                          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    "Chọn sản phẩm để xem tổng tiền",
                    style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.textGrey),
                  ),
                if (_selectedItemCount > 0) ...[
                  const SizedBox(height: 2),
                  if (_totalDiscount > 0)
                    Text(
                      "Tiết kiệm ${formatCurrency(_totalDiscount)}",
                      style: GoogleFonts.montserrat(fontSize: 12, color: Colors.green.shade700),
                    ),
                  if (!hasValidPrices && _selectedItemCount > 0)
                    Text(
                      "(Giá tạm tính, vui lòng xác nhận)",
                      style: GoogleFonts.montserrat(fontSize: 11, color: Colors.orange.shade700),
                    ),
                ]
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _selectedItemCount > 0 ? _proceedToCheckout : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              disabledBackgroundColor: AppColors.primaryRed.withOpacity(0.5),
              disabledForegroundColor: Colors.white.withOpacity(0.8),
              minimumSize: const Size(120, 45),
            ),
            child: const Text("Mua ngay"),
          ),
        ],
      ),
    );
  }
}