import 'dart:async'; // Cần cho Timer
import 'dart:convert'; // Cần cho jsonDecode
import 'package:cross_platform_mobile_app_development/screens/product_detail.dart';
import 'package:cross_platform_mobile_app_development/screens/profile_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';

import '../models/product_model.dart';
import '../services/api_service.dart'; // *** THAY ĐỔI: Import ApiService
import '../widgets/footer.dart';
import '../widgets/header.dart';
import 'cart_product.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const Color themeBluePrimary = Color(0xFF007BFF);
  static const Color themeBlueDark = Color(0xFF0056b3);
  // static const Color themeBlueLight = Color(0xFFE0EFFF); // Not used in current setup

  // General Text and UI Element Colors
  static const Color cpsTextBlack = Color(0xFF222222);
  static const Color cpsTextGrey = Color(0xFF4A4A4A);
  static const Color cpsSubtleTextGrey = Color(0xFF757575);
  static const Color cpsCardBorderColor = Color(0xFFE0E0E0);
  static const Color cpsStarYellow = Color(0xFFFFC107);

  // Colors based on the CellphoneS image theme (for body content)
  static const Color imageRedAccent = Color(0xFF007BFF); // CellphoneS Red
  static const Color imageLightRedBackground = Color(
      0xFFFDEBEE); // Light pinkish red for selected items/icon backgrounds
  static const Color imagePageBackground =
      Color(0xFFF5F5F5); // Light grey for sidebar, etc.
  static const Color imageUpdateBannerBlue =
      Color(0xFFEBF4FF); // Light blue for info banners

  // Tag colors from one of the user info versions (can be customized)
  static const Color imageSnullBgColor = Color(0xFFFCE4EC);
  static const Color imageSnullTextBorderColor = Color(0xFF1E88E5);
  static const Color imageSstudentBgColor = Color(0xFFE3F2FD);
  static const Color imageSstudentTextBorderColor = Color(0xFF1E88E5);

  static const Color themePageBackground = Color(0xFFF0F2F5);
  static const Color themeBlueLight = Color(0xFFE0EFFF);

  static const Color cpsInstallmentBlue = Color(0xFF007AFF);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, String>> _highlightTabsData = [
    {'title': 'IPHONE 16 PRO MAX', 'subtitle': 'Lên đời ngay'},
    {'title': 'GALAXY S25 ULTRA', 'subtitle': 'Giá tốt chốt ngay'},
    {'title': 'OPPO FIND N5', 'subtitle': 'Ưu đãi tốt mua ngay'},
    {'title': 'ĐỊNH GIÁ CÓ QUÀ', 'subtitle': 'Lên đời có deal'},
    {'title': 'MACBOOK AIR M4', 'subtitle': 'Lên đời nhận AirPods4'},
    // Thêm các tab khác...
  ];

  int _currentBannerPage = 0;
  late PageController _bannerPageController;
  Timer? _bannerTimer;

  // *** THAY ĐỔI: Biến cho dữ liệu từ API ***
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _categories =
      []; // Dùng để render UI, chứa category_id, name, sub_categories (là brand names)
  Map<int, List<Product>> _productsByCategory =
      {}; // category_id -> List<Product>
  Map<int, String> _selectedSubCategory =
      {}; // category_id -> selected brand name (hoặc "Tất cả")

  // Biến quản lý phân trang cho từng category
  Map<int, int> _currentSkipByCategory = {};
  Map<int, bool> _hasMoreProducts = {};
  Map<int, bool> _isLoadingMoreProducts = {};
  List<Product> _discountedProducts = [];
  List<Product> _newestProducts = [];
  List<Product> _bestSellerProducts = [];
  // ID ảo cho category "Sản phẩm giảm giá"
  static const int DISCOUNTED_PRODUCTS_CATEGORY_ID = -1;
  // --- Hết Biến cho dữ liệu từ API ---

  // Biến quản lý cuộn ngang
  final Map<int, ScrollController> _scrollControllers = {};
  final Map<int, VoidCallback> _scrollListeners = {};
  final Map<int, ValueNotifier<bool>> _canScrollForwardNotifiers = {};
  final Map<int, ValueNotifier<bool>> _canScrollBackwardNotifiers = {};
  // --- Hết Biến quản lý cuộn ngang ---

  // Kích thước card sản phẩm
  static Map<int, List<Product>>? _cachedProductsByCategory;
  static const double _productCardWidth = kIsWeb ? 200.0 : 170.0;
  static const double _productCardHeight = kIsWeb ? 400.0 : 370.0;
  static const double _cardHorizontalMargin = 6.0;
  final double _itemWidth = _productCardWidth + (_cardHorizontalMargin * 2);
  // --- Hết Kích thước card sản phẩm ---

  // Trạng thái chung
  bool _isLoading = true;
  bool _isLoadingNewest = false;
  bool _isLoadingBestSellers = false;
  bool _isLoadingPromotional = true;
  String? _errorMessage;
  String? _backendUserId;
  Map<String, dynamic>? _currentUserData;
  // --- Hết Trạng thái chung ---

  // Scroll chính và nút scroll to top
  final ScrollController _mainScrollController = ScrollController();
  bool _showScrollToTopButton = false;

  // *** THÊM: Biến cho số lượng giỏ hàng ***

  @override
  void initState() {
    super.initState();
    _bannerPageController =
        PageController(initialPage: 0, viewportFraction: 1.0);
    _startBannerTimer();
    _loadInitialDataAndUserInfo();
    _mainScrollController.addListener(() {
      if (mounted) {
        setState(() {
          _showScrollToTopButton = _mainScrollController.offset >= 300;
        });
      }
    });
    // TODO: Fetch initial cart item count if user is logged in
    // _fetchCartItemCount();
  }

  // *** THÊM CÁC HÀM XỬ LÝ CHO HEADER CALLBACKS ***
  void _navigateToCart() {
    print("HomeScreen: Cart icon pressed. Navigating to CartScreen...");
    // TODO: Thay thế bằng CartScreen thực tế của bạn
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (context) => const CartScreen()), // Giả sử CartScreen đã được import
    // ).then((_) {
    //   // Có thể cập nhật lại _cartItemCount nếu cần sau khi quay lại từ CartScreen
    //   // _fetchCartItemCount();
    // });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              "Chức năng Giỏ hàng (CartScreen) chưa được triển khai đầy đủ.")),
    );
  }

  void _navigateToAccountOrLogin() {
    if (_currentUserData != null) {
      print(
          "HomeScreen: Account icon pressed. Navigating to Account/Profile Screen for user: ${_currentUserData!['full_name']}");
      // TODO: Thay thế bằng ProfileScreen thực tế của bạn
      // Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userData: _currentUserData!)));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Đến trang tài khoản của: ${_currentUserData!['full_name']}. (Chưa triển khai)")),
      );
    } else {
      print("HomeScreen: Account icon pressed. Navigating to Login Screen...");
      // TODO: Thay thế bằng LoginScreen thực tế của bạn
      // Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()))
      //   .then((loggedInUserData) {
      //     if (loggedInUserData != null && loggedInUserData is Map<String, dynamic>) {
      //       // Xử lý sau khi đăng nhập thành công, ví dụ cập nhật UI, SharedPreferences
      //       _handleLoginSuccess(loggedInUserData);
      //       // Tải lại thông tin giỏ hàng
      //       // _fetchCartItemCount();
      //     }
      //   });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Chức năng Đăng nhập/Đăng ký (LoginScreen) chưa được triển khai đầy đủ.")),
      );
    }
  }

  void _handleCategorySelectionFromHeader(
      Map<String, dynamic> selectedCategory) {
    final categoryId = selectedCategory['category_id'] as int?;
    final categoryName = selectedCategory['name'] as String?;
    print(
        'HomeScreen: Header category selected: $categoryName, ID: $categoryId');
    if (categoryId != null) {
      // TODO: Triển khai logic scroll đến category section tương ứng trên trang.
      // Việc này có thể phức tạp, cần GlobalKey cho mỗi section hoặc tính toán offset.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Đã chọn danh mục: $categoryName. Chức năng scroll đến section chưa triển khai.")),
      );
    }
  }

  void _handleLogoTap() {
    print("HomeScreen: Logo tapped.");
    if (_mainScrollController.hasClients && _mainScrollController.offset > 0) {
      _scrollToTop(); // Cuộn lên đầu trang nếu đang không ở đầu
    } else {
      // Nếu đã ở đầu trang, có thể refresh dữ liệu
      print("Đã ở đầu trang. Cân nhắc refresh dữ liệu.");
      _loadInitialDataAndUserInfo(); // Refresh lại dữ liệu
    }
  }

  void _handleSearchSubmitted(String query) {
    print("HomeScreen: Search submitted from header: '$query'");
    if (query.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập từ khóa tìm kiếm.")),
      );
      return;
    }
    // TODO: Triển khai logic tìm kiếm
    // Ví dụ: điều hướng đến trang kết quả tìm kiếm hoặc lọc danh sách sản phẩm hiện tại
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => SearchResultsScreen(searchQuery: query), // Giả sử SearchResultsScreen đã import
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              "Đang tìm kiếm cho: '$query'. Chức năng tìm kiếm chưa triển khai đầy đủ.")),
    );
  }

  Widget _buildSpecialSection({
    required ThemeData theme,
    required String title,
    required List<Product> products,
    required bool isLoading,
    required IconData icon,
    Color? headerColor,
    Color? iconColor,
  }) {
    final categoryId = title.hashCode; // Tạo ID duy nhất cho section
    final ScrollController? scrollController = _scrollControllers[categoryId];
    final ValueNotifier<bool>? canScrollForwardNotifier =
        _canScrollForwardNotifiers[categoryId];
    final ValueNotifier<bool>? canScrollBackwardNotifier =
        _canScrollBackwardNotifiers[categoryId];

    // Khởi tạo ScrollController nếu chưa có
    if (!_scrollControllers.containsKey(categoryId)) {
      final controller = ScrollController();
      _scrollControllers[categoryId] = controller;
      _canScrollForwardNotifiers[categoryId] = ValueNotifier(false);
      _canScrollBackwardNotifiers[categoryId] = ValueNotifier(false);

      final listener = () {
        _updateScrollState(categoryId);
      };
      _scrollListeners[categoryId] = listener;
      controller.addListener(listener);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateScrollState(categoryId);
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
                left: kIsWeb ? 4 : 2, right: kIsWeb ? 4 : 2, bottom: 10.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor ?? HomeScreen.themeBluePrimary,
                  size: kIsWeb ? 20 : 18,
                ),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: kIsWeb ? 17 : 15,
                    color: headerColor ?? HomeScreen.cpsTextBlack,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.12),
                  spreadRadius: 0.5,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
                vertical: kIsWeb ? 14 : 10, horizontal: kIsWeb ? 6 : 2),
            child: isLoading
                ? SizedBox(
                    height: _productCardHeight + (kIsWeb ? 10 : 6),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: HomeScreen.themeBluePrimary,
                      ),
                    ),
                  )
                : products.isEmpty
                    ? _buildEmptyCategoryPlaceholder(theme)
                    : SizedBox(
                        height: _productCardHeight + (kIsWeb ? 10 : 6),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ListView.builder(
                              controller: scrollController,
                              scrollDirection: Axis.horizontal,
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                return _buildProductCard(
                                  theme: theme,
                                  product: products[index],
                                  cardMargin: _cardHorizontalMargin,
                                );
                              },
                            ),
                            _buildNavigationArrow(
                              theme: theme,
                              categoryId: categoryId,
                              isForward: false,
                              canScrollNotifier: canScrollBackwardNotifier,
                              hasMoreApi: false,
                              isLoading: false,
                              horizontalOffset: kIsWeb ? -8 : -4,
                              productCount: products.length,
                            ),
                            _buildNavigationArrow(
                              theme: theme,
                              categoryId: categoryId,
                              isForward: true,
                              canScrollNotifier: canScrollForwardNotifier,
                              hasMoreApi: false,
                              isLoading: false,
                              horizontalOffset: kIsWeb ? -8 : -4,
                              productCount: products.length,
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadInitialDataAndUserInfo() async {
    if (!mounted) return;

    if (_cachedProductsByCategory != null &&
        _cachedProductsByCategory!.isNotEmpty) {
      setState(() {
        _productsByCategory = Map.from(_cachedProductsByCategory!);
        _isLoading = false;
        _isLoadingNewest = false;
        _isLoadingBestSellers = false;
        _isLoadingPromotional = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateScrollStatesForAllCategories();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isLoadingNewest = true;
      _isLoadingBestSellers = true;
      _isLoadingPromotional = true;
      _errorMessage = null;
      _categories.clear();
      _productsByCategory.clear();
      _discountedProducts.clear();
      _newestProducts.clear();
      _bestSellerProducts.clear();
      _selectedSubCategory.clear();
      _currentSkipByCategory.clear();
      _hasMoreProducts.clear();
      _isLoadingMoreProducts.clear();
    });

    // Bước 1: Tải thông tin người dùng từ SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? loadedBackendUserId = prefs.getString('user_uid');
    final String? loadedFullName = prefs.getString('user_fullName');

    if (mounted) {
      if (loadedBackendUserId != null && loadedFullName != null) {
        setState(() {
          _backendUserId = loadedBackendUserId;
          _currentUserData = {
            'user_id': loadedBackendUserId,
            'full_name': loadedFullName,
          };
          print(
              "HomeScreen: User data loaded from SharedPreferences: $_currentUserData");
        });
      } else {
        setState(() {
          _backendUserId = null;
          _currentUserData = null;
          print("HomeScreen: No user data in SharedPreferences.");
        });
      }
    }

    // Bước 2: Tải dữ liệu sản phẩm và danh mục
    try {
      // Tải sản phẩm mới nhất
      List<Product> newestProducts =
          await _apiService.fetchNewestProducts(limit: 10);
      if (mounted) {
        setState(() {
          _newestProducts = newestProducts;
          _isLoadingNewest = false;
        });
      }

      // Tải sản phẩm bán chạy
      List<Product> bestSellerProducts =
          await _apiService.fetchBestSellingProducts(limit: 10);
      if (mounted) {
        setState(() {
          _bestSellerProducts = bestSellerProducts;
          _isLoadingBestSellers = false;
        });
      }

      // Tải sản phẩm giảm giá
      List<Product> promotionalProducts =
          await _apiService.fetchPromotionalProducts(limit: 10);
      if (mounted) {
        setState(() {
          _discountedProducts = promotionalProducts;
          _isLoadingPromotional = false;
        });
      }

      // Tải danh sách sản phẩm và danh mục
      List<Product> initialProducts =
          await _apiService.fetchProducts(limit: 100, skip: 0);

      if (!mounted) return;
      if (initialProducts.isEmpty &&
          _discountedProducts.isEmpty &&
          _newestProducts.isEmpty &&
          _bestSellerProducts.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Không có sản phẩm nào.";
        });
        return;
      }

      final Map<int, Category> uniqueApiCategories = {};
      final Map<int, Set<String>> uniqueBrandsPerCategory = {};

      for (var product in initialProducts) {
        if (product.category != null) {
          if (!uniqueApiCategories.containsKey(product.category!.categoryId)) {
            uniqueApiCategories[product.category!.categoryId] =
                product.category!;
          }
          if (product.brand != null) {
            uniqueBrandsPerCategory.putIfAbsent(
                product.category!.categoryId, () => <String>{});
            uniqueBrandsPerCategory[product.category!.categoryId]!
                .add(product.brand!.name ?? "Không rõ");
          } else {
            uniqueBrandsPerCategory.putIfAbsent(
                product.category!.categoryId, () => <String>{});
            uniqueBrandsPerCategory[product.category!.categoryId]!
                .add("Không rõ");
          }
        }

        if (product.category != null) {
          _productsByCategory.putIfAbsent(
              product.category!.categoryId, () => []);
          _productsByCategory[product.category!.categoryId]!.add(product);
        }
      }

      var sortedCategoryEntries = uniqueApiCategories.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      List<Map<String, dynamic>> uiCategories = [];

      for (var entry in sortedCategoryEntries) {
        final categoryId = entry.key;
        final categoryObject = entry.value;
        final brandsForThisCategory =
            uniqueBrandsPerCategory[categoryId]?.toList() ?? [];
        brandsForThisCategory.sort();

        List<String> subCategoryNames = ["Tất cả", ...brandsForThisCategory];

        uiCategories.add({
          'category_id': categoryId,
          'name': categoryObject.name,
          'sub_categories': subCategoryNames,
        });
        _selectedSubCategory[categoryId] = "Tất cả";
        _currentSkipByCategory[categoryId] =
            _productsByCategory[categoryId]?.length ?? 0;
        _isLoadingMoreProducts[categoryId] = false;
        _hasMoreProducts[categoryId] = true;
      }

      if (mounted) {
        setState(() {
          _categories = uiCategories;
          _isLoading = false;
          _cachedProductsByCategory = Map.from(_productsByCategory);
        });
      }

      _initializeScrollControllers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingNewest = false;
        _isLoadingBestSellers = false;
        _isLoadingPromotional = false;
        _errorMessage = "Lỗi tải dữ liệu: ${e.toString()}";
      });
      print("Error loading data: $e");
    } finally {
      if (mounted && _categories.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateScrollStatesForAllCategories();
        });
      }
    }
  }

  final List<Map<String, dynamic>> _slidingBannersData = [
    {
      'id': 'iphone16',
      'assetImagePath': 'assets/images/banner_iphone16_titan_bg.png',
      'productImageUrl': 'assets/images/iphone_16_pro_max_product.png',
      'brandLogoUrl': 'assets/images/apple_logo_black.png',
      'brandText': 'iPhone 16 Pro Max',
      'mainTitleLine1': 'Thiết kế Titan',
      'mainTitleLine2': 'tuyệt đẹp.',
      'promos': [
        {
          'title': 'Trợ giá lên đời',
          'value': 'Đến 3 Triệu',
          'valueColor': Colors.redAccent
        },
        {
          'title': 'Khách hàng mới',
          'value': 'Giảm 300K',
          'valueColor': Colors.redAccent
        },
        {
          'title': 'Góp 12 Tháng từ',
          'value': '76K/Ngày',
          'valueColor': Colors.black87
        },
      ],
      'actionText': 'Mua ngay',
      'gradientColors': [
        const Color(0xFFE0F2FF).withOpacity(0.8),
        const Color(0xFFF8E2FF).withOpacity(0.8)
      ],
      'mainTitleColor': const Color(0xFF0071E3),
      'promoTitleColor': Colors.grey.shade700,
      'actionButtonBackgroundColor': Colors.white,
      'actionButtonTextColor': const Color(0xFF333333),
      'actionButtonBorderColor': Colors.grey.shade400,
      'onTap': () {
        print("iPhone 16 Banner tapped"); /* Xử lý điều hướng */
      },
    },
    {
      'id': 's25ultra',
      'assetImagePath': 'assets/images/banner_s25_ultra_bg.png',
      'productImageUrl': 'assets/images/samsung_s25_ultra_product.png',
      'brandText': 'Galaxy S25 Ultra',
      'mainTitleLine1': 'Galaxy AI Mới',
      'mainTitleLine2': 'Trải nghiệm đỉnh cao.',
      'promos': [
        {
          'title': 'Đặt trước nhận quà',
          'value': 'Bộ quà 5 Triệu',
          'valueColor': Colors.deepPurpleAccent
        },
        {
          'title': 'Thu cũ đổi mới',
          'value': 'Trợ giá 2 Triệu',
          'valueColor': Colors.deepPurpleAccent
        },
      ],
      'actionText': 'XEM NGAY',
      'gradientColors': [const Color(0xFFEDE7F6), const Color(0xFFD1C4E9)],
      'mainTitleColor': Colors.deepPurple.shade700,
      'promoTitleColor': Colors.grey.shade700,
      'actionButtonBackgroundColor': Colors.deepPurple.shade600,
      'actionButtonTextColor': Colors.white,
      'onTap': () {
        print("Galaxy S25 Ultra Banner tapped");
      },
    },
    {
      'id': 'oppofindn5',
      'assetImagePath': 'assets/images/banner_oppo_find_n5_bg.png',
      'productImageUrl': 'assets/images/oppo_find_n5_product.png',
      'brandText': 'OPPO Find N5',
      'mainTitleLine1': 'Mở Ra Kỷ Nguyên Mới',
      'mainTitleLine2': 'Gập Mở Không Giới Hạn.',
      'promos': [
        {
          'title': 'Ưu đãi đặc biệt',
          'value': 'Giảm ngay 2 Triệu',
          'valueColor': Colors.green.shade700
        },
        {
          'title': 'Tặng kèm tai nghe',
          'value': 'Enco Buds2 Pro',
          'valueColor': Colors.green.shade700
        },
      ],
      'actionText': 'KHÁM PHÁ',
      'gradientColors': [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
      'mainTitleColor': Colors.green.shade800,
      'promoTitleColor': Colors.grey.shade700,
      'actionButtonBackgroundColor': Colors.green.shade700,
      'actionButtonTextColor': Colors.white,
      'onTap': () {
        print("OPPO Find N5 Banner tapped");
      },
    },
    {
      'id': 'placeholder1',
      'assetImagePath':
          'https://via.placeholder.com/800x400/CCCCCC/FFFFFF?text=Macbook+Air+M4',
      'productImageUrl': '',
      'brandText': 'Macbook Air M4',
      'mainTitleLine1': 'Sắp ra mắt',
      'mainTitleLine2': '',
      'promos': [],
      'actionText': 'Tìm hiểu thêm',
      'gradientColors': [Colors.grey.shade200, Colors.grey.shade300],
      'mainTitleColor': Colors.black54
    },
    {
      'id': 'placeholder2',
      'assetImagePath':
          'https://via.placeholder.com/800x400/DDDDDD/FFFFFF?text=Vivo+V50+Lite',
      'productImageUrl': '',
      'brandText': 'Vivo V50 Lite',
      'mainTitleLine1': 'Coming Soon',
      'mainTitleLine2': '',
      'promos': [],
      'actionText': 'Tìm hiểu thêm',
      'gradientColors': [Colors.blueGrey.shade100, Colors.blueGrey.shade200],
      'mainTitleColor': Colors.black54
    },
  ];

  void _startBannerTimer() {
    if (_slidingBannersData.length > 1) {
      _bannerTimer?.cancel();
      _bannerTimer = Timer.periodic(const Duration(seconds: 6), (Timer timer) {
        if (!_bannerPageController.hasClients || _slidingBannersData.isEmpty)
          return;
        int currentPage = _bannerPageController.page!.round();
        int nextPage = (currentPage + 1) % _slidingBannersData.length;
        if (mounted && _bannerPageController.hasClients) {
          _bannerPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    _scrollControllers.forEach((_, controller) => controller.dispose());
    _scrollListeners.forEach((_, listener) {});
    _canScrollForwardNotifiers.forEach((_, notifier) => notifier.dispose());
    _canScrollBackwardNotifiers.forEach((_, notifier) => notifier.dispose());
    _bannerTimer?.cancel();
    _bannerPageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _productsByCategory.clear();
      _categories.clear();
      _selectedSubCategory.clear();
      _currentSkipByCategory.clear();
      _hasMoreProducts.clear();
      _isLoadingMoreProducts.clear();
      _discountedProducts.clear();
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id'); // Giả sử bạn lưu user_id
    String? fullName = prefs.getString('user_full_name');
    String? email = prefs.getString('user_email');
    String? avatarUrl = prefs.getString('user_avatar_url'); // Nếu có

    if (userId != null && fullName != null) {
      if (mounted) {
        setState(() {
          _currentUserData = {
            'user_id': userId, // hoặc 'id' tùy theo key bạn dùng
            'full_name': fullName,
            'email': email,
            'avatar_url': avatarUrl // Sẽ dùng cho avatar
          };
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _currentUserData = null; // Chưa đăng nhập
        });
      }
    }

    try {
      List<Product> initialProducts =
          await _apiService.fetchProducts(limit: 100, skip: 0);

      if (!mounted) return;
      if (initialProducts.isEmpty) {
        /* ... */
        return;
      }

      final Map<int, Category> uniqueApiCategories = {};
      final Map<int, Set<String>> uniqueBrandsPerCategory = {};
      _discountedProducts.clear();

      for (var product in initialProducts) {
        if (product.category != null) {
          if (!uniqueApiCategories.containsKey(product.category!.categoryId)) {
            uniqueApiCategories[product.category!.categoryId] =
                product.category!;
          }
          if (product.brand != null) {
            uniqueBrandsPerCategory.putIfAbsent(
                product.category!.categoryId, () => <String>{});
            uniqueBrandsPerCategory[product.category!.categoryId]!
                .add(product.brand!.name ?? "Không rõ");
          } else {
            uniqueBrandsPerCategory.putIfAbsent(
                product.category!.categoryId, () => <String>{});
            uniqueBrandsPerCategory[product.category!.categoryId]!
                .add("Không rõ");
          }
        }

        if (product.category != null) {
          _productsByCategory.putIfAbsent(
              product.category!.categoryId, () => []);
          _productsByCategory[product.category!.categoryId]!
              .add(product); // *** SỬA: Thay 'CertesId' thành 'categoryId'
        }

        if (product.isOnSale) {
          _discountedProducts.add(product);
        }
      }

      var sortedCategoryEntries = uniqueApiCategories.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      List<Map<String, dynamic>> uiCategories = [];

      if (_discountedProducts.isNotEmpty) {
        Set<String> brandsInDiscounted = <String>{};
        for (var p in _discountedProducts) {
          if (p.brand != null) {
            brandsInDiscounted.add(p.brand!.name ?? "Không rõ");
          }
        }
        List<String> discountedSubCategories = [
          "Tất cả",
          ...brandsInDiscounted.toList()..sort()
        ];

        uiCategories.add({
          'category_id': DISCOUNTED_PRODUCTS_CATEGORY_ID,
          'name': 'Sản Phẩm Giảm Giá 🔥',
          'sub_categories': discountedSubCategories,
        });
        _selectedSubCategory[DISCOUNTED_PRODUCTS_CATEGORY_ID] = "Tất cả";
        _currentSkipByCategory[DISCOUNTED_PRODUCTS_CATEGORY_ID] =
            _discountedProducts.length;
        _isLoadingMoreProducts[DISCOUNTED_PRODUCTS_CATEGORY_ID] = false;
        _hasMoreProducts[DISCOUNTED_PRODUCTS_CATEGORY_ID] = false;
      }

      for (var entry in sortedCategoryEntries) {
        final categoryId = entry.key;
        final categoryObject = entry.value;
        final brandsForThisCategory =
            uniqueBrandsPerCategory[categoryId]?.toList() ?? [];
        brandsForThisCategory.sort();

        List<String> subCategoryNames = ["Tất cả", ...brandsForThisCategory];

        uiCategories.add({
          'category_id': categoryId,
          'name': categoryObject.name,
          'sub_categories': subCategoryNames,
        });
        _selectedSubCategory[categoryId] = "Tất cả";
        _currentSkipByCategory[categoryId] =
            _productsByCategory[categoryId]?.length ?? 0;
        _isLoadingMoreProducts[categoryId] = false;
        _hasMoreProducts[categoryId] = true;
      }

      setState(() {
        _categories = uiCategories;
      });

      _initializeScrollControllers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Lỗi tải dữ liệu: ${e.toString()}";
      });
      print("Error loading initial data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (_categories.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateScrollStatesForAllCategories();
          });
        }
      }
    }
  }

  Future<void> _fetchProductsForCategory(int categoryId) async {
    if (categoryId == DISCOUNTED_PRODUCTS_CATEGORY_ID) {
      if (mounted) {
        setState(() {
          _isLoadingMoreProducts[categoryId] = false;
          _hasMoreProducts[categoryId] = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollControllers[categoryId]?.hasClients ?? false) {
            _updateScrollState(categoryId);
          }
        });
      }
      return;
    }
    if (_isLoadingMoreProducts[categoryId] ?? false) return;
    if (!(_hasMoreProducts[categoryId] ?? true)) return;

    if (mounted) {
      setState(() {
        _isLoadingMoreProducts[categoryId] = true;
      });
    }

    try {
      final int currentSkip = _productsByCategory[categoryId]?.length ?? 0;
      final List<Product> fetchedProducts = await _apiService
          .fetchProducts(
            categoryId: categoryId,
            skip: currentSkip,
            limit: 10,
          )
          .timeout(const Duration(seconds: 10), onTimeout: () => []);

      if (!mounted) return;

      setState(() {
        if (fetchedProducts.isNotEmpty) {
          _productsByCategory.putIfAbsent(categoryId, () => []);
          _productsByCategory[categoryId]!.addAll(fetchedProducts);
          _currentSkipByCategory[categoryId] =
              currentSkip + fetchedProducts.length;
          _hasMoreProducts[categoryId] = fetchedProducts.length >= 10;
          _cachedProductsByCategory =
              Map.from(_productsByCategory); // Cập nhật cache
        } else {
          _hasMoreProducts[categoryId] = false;
        }
        _isLoadingMoreProducts[categoryId] = false;
      });

      // Cập nhật trạng thái cuộn sau khi tải dữ liệu
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_scrollControllers[categoryId]?.hasClients ?? false)) {
          _updateScrollState(categoryId);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMoreProducts[categoryId] = false;
        _hasMoreProducts[categoryId] = false;
        print("Error fetching more products for category $categoryId: $e");
      });
    }
  }

  final Map<int, Timer> _debounceTimers = {};

  void _initializeScrollControllers() {
    _scrollControllers.forEach((_, controller) => controller.dispose());
    _scrollControllers.clear();
    _scrollListeners.forEach((_, listener) {});
    _scrollListeners.clear();
    _canScrollForwardNotifiers.forEach((_, notifier) => notifier.dispose());
    _canScrollForwardNotifiers.clear();
    _canScrollBackwardNotifiers.forEach((_, notifier) => notifier.dispose());
    _canScrollBackwardNotifiers.clear();
    _debounceTimers.clear();

    for (var category in _categories) {
      final categoryId = category['category_id'] as int;
      final controller = ScrollController();
      _scrollControllers[categoryId] = controller;
      _canScrollForwardNotifiers[categoryId] = ValueNotifier(false);
      _canScrollBackwardNotifiers[categoryId] = ValueNotifier(false);

      final listener = () {
        // Cập nhật trạng thái cuộn
        if (_debounceTimers[categoryId]?.isActive ?? false) return;
        _debounceTimers[categoryId] =
            Timer(const Duration(milliseconds: 100), () {
          _updateScrollState(categoryId);
        });

        // Kích hoạt tải thêm sản phẩm khi cuộn đến cuối
        if (controller.position.pixels >=
                controller.position.maxScrollExtent - 200 &&
            !(_isLoadingMoreProducts[categoryId] ?? false) &&
            (_hasMoreProducts[categoryId] ?? false)) {
          _fetchProductsForCategory(categoryId);
        }
      };
      _scrollListeners[categoryId] = listener;
      controller.addListener(listener);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollStatesForAllCategories();
    });
  }

  void _updateScrollStatesForAllCategories() {
    if (mounted) {
      for (var cat in _categories) {
        final id = cat['category_id'] as int?;
        if (id != null) _updateScrollState(id);
      }
    }
  }

  void _updateScrollState(int categoryId) {
    final controller = _scrollControllers[categoryId];
    if (controller != null && controller.hasClients) {
      final position = controller.position;
      final canScrollB = position.pixels > position.minScrollExtent + 5.0;
      final canScrollF = position.pixels < position.maxScrollExtent - 5.0;

      if (_canScrollBackwardNotifiers[categoryId]?.value != canScrollB) {
        _canScrollBackwardNotifiers[categoryId]?.value = canScrollB;
      }
      if (_canScrollForwardNotifiers[categoryId]?.value != canScrollF) {
        _canScrollForwardNotifiers[categoryId]?.value = canScrollF;
      }
    } else {
      if (_canScrollBackwardNotifiers[categoryId]?.value != false) {
        _canScrollBackwardNotifiers[categoryId]?.value = false;
      }

      final productsInCategory = _productsByCategory[categoryId] ?? [];
      final currentSelectedSub = _selectedSubCategory[categoryId] ?? "Tất cả";

      final categoryDefinition = _categories.firstWhere(
          (cat) => cat['category_id'] == categoryId,
          orElse: () => {'sub_categories': <String>[]});
      final subCategories =
          List<String>.from(categoryDefinition['sub_categories'] ?? []);

      final List<Product> filteredProducts;
      if (currentSelectedSub == "Tất cả" || subCategories.isEmpty) {
        filteredProducts = productsInCategory;
      } else {
        filteredProducts = productsInCategory.where((p) {
          return p.brand != null &&
              p.brand!.name
                  .toLowerCase()
                  .contains(currentSelectedSub.toLowerCase());
        }).toList();
      }

      final totalContentWidth = filteredProducts.length * _itemWidth;
      if (context.findRenderObject() != null) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double mainSliverHorizontalPadding = kIsWeb
            ? (screenWidth > 1000 ? screenWidth * 0.07 : screenWidth * 0.03)
            : 10.0;
        final double categorySectionInternalHorizontalPadding = kIsWeb ? 6 : 2;
        final double viewportWidth = screenWidth -
            (2 * mainSliverHorizontalPadding) -
            (2 * categorySectionInternalHorizontalPadding);

        final bool hasMoreInitial = totalContentWidth > viewportWidth;
        if (_canScrollForwardNotifiers[categoryId]?.value != hasMoreInitial) {
          _canScrollForwardNotifiers[categoryId]?.value = hasMoreInitial;
        }
      } else {
        if (_canScrollForwardNotifiers[categoryId]?.value != false) {
          _canScrollForwardNotifiers[categoryId]?.value = false;
        }
      }
    }
  }

  void _scrollHorizontalList(int categoryId, bool forward) {
    final scrollController = _scrollControllers[categoryId];
    if (scrollController != null && scrollController.hasClients) {
      final maxScroll = scrollController.position.maxScrollExtent;
      final currentScroll = scrollController.offset;
      final minScroll = scrollController.position.minScrollExtent;
      final viewportWidth = scrollController.position.viewportDimension;
      final scrollAmount =
          (_itemWidth * 2.5).clamp(viewportWidth * 0.6, viewportWidth * 0.8);
      double targetScroll = forward
          ? (currentScroll + scrollAmount).clamp(minScroll, maxScroll)
          : (currentScroll - scrollAmount).clamp(minScroll, maxScroll);
      if ((targetScroll - currentScroll).abs() > 1.0) {
        scrollController.animateTo(targetScroll,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic);
      }
    }
  }

  void _scrollToTop() {
    _mainScrollController.animateTo(0,
        duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
  }

  Widget _buildBannerNavigationTabs(ThemeData theme, double availableWidth) {
    if (_highlightTabsData.isEmpty) {
      return const SizedBox.shrink();
    }
    final int maxVisibleTabs =
        kIsWeb ? 5 : (availableWidth / 100).floor().clamp(3, 5);
    bool useScrollable = _highlightTabsData.length > maxVisibleTabs;

    Widget buildTabItem(Map<String, String> tabData, int index) {
      final bool isSelected = _currentBannerPage == index;
      return InkWell(
        onTap: () {
          if (_bannerPageController.hasClients) {
            _bannerPageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }
        },
        child: Container(
          padding:
              EdgeInsets.symmetric(vertical: 10, horizontal: kIsWeb ? 12 : 8),
          constraints: BoxConstraints(minWidth: kIsWeb ? 120 : 90),
          decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 0.5)),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(kIsWeb ? 12 : 8),
                bottomRight: Radius.circular(kIsWeb ? 12 : 8),
              )),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tabData['title']!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: kIsWeb ? 12.5 : 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? HomeScreen.cpsTextBlack
                      : HomeScreen.cpsTextGrey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                tabData['subtitle']!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: kIsWeb ? 10.5 : 9,
                  color: isSelected
                      ? Colors.redAccent.shade400
                      : HomeScreen.cpsSubtleTextGrey,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
      ),
      child: useScrollable
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                children: _highlightTabsData.asMap().entries.map((entry) {
                  return buildTabItem(entry.value, entry.key);
                }).toList(),
              ),
            )
          : Row(
              children: _highlightTabsData.asMap().entries.map((entry) {
                return Expanded(child: buildTabItem(entry.value, entry.key));
              }).toList(),
            ),
    );
  }

  Widget _buildSlidingBannerItem(BuildContext context, ThemeData theme,
      Map<String, dynamic> bannerData, double availableWidth) {
    final bool isSmallScreen = availableWidth < 650;
    final bool isVerySmallScreen = availableWidth < 380;

    final String assetImagePath = bannerData['assetImagePath'] ??
        'https://via.placeholder.com/800x400/grey/white?text=Banner';
    final String productImageUrl = bannerData['productImageUrl'] ?? '';

    final List<Color> gradientColors =
        (bannerData['gradientColors'] as List<dynamic>?)
                ?.whereType<Color>()
                .toList() ??
            [HomeScreen.themeBlueLight, Colors.white];

    final brandText = bannerData['brandText'] as String? ?? '';
    final mainTitleLine1 =
        bannerData['mainTitleLine1'] as String? ?? 'Ưu đãi đặc biệt';
    final mainTitleLine2 = bannerData['mainTitleLine2'] as String? ?? '';
    final mainTitleColor =
        bannerData['mainTitleColor'] as Color? ?? HomeScreen.themeBluePrimary;

    final promos = (bannerData['promos'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    final actionText = bannerData['actionText'] as String? ?? 'Xem ngay';
    final VoidCallback? onTap = bannerData['onTap'] as VoidCallback?;
    final actionButtonBackgroundColor =
        bannerData['actionButtonBackgroundColor'] as Color? ?? Colors.white;
    final actionButtonTextColor =
        bannerData['actionButtonTextColor'] as Color? ??
            HomeScreen.themeBluePrimary;
    final actionButtonBorderColor =
        bannerData['actionButtonBorderColor'] as Color?;

    final brandTextStyle = GoogleFonts.getFont('Roboto',
        fontSize: isSmallScreen ? 16 : 20,
        fontWeight: FontWeight.w500,
        color: Colors.black.withOpacity(0.7));
    final mainTitleStyle = GoogleFonts.getFont('Roboto',
        fontSize: isVerySmallScreen ? 24 : (isSmallScreen ? 30 : 38),
        fontWeight: FontWeight.bold,
        color: mainTitleColor,
        height: 1.15,
        letterSpacing: -0.5);
    final promoTitleStyle = GoogleFonts.getFont('Roboto',
        fontSize: isVerySmallScreen ? 9 : (isSmallScreen ? 10 : 11.5),
        color: bannerData['promoTitleColor'] ?? Colors.grey.shade700);
    final promoValueStyleBase = GoogleFonts.getFont('Roboto',
        fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 13 : 15),
        fontWeight: FontWeight.bold);

    Widget promoItemWidget(Map<String, dynamic> promo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            promo['title'] as String? ?? '',
            style: promoTitleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            promo['value'] as String? ?? '',
            style: promoValueStyleBase.copyWith(
                color: promo['valueColor'] as Color? ?? Colors.redAccent),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          image: assetImagePath.startsWith('http')
              ? DecorationImage(
                  image: NetworkImage(assetImagePath),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.05), BlendMode.dstATop))
              : DecorationImage(
                  image: AssetImage(assetImagePath),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.05), BlendMode.dstATop)),
          gradient: LinearGradient(
            colors: gradientColors.length >= 2
                ? gradientColors
                : [gradientColors.first, gradientColors.first],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            if (productImageUrl.isNotEmpty)
              Positioned.fill(
                child: Align(
                  alignment: Alignment(isSmallScreen ? 1.05 : 0.9, 0.05),
                  child: FractionallySizedBox(
                    widthFactor: isSmallScreen ? 0.52 : 0.45,
                    heightFactor: isSmallScreen ? 0.75 : 0.8,
                    child: productImageUrl.startsWith('http')
                        ? Image.network(productImageUrl, fit: BoxFit.contain)
                        : Image.asset(productImageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) =>
                                const SizedBox.shrink()),
                  ),
                ),
              ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(
                      left: isVerySmallScreen
                          ? 10
                          : (isSmallScreen
                              ? 16
                              : (kIsWeb ? availableWidth * 0.035 : 20)),
                      right: availableWidth * (isSmallScreen ? 0.48 : 0.52),
                      top: 8,
                      bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (brandText.isNotEmpty) ...[
                        Text(brandText, style: brandTextStyle),
                        SizedBox(height: isSmallScreen ? 4 : 8),
                      ],
                      Text(mainTitleLine1, style: mainTitleStyle),
                      if (mainTitleLine2.isNotEmpty)
                        Text(mainTitleLine2, style: mainTitleStyle),
                      SizedBox(height: isSmallScreen ? 10 : 16),
                      if (promos.isNotEmpty)
                        Wrap(
                          spacing: isSmallScreen ? 12 : 20,
                          runSpacing: 8,
                          children:
                              promos.map((p) => promoItemWidget(p)).toList(),
                        ),
                      SizedBox(height: isSmallScreen ? 12 : 20),
                      if (actionText.isNotEmpty)
                        ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: actionButtonBackgroundColor,
                            foregroundColor: actionButtonTextColor,
                            padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 18 : 24,
                                vertical: isSmallScreen ? 10 : 12),
                            textStyle: TextStyle(
                                fontSize: isSmallScreen ? 13 : 15,
                                fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: actionButtonBorderColor != null
                                  ? BorderSide(
                                      color: actionButtonBorderColor,
                                      width: 1.5)
                                  : BorderSide.none,
                            ),
                            elevation: 2,
                          ),
                          child: Text(actionText),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_slidingBannersData.length > 1) ...[
              Positioned(
                  left: kIsWeb ? 8 : 2,
                  top: 0,
                  bottom: 0,
                  child: Center(
                      child: IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.black.withOpacity(0.30),
                              size: kIsWeb ? 22 : 18),
                          onPressed: () => _bannerPageController.previousPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOut)))),
              Positioned(
                  right: kIsWeb ? 8 : 2,
                  top: 0,
                  bottom: 0,
                  child: Center(
                      child: IconButton(
                          icon: Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.black.withOpacity(0.30),
                              size: kIsWeb ? 22 : 18),
                          onPressed: () => _bannerPageController.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOut)))),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingElements(ThemeData theme) {
    return Stack(
      children: [
        if (_showScrollToTopButton)
          Positioned(
              bottom: kIsWeb ? 60 : 50,
              right: kIsWeb ? 24 : 12,
              child: FloatingActionButton(
                  mini: true,
                  onPressed: _scrollToTop,
                  backgroundColor: HomeScreen.themeBluePrimary.withOpacity(0.9),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_upward_rounded,
                      color: Colors.white, size: 18))),
        Positioned(
            bottom: kIsWeb ? 12 : 8,
            right: kIsWeb ? 24 : 12,
            child: FloatingActionButton(
                mini: true,
                onPressed: () {
                  if (_backendUserId != null && _backendUserId!.isNotEmpty) {
                    // Kiểm tra kỹ _backendUserId
                    print(
                        "HomeScreen: Navigating to ChatScreen for user_id: $_backendUserId");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ChatScreen(), // Điều hướng đến ChatScreen
                      ),
                    );
                  } else {
                    print(
                        "HomeScreen: User not logged in or backendUserId is null/empty. Prompting login.");
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Vui lòng đăng nhập để sử dụng chức năng chat!')));
                    // Optional: Điều hướng đến trang đăng nhập nếu muốn
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen()));
                  }
                },
                backgroundColor: HomeScreen.themeBluePrimary,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tooltip: 'Chat với nhân viên',
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    color: Colors.white, size: 18))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'Roboto',
          bodyColor: HomeScreen.cpsTextBlack,
          displayColor: HomeScreen.cpsTextBlack),
      chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: HomeScreen.themeBlueLight,
          labelStyle: TextStyle(
              color: HomeScreen.cpsTextGrey,
              fontSize: kIsWeb ? 12 : 10.5,
              fontWeight: FontWeight.normal),
          secondaryLabelStyle: TextStyle(
              color: HomeScreen.themeBluePrimary,
              fontSize: kIsWeb ? 12 : 10.5,
              fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(
              color: HomeScreen.cpsCardBorderColor.withOpacity(0.5),
              width: 0.7)),
    );
    final screenWidth = MediaQuery.of(context).size.width;

    if (_isLoading && _categories.isEmpty && _productsByCategory.isEmpty) {
      return Scaffold(
          backgroundColor: HomeScreen.themePageBackground,
          body: Column(
            children: [
              SizedBox(
                height: (kIsWeb ? (screenWidth > 900 ? 60 : 50) : 45) +
                    MediaQuery.of(context).padding.top,
                child: CustomHeader(
                  categories: _categories,
                  currentUserData: _currentUserData, // Đã truyền
                  onCartPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CartScreen()),
                    );
                  },
                  onAccountPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AccountPage()),
                    );
                  },
                  onCategorySelected: (Map<String, dynamic> selectedCategory) {
                    print(
                        'Selected category from menu: ${selectedCategory['name']}');
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
              const Expanded(
                child: Center(
                    child: CircularProgressIndicator(
                        color: HomeScreen.themeBluePrimary)),
              ),
            ],
          ));
    }

    if (_errorMessage != null &&
        _categories.isEmpty &&
        _productsByCategory.isEmpty &&
        !_isLoading) {
      return Scaffold(
          backgroundColor: HomeScreen.themePageBackground,
          body: Column(
            children: [
              SizedBox(
                height: (kIsWeb ? (screenWidth > 900 ? 60 : 50) : 45) +
                    MediaQuery.of(context).padding.top,
                child: CustomHeader(
                  categories: _categories,
                  currentUserData: _currentUserData,
                  onCartPressed: () {
                    // TODO: Navigate to cart
                  },
                  onAccountPressed: () {
                    // TODO: Navigate to account or login
                  },
                  onCategorySelected: (Map<String, dynamic> selectedCategory) {
                    print(
                        'Selected category from menu: ${selectedCategory['name']}');
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
              Expanded(child: _buildErrorState(theme, _errorMessage!)),
            ],
          ));
    }

    if (!_isLoading && _errorMessage == null && _categories.isEmpty) {
      return Scaffold(
          backgroundColor: HomeScreen.themePageBackground,
          body: Column(
            children: [
              SizedBox(
                height: (kIsWeb ? (screenWidth > 900 ? 60 : 50) : 45) +
                    MediaQuery.of(context).padding.top,
                child: CustomHeader(
                  categories: _categories,
                  currentUserData: _currentUserData,
                  onCartPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CartScreen()),
                    );
                  },
                  onAccountPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AccountPage()),
                    );
                  },
                  onCategorySelected: (Map<String, dynamic> selectedCategory) {
                    print(
                        'Selected category from menu: ${selectedCategory['name']}');
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
              Expanded(
                  child: _buildEmptyState(theme,
                      "Không có sản phẩm hoặc danh mục nào.", Icons.shelves)),
            ],
          ));
    }

    return Scaffold(
      backgroundColor: HomeScreen.themePageBackground,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadInitialData,
            color: HomeScreen.themeBluePrimary,
            backgroundColor: Colors.white,
            child: CustomScrollView(
              controller: _mainScrollController,
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: HomeScreen.themeBluePrimary,
                  elevation: 2,
                  titleSpacing: 0,
                  flexibleSpace: FlexibleSpaceBar(
                      titlePadding: EdgeInsets.zero,
                      title: CustomHeader(
                        categories: _categories,
                        currentUserData: _currentUserData,
                        onCartPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const CartScreen()),
                          );
                        },
                        onAccountPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const AccountPage()),
                          );
                        },
                        onCategorySelected:
                            (Map<String, dynamic> selectedCategory) {
                          print(
                              'Selected category from menu: ${selectedCategory['name']}');
                          final categoryId =
                              selectedCategory['category_id'] as int?;
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
                      )),
                  toolbarHeight: (kIsWeb ? (screenWidth > 900 ? 60 : 50) : 45) +
                      MediaQuery.of(context).padding.top,
                ),
                SliverToBoxAdapter(
                  child: Container(
                    margin: EdgeInsets.symmetric(
                        horizontal: kIsWeb ? screenWidth * 0.07 : 10.0,
                        vertical: 20.0),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(kIsWeb ? 12 : 8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.maxWidth;
                        return Column(
                          children: [
                            if (_slidingBannersData.isNotEmpty)
                              SizedBox(
                                height: (kIsWeb
                                    ? (availableWidth * 0.35)
                                        .clamp(250.0, 380.0)
                                    : (availableWidth * 0.68)
                                        .clamp(180.0, 350.0)),
                                child: PageView.builder(
                                  controller: _bannerPageController,
                                  onPageChanged: (index) {
                                    _bannerTimer?.cancel();
                                    if (mounted) {
                                      setState(() {
                                        _currentBannerPage =
                                            index % _slidingBannersData.length;
                                      });
                                    }
                                    Future.delayed(const Duration(seconds: 8),
                                        () {
                                      if (mounted) _startBannerTimer();
                                    });
                                  },
                                  itemCount: _slidingBannersData.length,
                                  itemBuilder: (context, index) {
                                    final bannerData =
                                        _slidingBannersData[index];
                                    return _buildSlidingBannerItem(context,
                                        theme, bannerData, availableWidth);
                                  },
                                ),
                              )
                            else
                              Container(
                                height: (kIsWeb
                                    ? (availableWidth * 0.35)
                                        .clamp(250.0, 380.0)
                                    : (availableWidth * 0.68)
                                        .clamp(180.0, 350.0)),
                                decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(kIsWeb ? 12 : 8),
                                      topRight:
                                          Radius.circular(kIsWeb ? 12 : 8),
                                    )),
                                child: const Center(
                                    child: Text("Không có banner quảng cáo")),
                              ),
                            _buildBannerNavigationTabs(theme, availableWidth),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: kIsWeb
                            ? (screenWidth > 1000
                                ? screenWidth * 0.07
                                : screenWidth * 0.03)
                            : 10.0),
                    child: _buildSpecialSection(
                      theme: theme,
                      title: "Sản Phẩm Mới Nhất",
                      products: _newestProducts,
                      isLoading: _isLoadingNewest,
                      icon: Icons.new_releases_rounded,
                      headerColor: Colors.green.shade800,
                      iconColor: Colors.green.shade700,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: kIsWeb
                            ? (screenWidth > 1000
                                ? screenWidth * 0.07
                                : screenWidth * 0.03)
                            : 10.0),
                    child: _buildSpecialSection(
                      theme: theme,
                      title: "Sản Phẩm Bán Chạy",
                      products: _bestSellerProducts,
                      isLoading: _isLoadingBestSellers,
                      icon: Icons.trending_up_rounded,
                      headerColor: Colors.blue.shade800,
                      iconColor: Colors.blue.shade700,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: kIsWeb
                            ? (screenWidth > 1000
                                ? screenWidth * 0.07
                                : screenWidth * 0.03)
                            : 10.0),
                    child: _buildSpecialSection(
                      theme: theme,
                      title: "Sản Phẩm Giảm Giá",
                      products: _discountedProducts,
                      isLoading: _isLoadingPromotional,
                      icon: Icons.local_offer_rounded,
                      headerColor: Colors.red.shade800,
                      iconColor: Colors.red.shade700,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                      horizontal: kIsWeb
                          ? (screenWidth > 1000
                              ? screenWidth * 0.07
                              : screenWidth * 0.03)
                          : 10.0,
                      vertical: 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final categoryMap = _categories[index];
                        final categoryId = categoryMap['category_id'] as int;
                        final categoryName =
                            categoryMap['name'] as String? ?? 'Danh mục';
                        return _buildCategorySection(
                            theme, categoryId, categoryName);
                      },
                      childCount: _categories.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: AppFooter()),
                SliverToBoxAdapter(child: SizedBox(height: kIsWeb ? 80 : 60)),
              ],
            ),
          ),
          _buildFloatingElements(theme),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String message) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, color: Colors.red[400], size: 50),
        const SizedBox(height: 12),
        Text("Lỗi: $message",
            style:
                theme.textTheme.titleMedium?.copyWith(color: Colors.red[400]),
            textAlign: TextAlign.center)
      ]));

  Widget _buildEmptyState(ThemeData theme, String message, IconData icon) =>
      Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 50, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(message,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: HomeScreen.cpsSubtleTextGrey))
      ]));

  Widget _buildCategorySection(
      ThemeData theme, int categoryId, String categoryName) {
    List<Product> productsForThisSection =
        _productsByCategory[categoryId] ?? [];
    final ScrollController? scrollController = _scrollControllers[categoryId];
    final ValueNotifier<bool>? canScrollForwardNotifier =
        _canScrollForwardNotifiers[categoryId];
    final ValueNotifier<bool>? canScrollBackwardNotifier =
        _canScrollBackwardNotifiers[categoryId];

    final categoryDefinition = _categories.firstWhere(
        (cat) => cat['category_id'] == categoryId,
        orElse: () => {'sub_categories': <String>[]});
    final List<String> subCategories =
        List<String>.from(categoryDefinition['sub_categories'] ?? []);
    final String currentSelectedSub = _selectedSubCategory[categoryId] ??
        (subCategories.isNotEmpty ? subCategories.first : "Tất cả");

    final Map<int, Map<String, List<Product>>> _filteredProductsCache = {};
// Trong _buildCategorySection
    final List<Product> productsToDisplay;
    if (currentSelectedSub == "Tất cả" || subCategories.isEmpty) {
      productsToDisplay = productsForThisSection;
    } else {
      if (_filteredProductsCache[categoryId]?.containsKey(currentSelectedSub) ??
          false) {
        productsToDisplay =
            _filteredProductsCache[categoryId]![currentSelectedSub]!;
      } else {
        productsToDisplay = productsForThisSection.where((p) {
          return p.brand != null &&
              p.brand!.name
                  .toLowerCase()
                  .contains(currentSelectedSub.toLowerCase());
        }).toList();
        _filteredProductsCache.putIfAbsent(categoryId, () => {});
        _filteredProductsCache[categoryId]![currentSelectedSub] =
            productsToDisplay;
      }
    }

    // Khởi tạo ScrollController nếu chưa có
    if (!_scrollControllers.containsKey(categoryId)) {
      final controller = ScrollController();
      _scrollControllers[categoryId] = controller;
      _canScrollForwardNotifiers[categoryId] = ValueNotifier(false);
      _canScrollBackwardNotifiers[categoryId] = ValueNotifier(false);

      controller.addListener(() {
        // Debounce cho cả cập nhật trạng thái và tải thêm
        if (_debounceTimers[categoryId]?.isActive ?? false) return;
        _debounceTimers[categoryId] =
            Timer(const Duration(milliseconds: 100), () {
          _updateScrollState(categoryId);
        });

        // Tải thêm sản phẩm khi cuộn đến cuối
        if (controller.position.extentAfter < 50 &&
            !(_isLoadingMoreProducts[categoryId] ?? false) &&
            (_hasMoreProducts[categoryId] ?? false)) {
          _fetchProductsForCategory(categoryId);
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateScrollState(categoryId);
      });
    }

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                  left: kIsWeb ? 4 : 2,
                  right: kIsWeb ? 4 : 2,
                  bottom: subCategories.length > 1 ? 6 : 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(children: [
                    Icon(Icons.auto_awesome_mosaic_outlined,
                        color: HomeScreen.themeBluePrimary,
                        size: kIsWeb ? 20 : 18),
                    const SizedBox(width: 8),
                    Text(categoryName.toUpperCase(),
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: kIsWeb ? 17 : 15,
                            color: HomeScreen.cpsTextBlack)),
                  ]),
                ],
              ),
            ),
            if (subCategories.length > 1)
              Padding(
                padding: EdgeInsets.only(
                    bottom: 12.0, left: kIsWeb ? 4 : 2, right: kIsWeb ? 4 : 2),
                child: SizedBox(
                  height: kIsWeb ? 34 : 30,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: subCategories.length,
                    itemBuilder: (context, index) {
                      final subCategoryName = subCategories[index];
                      final isSelected = subCategoryName == currentSelectedSub;
                      return Padding(
                        padding: EdgeInsets.only(
                            right: 8.0, left: index == 0 ? 0 : 0),
                        child: ChoiceChip(
                          label: Text(subCategoryName),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              if (_debounceTimers[categoryId]?.isActive ??
                                  false) {
                                _debounceTimers[categoryId]?.cancel();
                              }
                              _debounceTimers[categoryId] =
                                  Timer(const Duration(milliseconds: 200), () {
                                setState(() {
                                  _selectedSubCategory[categoryId] =
                                      subCategoryName;
                                });
                                _updateScrollState(categoryId);
                              });
                            }
                          },
                          selectedColor: HomeScreen.themeBlueLight,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? HomeScreen.themeBluePrimary
                                : HomeScreen.cpsTextGrey,
                            fontSize: kIsWeb ? 12 : 10.5,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected
                                  ? HomeScreen.themeBluePrimary.withOpacity(0.6)
                                  : HomeScreen.cpsCardBorderColor
                                      .withOpacity(0.6),
                              width: 0.8,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      );
                    },
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.12),
                      spreadRadius: 0.5,
                      blurRadius: 6,
                      offset: const Offset(0, 3))
                ],
              ),
              padding: EdgeInsets.symmetric(
                  vertical: kIsWeb ? 14 : 10, horizontal: kIsWeb ? 6 : 2),
              child: (productsToDisplay.isEmpty &&
                      !(_isLoadingMoreProducts[categoryId] ?? false) &&
                      !_isLoading)
                  ? _buildEmptyCategoryPlaceholder(theme)
                  : SizedBox(
                      height: _productCardHeight + (kIsWeb ? 10 : 6),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ListView.builder(
                            controller: scrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: productsToDisplay.length +
                                ((_hasMoreProducts[categoryId] ?? false)
                                    ? 1
                                    : 0),
                            itemBuilder: (context, productIndex) {
                              if (productIndex == productsToDisplay.length &&
                                  (_hasMoreProducts[categoryId] ?? false)) {
                                return Center(
                                  child: Container(
                                    width: _productCardWidth,
                                    padding: const EdgeInsets.all(16.0),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: HomeScreen.themeBluePrimary),
                                    ),
                                  ),
                                );
                              }
                              if (productIndex >= productsToDisplay.length)
                                return const SizedBox.shrink();

                              return _buildProductCard(
                                  theme: theme,
                                  product: productsToDisplay[productIndex],
                                  cardMargin: _cardHorizontalMargin);
                            },
                          ),
                          _buildNavigationArrow(
                            theme: theme,
                            categoryId: categoryId,
                            isForward: false,
                            canScrollNotifier: canScrollBackwardNotifier,
                            hasMoreApi: false,
                            isLoading: false,
                            horizontalOffset: kIsWeb ? -8 : -4,
                            productCount: productsToDisplay.length,
                          ),
                          _buildNavigationArrow(
                            theme: theme,
                            categoryId: categoryId,
                            isForward: true,
                            canScrollNotifier: canScrollForwardNotifier,
                            hasMoreApi: (_hasMoreProducts[categoryId] ?? false),
                            isLoading:
                                (_isLoadingMoreProducts[categoryId] ?? false),
                            horizontalOffset: kIsWeb ? -8 : -4,
                            productCount: productsToDisplay.length,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ));
  }

  Future<void> _handleLoginSuccess(
      Map<String, dynamic> userDataFromLogin) async {
    if (!mounted) return;
    setState(() {
      _currentUserData = userDataFromLogin;
      // Có thể lưu vào SharedPreferences ở đây nếu muốn
    });
  }

  Widget _buildNavigationArrow(
      {required ThemeData theme,
      required int categoryId,
      required bool isForward,
      required ValueNotifier<bool>? canScrollNotifier,
      required bool hasMoreApi,
      required bool isLoading,
      required double horizontalOffset,
      required int productCount}) {
    return ValueListenableBuilder<bool>(
      valueListenable: canScrollNotifier ?? ValueNotifier(false),
      builder: (context, canScrollUIValue, child) {
        bool actualCanScroll = canScrollUIValue;
        if (isForward && isLoading && hasMoreApi) {
        } else if (!actualCanScroll && !isLoading) {
          return const SizedBox.shrink();
        }

        if (isForward && isLoading && hasMoreApi)
          return const SizedBox.shrink();

        return Positioned(
          top: 0,
          bottom: 0,
          left: isForward ? null : horizontalOffset,
          right: isForward ? horizontalOffset : null,
          child: Center(
            child: (isLoading &&
                    ((isForward && hasMoreApi) ||
                        !isForward /*loading previous not implemented*/))
                ? Container(
                    width: kIsWeb ? 40 : 36,
                    height: kIsWeb ? 40 : 36,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4)
                        ]),
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: HomeScreen.themeBluePrimary))
                : actualCanScroll
                    ? Material(
                        color: Colors.white.withOpacity(0.85),
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () =>
                                _scrollHorizontalList(categoryId, isForward),
                            child: Container(
                                width: kIsWeb ? 40 : 36,
                                height: kIsWeb ? 40 : 36,
                                alignment: Alignment.center,
                                child: Icon(
                                    isForward
                                        ? Icons.arrow_forward_ios_rounded
                                        : Icons.arrow_back_ios_new_rounded,
                                    color: HomeScreen.themeBluePrimary,
                                    size: kIsWeb ? 18 : 15))))
                    : const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Widget _buildEmptyCategoryPlaceholder(ThemeData theme) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0),
      child: Center(
          child: Text("Không có sản phẩm nào trong mục này.",
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: HomeScreen.cpsSubtleTextGrey))));

  Widget _buildProductCard({
    required ThemeData theme,
    required Product product,
    required double cardMargin,
  }) {
    final String displayPriceText = product.salePriceText;
    final String originalPriceToStrike =
        (product.isOnSale && product.originalPriceText != product.salePriceText)
            ? product.originalPriceText
            : '';

    final productName = product.name;
    final String? rawThumbnailUrl = product.thumbnailUrl;

    final String discountBadgeText = product.discountBadgeText;
    final String installmentBadgeText = product.installmentBadgeText;
    final List<String> additionalInfoTags = product.additionalInfoTags;
    final double starRating = product.starRating;
    bool isLiked = product.isLiked;

    final Color primaryColor = HomeScreen.themeBluePrimary;
    final Color lightBgColor = HomeScreen.themeBlueLight;
    final double productNameLineHeight = kIsWeb ? 17.0 : 15.0;
    final double fixedProductNameHeight = productNameLineHeight * 2.1;

    // Chuẩn bị tag hiển thị, thêm phần trăm giảm giá nếu có
    final List<Widget> tagWidgets = [];
    if (additionalInfoTags.isNotEmpty) {
      for (var tag in additionalInfoTags.take(kIsWeb ? 2 : 2)) {
        tagWidgets.add(
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: kIsWeb ? 6 : 5, vertical: kIsWeb ? 2.5 : 2),
            decoration: BoxDecoration(
              color: lightBgColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tag,
                  style: TextStyle(
                    color: primaryColor.withOpacity(0.9),
                    fontSize: kIsWeb ? 10.5 : 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (tag == 'Hàng chính hãng' &&
                    product.discount != null &&
                    product.discount!.discountPercent > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '-${product.discount!.discountPercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: kIsWeb ? 10.5 : 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    return Container(
      width: _productCardWidth,
      margin: EdgeInsets.symmetric(horizontal: cardMargin, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: HomeScreen.cpsCardBorderColor.withOpacity(0.6),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          print("Tapped on product: ${product.name}, ID: ${product.productId}");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ProductDetailsScreen2(productId: product.productId),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Center(
                      child: (rawThumbnailUrl != null &&
                              rawThumbnailUrl.isNotEmpty)
                          ? Image.asset(
                              rawThumbnailUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                print(
                                    "Error loading asset: '$rawThumbnailUrl', Error: $error");
                                return Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey[300],
                                  size: 40,
                                );
                              },
                            )
                          : Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey[300],
                              size: 40,
                            ),
                    ),
                  ),
                  if (discountBadgeText.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          discountBadgeText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: kIsWeb ? 11 : 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (installmentBadgeText.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: HomeScreen.cpsInstallmentBlue,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          installmentBadgeText,
                          style: TextStyle(
                            color: HomeScreen.cpsInstallmentBlue,
                            fontSize: kIsWeb ? 11 : 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 10, right: 10, bottom: 10, top: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: fixedProductNameHeight,
                      child: Text(
                        productName,
                        style: TextStyle(
                          fontSize: kIsWeb ? 14.5 : 12.5,
                          fontWeight: FontWeight.w600,
                          color: HomeScreen.cpsTextBlack,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          displayPriceText,
                          style: TextStyle(
                            color: product.isOnSale
                                ? Colors.redAccent
                                : primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: kIsWeb ? 16.5 : 14.5,
                          ),
                        ),
                        if (originalPriceToStrike.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              originalPriceToStrike,
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: HomeScreen.cpsSubtleTextGrey
                                    .withOpacity(0.8),
                                fontSize: kIsWeb ? 12.5 : 10.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: kIsWeb ? 8 : 5),
                    if (tagWidgets.isNotEmpty)
                      Wrap(
                        spacing: 5,
                        runSpacing: 3,
                        children: tagWidgets,
                      ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                index < starRating.floor()
                                    ? Icons.star_rounded
                                    : (index < starRating &&
                                            (starRating - index) >= 0.5)
                                        ? Icons.star_half_rounded
                                        : Icons.star_border_rounded,
                                color: HomeScreen.cpsStarYellow,
                                size: kIsWeb ? 17 : 15,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () {
                              setState(() {
                                product.isLiked = !isLiked;
                              });
                              print(
                                  "Product ${product.productId} liked: ${product.isLiked}");
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isLiked
                                    ? primaryColor
                                    : HomeScreen.cpsSubtleTextGrey
                                        .withOpacity(0.7),
                                size: kIsWeb ? 20 : 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
