import 'package:cross_platform_mobile_app_development/screens/profile_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';

import '../models/product_detail_model.dart';
import '../models/product_list_item_model.dart';
import '../models/review_model.dart';
import '../services/api_service.dart';
import '../widgets/footer.dart';
import '../widgets/header.dart';
import 'cart_product.dart';
import 'home_screen.dart'; // *** THAY ĐỔI: Import CustomHeader từ custom_header.dart

class ProductDetailsScreen2 extends StatefulWidget {
  final int productId;
  const ProductDetailsScreen2({super.key, required this.productId});

  @override
  _ProductDetailsScreenState createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen2> {
  int _selectedStorageIndex = 1;
  int _selectedColorIndex = 0;
  int _selectedImageIndex = 0;
  int _selectedReviewPrimaryFilter = 0;
  int? _selectedReviewStarFilter;
  late ScrollController _similarProductsScrollController;
  bool _showSimilarLeftArrow = false;
  bool _showSimilarRightArrow = false;
  Map<String, dynamic>? _currentUserData;
  bool _isAddingToCart = false;
  // *** THÊM: Danh sách danh mục mẫu (có thể thay bằng dữ liệu từ API hoặc _productDetail) ***
  final List<Map<String, dynamic>> _categories = [
    {'category_id': 1, 'name': 'Điện thoại'},
    {'category_id': 2, 'name': 'Laptop'},
  ];

  Future<void> _handleAddToCart({bool navigateToCart = false}) async {
    if (_isAddingToCart) return;

    if (_productDetail == null || _productDetail!.variants.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi: Dữ liệu sản phẩm không hợp lệ.'), backgroundColor: Colors.red),
      );
      return;
    }

    final int? userId = _currentUserData?['user_id'] as int?;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để thêm vào giỏ hàng.'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Đảm bảo _selectedColorIndex hợp lệ
    int currentSelectedVariantIndex = _selectedColorIndex;
    if (currentSelectedVariantIndex >= _productDetail!.variants.length || currentSelectedVariantIndex < 0) {
      currentSelectedVariantIndex = 0; // Mặc định chọn variant đầu tiên
      setState(() {
        _selectedColorIndex = 0;
        _selectedStorageIndex = 0;
      });
    }

    final selectedVariant = _productDetail!.variants[currentSelectedVariantIndex];
    final int variantId = selectedVariant.variantId;
    const int quantity = 1;

    // Tính currentPrice
    double basePrice = double.tryParse(_productDetail!.basePrice) ?? 0.0;
    double additionalPrice = double.tryParse(selectedVariant.additionalPrice) ?? 0.0;
    double currentPrice = basePrice + additionalPrice;
    if (_productDetail!.discount != null && _productDetail!.discount!.isActive) {
      double discountPercent = double.tryParse(_productDetail!.discount!.discountPercent) ?? 0.0;
      if (discountPercent > 0) {
        currentPrice = currentPrice * (1 - discountPercent / 100);
      }
    }

    setState(() {
      _isAddingToCart = true;
    });

    try {
      final success = await _apiService.addToCart(variantId, quantity, userId);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm "${_productDetail!.name} - ${selectedVariant.variantName}" vào giỏ hàng!'),
            backgroundColor: Colors.green,
          ),
        );

        if (navigateToCart) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CartScreen(
                addedVariantId: variantId,
                addedCurrentPrice: currentPrice,
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thêm vào giỏ hàng thất bại. Có thể sản phẩm đã hết hàng hoặc có lỗi xảy ra.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xảy ra lỗi khi thêm vào giỏ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print("Error in _handleAddToCart UI: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  // *** THÊM: Số lượng sản phẩm trong giỏ hàng (giá trị mẫu) ***
  int get _cartItemCount => 0; // Thay bằng dữ liệu thực từ state management nếu có

  final ApiService _apiService = ApiService();
  ProductDetail? _productDetail;
  List<Review> _productReviews = [];
  bool _isLoadingProduct = true;
  bool _isLoadingReviews = true;
  String? _productError;
  String? _reviewsError;
  final _reviewFormKey = GlobalKey<FormState>();
  final _reviewCommentController = TextEditingController();
  int _currentReviewRating = 5;
  List<ProductListItem> _similarProductsFromApi = [];
  bool _isLoadingSimilarProducts = false;
  String? _similarProductsError;

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Gọi hàm để tải dữ liệu người dùng
    _fetchProductData();
    _similarProductsScrollController = ScrollController();
    _similarProductsScrollController.addListener(_updateSimilarArrowVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateSimilarArrowVisibility();
    });
  }

  Future<void> _loadUserData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? loadedBackendUserId = prefs.getString('user_uid');
      final String? loadedFullName = prefs.getString('user_fullName');

      if (mounted) {
        setState(() {
          _currentUserData = {
            'user_id': loadedBackendUserId != null ? int.tryParse(loadedBackendUserId) : null,
            'full_name': loadedFullName ?? 'Khách',
            'avatar_url': null, // Có thể lấy từ SharedPreferences hoặc API nếu có
          };
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _currentUserData = {
            'user_id': null,
            'full_name': 'Khách',
            'avatar_url': null,
          };
        });
      }
    }
  }

  @override
  void dispose() {
    _similarProductsScrollController.removeListener(_updateSimilarArrowVisibility);
    _similarProductsScrollController.dispose();
    _reviewCommentController.dispose();
    super.dispose();
  }

  Future<void> _fetchSimilarProducts() async {
    if (_productDetail == null) return;
    print(_productDetail);
    setState(() {
      _isLoadingSimilarProducts = true;
      _similarProductsError = null;
    });

    try {
      final products = await _apiService.getProducts(
        categoryId: _productDetail!.categoryId,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _similarProductsFromApi = products.where((p) => p.productId != _productDetail!.productId).toList();
          _isLoadingSimilarProducts = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _updateSimilarArrowVisibility();
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _similarProductsError = "Lỗi tải sản phẩm tương tự: ${e.toString()}";
          _isLoadingSimilarProducts = false;
        });
      }
      print("Error fetching similar products: $e");
    }
  }

  Future<void> _fetchProductData() async {
    setState(() {
      _isLoadingProduct = true;
      _isLoadingReviews = true;
      _productError = null;
      _reviewsError = null;
    });
    try {
      final product = await _apiService.getProductDetails(widget.productId);
      if (mounted) {
        setState(() {
          _productDetail = product;
          _isLoadingProduct = false;
          _selectedImageIndex = 0;
          _selectedStorageIndex =
          0; // Có thể cần điều chỉnh nếu variant đầu tiên không phải là lựa chọn mặc định
        });

        // DEBUGGING:
        if (_productDetail != null) {
          print("DEBUG: Product Detail Thumbnail URL (raw): ${_productDetail!
              .thumbnailUrl}");
          if (_productDetail!.images.isNotEmpty) {
            _productDetail!.images.asMap().forEach((index, img) {
              print("DEBUG: Product Detail Image $index URL (raw): ${img
                  .imageUrl}");
            });
          } else {
            print("DEBUG: Product Detail has no images in 'images' list.");
          }
        }
        _fetchSimilarProducts();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _productError = "Lỗi tải chi tiết sản phẩm: ${e.toString()}";
          _isLoadingProduct = false;
        });
      }
      print("Error fetching product: $e");
    }

    try {
      final reviews = await _apiService.getProductReviews(widget.productId);
      if (mounted) {
        setState(() {
          _productReviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reviewsError = "Lỗi tải đánh giá: ${e.toString()}";
          _isLoadingReviews = false;
        });
      }
      print("Error fetching reviews: $e");
    }
  }

  void _updateSimilarArrowVisibility() {
    if (!_similarProductsScrollController.hasClients ) {
      if (mounted && (_showSimilarLeftArrow || _showSimilarRightArrow)) {
        setState(() {
          _showSimilarLeftArrow = false;
          _showSimilarRightArrow = false;
        });
      }
      return;
    }

    final maxScroll = _similarProductsScrollController.position.maxScrollExtent;
    final currentScroll = _similarProductsScrollController.position.pixels;
    const threshold = 1.0;

    bool canScrollLeft = currentScroll > threshold;
    bool canScrollRight = maxScroll > threshold && currentScroll < (maxScroll - threshold);

    if (mounted) {
      if (_showSimilarLeftArrow != canScrollLeft || _showSimilarRightArrow != canScrollRight) {
        setState(() {
          _showSimilarLeftArrow = canScrollLeft;
          _showSimilarRightArrow = canScrollRight;
        });
      }
    }
  }

  void _scrollSimilarProducts(bool goRight) {
    if (!_similarProductsScrollController.hasClients) return;

    final currentOffset = _similarProductsScrollController.offset;
    final scrollAmount = (180.0 + 12.0) * 2;

    if (goRight) {
      _similarProductsScrollController.animateTo(
        currentOffset + scrollAmount,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _similarProductsScrollController.animateTo(
        currentOffset - scrollAmount,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToCatalog(int categoryId, String categoryName) {
    print('Navigating to category: $categoryName (ID: $categoryId)');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mở danh mục: $categoryName')),
    );
  }

  Map<String, dynamic> get _mappedProductData {
    if (_productDetail == null) {
      print("DEBUG - _mappedProductData: _productDetail is null, returning empty map.");
      return {};
    }

    List<String> imagePaths = [];
    if (_productDetail!.images.isNotEmpty) {
      imagePaths = _productDetail!.images
          .map((img) => img.imageUrl)
          .where((url) => url != null && url.isNotEmpty)
          .cast<String>()
          .toList();
    } else if (_productDetail!.thumbnailUrl != null && _productDetail!.thumbnailUrl!.isNotEmpty) {
      imagePaths.add(_productDetail!.thumbnailUrl!);
    }

    double basePriceNum = double.tryParse(_productDetail!.basePrice) ?? 0.0;
    String currentPriceStr = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(basePriceNum);
    String? oldPriceStr;

    if (_productDetail!.discount != null && _productDetail!.discount!.isActive) {
      double discountPercent = double.tryParse(_productDetail!.discount!.discountPercent) ?? 0.0;
      if (discountPercent > 0) {
        double discountedPrice = basePriceNum * (1 - (discountPercent / 100));
        currentPriceStr = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(discountedPrice);
        oldPriceStr = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(basePriceNum);
      }
    }

    List<Map<String, dynamic>> storageOptions = [];
    List<Map<String, dynamic>> colorOptions = [];

    for (int i = 0; i < _productDetail!.variants.length; i++) {
      var variant = _productDetail!.variants[i];
      double variantBasePrice = double.tryParse(_productDetail!.basePrice) ?? 0.0;
      double additionalPrice = double.tryParse(variant.additionalPrice) ?? 0.0;
      double totalVariantPrice = variantBasePrice + additionalPrice;

      if (_productDetail!.discount != null && _productDetail!.discount!.isActive) {
        double discountPercent = double.tryParse(_productDetail!.discount!.discountPercent) ?? 0.0;
        if (discountPercent > 0) {
          totalVariantPrice = totalVariantPrice * (1 - (discountPercent / 100));
        }
      }

      String formattedPrice = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(totalVariantPrice);

      storageOptions.add({
        'label': variant.variantName,
        'price': formattedPrice,
      });

      colorOptions.add({
        'name': variant.variantName,
        'price': formattedPrice,
        'image': variant.imageUrl
      });
    }

    return {
      'images': imagePaths,
      'name': _productDetail!.name,
      'colorOptions': colorOptions.isNotEmpty
          ? colorOptions
          : [{
        'name': 'Mặc định',
        'price': currentPriceStr,
        'image': _productDetail!.thumbnailUrl ?? 'placeholder_image.png'
      }],
      'productFullName': _productDetail!.name,
      'rating': _calculateAverageRating(),
      'reviewCount': _productReviews.length,
      'features': _productDetail!.description.split('.').where((s) => s.trim().isNotEmpty).toList(),
      'storageOptions': storageOptions.isNotEmpty ? storageOptions : [{'label': 'Mặc định', 'price': currentPriceStr}],
      'currentPrice': currentPriceStr,
      'oldPrice': oldPriceStr,
      'tradeInPrice': 'Liên hệ',
      'smemberDiscount': 'Xem chi tiết',
      'studentDiscount': 'Xem chi tiết',
      'promotions': _productDetail!.discount != null && _productDetail!.discount!.isActive
          ? ['Giảm ${_productDetail!.discount!.discountPercent}% đến hết ngày ${DateFormat('dd/MM/yyyy').format(_productDetail!.discount!.endDate)}']
          : [],
    };
  }

  Map<String, dynamic> get _mappedReviewSummaryData {
    if (_productReviews.isEmpty) {
      return {
        'averageRating': 0.0,
        'totalReviews': 0,
        'starDistribution': [0, 0, 0, 0, 0],
        'experienceRatings': []
      };
    }
    double totalRating = 0;
    List<int> starDistribution = [0, 0, 0, 0, 0];
    for (var review in _productReviews) {
      totalRating += review.rating;
      if (review.rating >= 1 && review.rating <= 5) {
        starDistribution[5 - review.rating]++;
      }
    }
    return {
      'averageRating': _productReviews.isNotEmpty ? (totalRating / _productReviews.length) : 0.0,
      'totalReviews': _productReviews.length,
      'starDistribution': starDistribution.reversed.toList(),
      'experienceRatings': [
        {'name': 'Chất lượng', 'rating': _calculateAverageRating(), 'count': _productReviews.length},
      ]
    };
  }

  List<Map<String, dynamic>> get _mappedReviews {
    return _productReviews.map((review) {
      return {
        'userName': review.user.fullName,
        'avatarInitial': review.user.fullName.isNotEmpty ? review.user.fullName[0].toUpperCase() : 'A',
        'date': DateFormat('dd/MM/yyyy HH:mm').format(review.createdAt),
        'rating': review.rating,
        'tags': [],
        'comment': review.comment,
        'avatarColor': Colors.deepPurple,
      };
    }).toList();
  }

  double _calculateAverageRating() {
    if (_productReviews.isEmpty) return 0.0;
    return _productReviews.map((r) => r.rating).reduce((a, b) => a + b) / _productReviews.length;
  }

  Future<void> _submitReview() async {
    if (_reviewFormKey.currentState!.validate()) {
      final int currentUserId = _currentUserData?['user_id'] ?? 3;

      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập để đánh giá!')),
        );
        return;
      }

      try {
        final newReview = await _apiService.postProductReview(
          widget.productId,
          currentUserId,
          _currentReviewRating,
          _reviewCommentController.text,
        );
        setState(() {
          _productReviews.insert(0, newReview);
          _reviewCommentController.clear();
          _currentReviewRating = 5;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đánh giá của bạn đã được gửi!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi đánh giá: $e')),
        );
        print("Error posting review: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 950;

    if (_isLoadingProduct) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(
              kIsWeb ? (screenWidth > 900 ? 60 : 50) : 45 + MediaQuery.of(context).padding.top
          ),
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_productError != null) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(
              kIsWeb ? (screenWidth > 900 ? 60 : 50) : 45 + MediaQuery.of(context).padding.top
          ),
          child: CustomHeader(
            categories: _categories,
            currentUserData: _currentUserData,
            cartItemCount: _cartItemCount,
            onCartPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
            },
            onAccountPressed: () {
              print("Account button pressed");
            },
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
              print('Search submitted: $value');
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_productError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontSize: 16)),
                SizedBox(height: 20),
                ElevatedButton(onPressed: _fetchProductData, child: Text("Thử lại"))
              ],
            ),
          ),
        ),
      );
    }

    final Map<String, dynamic> product = _mappedProductData;
    final Map<String, dynamic> reviewSummaryData = _mappedReviewSummaryData;
    final List<Map<String, dynamic>> reviews = _mappedReviews;

    return Scaffold(
      backgroundColor: HomeScreen.themePageBackground,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
            kIsWeb ? (screenWidth > 900 ? 60 : 50) : 45 + MediaQuery.of(context).padding.top
        ),
        child: CustomHeader(
          categories: _categories,
          currentUserData: _currentUserData,
          cartItemCount: _cartItemCount,
          onCartPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
          },
          onAccountPressed: () {
            print("Account button pressed");
          },
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
            print('Search submitted: $value');
          },
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isLargeScreen ? screenWidth * 0.08 : 16,
              16,
              isLargeScreen ? screenWidth * 0.08 : 16,
              150,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumbs(product),
                const SizedBox(height: 16),
                _buildProductNameAndRating(product),
                const SizedBox(height: 20),
                isLargeScreen
                    ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildProductImageAndFeaturesSection(isLargeScreen, product)),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: _buildPricingAndOptionsSection(isLargeScreen, product)),
                  ],
                )
                    : Column(
                  children: [
                    _buildProductImageAndFeaturesSection(isLargeScreen, product),
                    const SizedBox(height: 24),
                    _buildPricingAndOptionsSection(isLargeScreen, product),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSimilarProductsSection(),
                const SizedBox(height: 32),
                _buildProductReviewsSection(product, reviewSummaryData, reviews),
                const SizedBox(height: 32),
                const AppFooter(),
              ],
            ),
          ),
          _buildFixedChatButton(),
          _buildScrollToTopButton(),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(Map<String, dynamic> productData) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        _breadcrumbItem("Trang chủ"),
        _breadcrumbIcon(),
        _breadcrumbItem(_productDetail?.category.name ?? "Danh mục", isCurrent: false),
        _breadcrumbIcon(),
        _breadcrumbItem(_productDetail?.name ?? "Sản phẩm", isCurrent: true),
      ],
    );
  }

  Widget _buildProductNameAndRating(Map<String, dynamic> productData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          productData['name'] ?? 'Tên sản phẩm không có',
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: HomeScreen.cpsTextBlack,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < 5; i++)
              Icon(
                i < (productData['rating'] as double? ?? 0.0).floor() ? Icons.star : Icons.star_border,
                color: HomeScreen.cpsStarYellow,
                size: 18,
              ),
            const SizedBox(width: 8),
            Text(
              '${productData['reviewCount'] ?? 0} đánh giá',
              style: GoogleFonts.montserrat(fontSize: 14, color: HomeScreen.cpsTextGrey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductImageAndFeaturesSection(bool isLargeScreen, Map<String, dynamic> productData) {
    print("DEBUG - _buildProductImageAndFeaturesSection - productData['images']: ${productData['images']}");
    List<String> images = List<String>.from(productData['images'] ?? []);
    String? currentImage = (images.isNotEmpty && _selectedImageIndex < images.length)
        ? images[_selectedImageIndex]
        : null;
    if (images.isNotEmpty && _selectedImageIndex >= images.length) {
      _selectedImageIndex = 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: HomeScreen.cpsCardBorderColor),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: currentImage != null && currentImage.isNotEmpty
                    ? Image.asset(
                    currentImage,
                    height: isLargeScreen ? 450 : 300,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      print("Lỗi tải asset: $currentImage - $error");
                      return Icon(Icons.broken_image, size: 100, color: HomeScreen.cpsCardBorderColor);
                    })
                    : Image.asset(
                  'assets/images/placeholder.png',
                  height: isLargeScreen ? 450 : 300,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (context, index) {
              String? thumbImage = images.length > index ? images[index] : null;
              return GestureDetector(
                onTap: () => setState(() => _selectedImageIndex = index),
                child: Container(
                  width: 70,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedImageIndex == index ? HomeScreen.themeBluePrimary : HomeScreen.cpsCardBorderColor,
                      width: _selectedImageIndex == index ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: thumbImage != null && thumbImage.isNotEmpty
                        ? Image.asset(
                      thumbImage,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 30, color: HomeScreen.cpsCardBorderColor),
                    )
                        : Icon(Icons.image_not_supported, size: 30, color: HomeScreen.cpsCardBorderColor),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HomeScreen.themeBlueLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TÍNH NĂNG NỔI BẬT',
                style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: HomeScreen.cpsTextBlack),
              ),
              const SizedBox(height: 10),
              ...(productData['features'] as List<dynamic>? ?? []).map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: GoogleFonts.montserrat(fontSize: 14, color: HomeScreen.cpsTextGrey)),
                    Expanded(
                      child: Text(
                        feature.toString(),
                        style: GoogleFonts.montserrat(fontSize: 14, color: HomeScreen.cpsTextGrey, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildPricingAndOptionsSection(
      bool isLargeScreen, Map<String, dynamic> productData) {
    List<dynamic> storageOptions = productData['storageOptions'] ?? [];
    List<dynamic> colorOptions = productData['colorOptions'] ?? [];

    // Kiểm tra và cập nhật chỉ số hợp lệ
    if (storageOptions.isNotEmpty && _selectedStorageIndex >= storageOptions.length) {
      _selectedStorageIndex = 0;
    }
    if (colorOptions.isNotEmpty && _selectedColorIndex >= colorOptions.length) {
      _selectedColorIndex = 0;
    }

    // Xác định giá hiển thị
    String displayCurrentPrice = productData['currentPrice'] ?? 'N/A';
    if (storageOptions.isNotEmpty &&
        storageOptions.length > _selectedStorageIndex) {
      displayCurrentPrice =
          storageOptions[_selectedStorageIndex]['price'] ?? displayCurrentPrice;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phần chọn phiên bản
        if (storageOptions.isNotEmpty) ...[
          Text(
            'Chọn phiên bản:',
            style: GoogleFonts.montserrat(
              fontSize: 16, // Tăng kích thước chữ
              fontWeight: FontWeight.w700,
              color: HomeScreen.cpsTextBlack,
            ),
          ),
          const SizedBox(height: 12), // Tăng khoảng cách
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(storageOptions.length, (index) {
              bool isSelected = _selectedStorageIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ChoiceChip(
                  label: Text(
                    storageOptions[index]['label'],
                    style: GoogleFonts.montserrat(
                      fontSize: 14, // Tăng kích thước chữ
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? HomeScreen.themeBluePrimary
                          : HomeScreen.cpsTextBlack,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedStorageIndex = index;
                      });
                    }
                  },
                  selectedColor: HomeScreen.themeBluePrimary.withOpacity(0.15),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected
                          ? HomeScreen.themeBluePrimary
                          : HomeScreen.cpsCardBorderColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  labelPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: isSelected ? 2 : 0, // Thêm shadow khi chọn
                  pressElevation: 4,
                ),
              );
            }),
          ),
          const SizedBox(height: 20), // Tăng khoảng cách
        ],

        // Phần chọn màu sắc
        if (colorOptions.isNotEmpty &&
            _productDetail != null &&
            _productDetail!.variants.isNotEmpty) ...[
          Text(
            'Màu sắc:',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HomeScreen.cpsTextBlack,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(colorOptions.length, (index) {
              bool isSelected = _selectedColorIndex == index;
              var option = colorOptions[index];
              String imageUrl = option['image'] ?? 'assets/images/placeholder.png';

              return Semantics(
                label: 'Chọn màu ${option['name']}',
                child: InkWell(
                  onTap: () => setState(() {
                    _selectedColorIndex = index;
                    _selectedStorageIndex = index;
                    if (_productDetail != null &&
                        index < _productDetail!.variants.length &&
                        _productDetail!.variants[index].imageUrl != null) {
                      int mainImageIdx = _productDetail!
                          .getAllImageUrls()
                          .indexOf(_productDetail!.variants[index].imageUrl!);
                      if (mainImageIdx != -1) _selectedImageIndex = mainImageIdx;
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? HomeScreen.themeBluePrimary
                            : HomeScreen.cpsCardBorderColor,
                        width: isSelected ? 2.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: HomeScreen.themeBluePrimary.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        imageUrl.startsWith('http')
                            ? FadeInImage.memoryNetwork(
                          placeholder: kTransparentImage,
                          image: imageUrl,
                          width: 40, // Tăng kích thước ảnh
                          height: 40,
                          fit: BoxFit.contain,
                          imageErrorBuilder: (ctx, e, st) => Icon(
                            Icons.phone_android,
                            size: 40,
                            color: HomeScreen.cpsCardBorderColor,
                          ),
                        )
                            : Image.asset(
                          imageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, e, st) => Icon(
                            Icons.phone_android,
                            size: 40,
                            color: HomeScreen.cpsCardBorderColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option['name'],
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: HomeScreen.cpsTextBlack,
                              ),
                            ),
                            Text(
                              option['price'],
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: HomeScreen.themeBluePrimary,
                              ),
                            ),
                          ],
                        ),
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Icon(
                              Icons.check_circle,
                              color: HomeScreen.themeBluePrimary,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
        ],

        // Phần giá
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: HomeScreen.themeBluePrimary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: HomeScreen.themeBluePrimary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayCurrentPrice,
                style: GoogleFonts.montserrat(
                  fontSize: 26, // Tăng kích thước chữ
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (productData['oldPrice'] != null)
                Text(
                  productData['oldPrice'],
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.7),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Phần nút
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Semantics(
                label: 'Mua ngay sản phẩm',

                child:
                ElevatedButton(
                  onPressed: _isAddingToCart
                      ? null
                      : () async {
                    await _handleAddToCart(navigateToCart: true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeScreen.themeBluePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    disabledBackgroundColor: HomeScreen.themeBluePrimary.withOpacity(0.5),
                  ),
                  child: _isAddingToCart
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Text(
                    'MUA NGAY',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: Semantics(
                label: 'Thêm sản phẩm vào giỏ hàng',
                child:
                OutlinedButton.icon(
                  onPressed: _isAddingToCart ? null : () async {
                    await _handleAddToCart(navigateToCart: true); // Điều hướng để truyền currentPrice
                  },
                  icon: _isAddingToCart
                      ? Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 4),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(HomeScreen.themeBluePrimary),
                    ),
                  )
                      : Icon(
                    Icons.add_shopping_cart,
                    color: HomeScreen.themeBluePrimary,
                    size: 22,
                  ),
                  label: Text(
                    _isAddingToCart ? 'ĐANG THÊM' : 'Thêm vào giỏ',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: HomeScreen.themeBluePrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: HomeScreen.themeBluePrimary, width: 2),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledForegroundColor: HomeScreen.themeBluePrimary.withOpacity(0.5),
                    disabledMouseCursor: SystemMouseCursors.wait,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Phần khuyến mãi
        if (productData['promotions'] != null &&
            (productData['promotions'] as List).isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HomeScreen.themeBlueLight.withOpacity(0.3), // Màu nền nhẹ hơn
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.card_giftcard,
                      color: HomeScreen.themeBluePrimary,
                      size: 24, // Tăng kích thước biểu tượng
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Khuyến mãi',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: HomeScreen.cpsTextBlack,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...(productData['promotions'] as List<String>).map((promo) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎁 ',
                        style: GoogleFonts.montserrat(fontSize: 14),
                      ),
                      Expanded(
                        child: Text(
                          promo,
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: HomeScreen.cpsTextGrey,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductReviewsSection(Map<String, dynamic> productData, Map<String, dynamic> reviewSummary, List<Map<String, dynamic>> currentReviews) {
    if (_isLoadingReviews && _productReviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_reviewsError != null && _productReviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Center(
          child: Column(
            children: [
              Text(_reviewsError!, style: TextStyle(color: Colors.red)),
              ElevatedButton(onPressed: _fetchProductData, child: Text("Tải lại đánh giá"))
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HomeScreen.cpsCardBorderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReviewSummaryHeader(productData),
          const SizedBox(height: 20),
          _buildReviewOverallRating(reviewSummary),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          _buildCallToActionReview(),
          const SizedBox(height: 24),
          _buildReviewFilters(),
          const SizedBox(height: 20),
          _buildIndividualReviewsList(currentReviews),
        ],
      ),
    );
  }

  Widget _buildReviewSummaryHeader(Map<String, dynamic> productData) {
    return Text(
      'Đánh giá & nhận xét ${productData['productFullName'] ?? productData['name'] ?? 'Sản phẩm'}',
      style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: HomeScreen.cpsTextBlack),
    );
  }

  Widget _buildReviewOverallRating(Map<String, dynamic> reviewSummary) {
    List<int> distribution = List<int>.from(reviewSummary['starDistribution'] ?? [0,0,0,0,0]);
    int totalReviews = reviewSummary['totalReviews'] ?? 0;
    double averageRating = (reviewSummary['averageRating'] as num?)?.toDouble() ?? 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Text(
              '${averageRating.toStringAsFixed(1)}/5',
              style: GoogleFonts.montserrat(fontSize: 36, fontWeight: FontWeight.bold, color: HomeScreen.cpsTextBlack),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                return Icon(
                  index < averageRating.round() ? Icons.star : Icons.star_border,
                  color: HomeScreen.cpsStarYellow,
                  size: 20,
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(
              '$totalReviews đánh giá',
              style: GoogleFonts.montserrat(fontSize: 13, color: HomeScreen.themeBluePrimary, decoration: TextDecoration.underline),
            ),
          ],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: List.generate(5, (index) {
              int starValue = 5 - index;
              int count = distribution.length > index ? distribution[index] : 0;
              double percentage = totalReviews > 0 ? count / totalReviews : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Text('$starValue', style: GoogleFonts.montserrat(fontSize: 12, color: HomeScreen.cpsTextGrey)),
                    const SizedBox(width: 2),
                    Icon(Icons.star, color: HomeScreen.cpsStarYellow, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: HomeScreen.cpsCardBorderColor.withOpacity(0.5),
                        valueColor: AlwaysStoppedAnimation<Color>(HomeScreen.cpsStarYellow),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$count', style: GoogleFonts.montserrat(fontSize: 12, color: HomeScreen.cpsTextGrey)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCallToActionReview() {
    return Form(
      key: _reviewFormKey,
      child: Column(
        children: [
          Text(
            'Bạn đánh giá sao về sản phẩm này?',
            style: GoogleFonts.montserrat(fontSize: 14, color: HomeScreen.cpsTextBlack),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _currentReviewRating ? Icons.star : Icons.star_border,
                  color: HomeScreen.cpsStarYellow,
                ),
                onPressed: () {
                  setState(() {
                    _currentReviewRating = index + 1;
                  });
                },
              );
            }),
          ),
          TextFormField(
            controller: _reviewCommentController,
            decoration: InputDecoration(
              labelText: 'Viết nhận xét của bạn (tùy chọn)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeScreen.themeBluePrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              textStyle: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Gửi đánh giá'),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualReviewsList(List<Map<String, dynamic>> currentReviews) {
    List<Map<String, dynamic>> filteredReviews = currentReviews;
    if (_selectedReviewStarFilter != null) {
      filteredReviews = currentReviews.where((r) => r['rating'] == _selectedReviewStarFilter).toList();
    }

    if (filteredReviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Center(
          child: Text(
            _isLoadingReviews ? 'Đang tải đánh giá...' : 'Không có đánh giá nào phù hợp.',
            style: GoogleFonts.montserrat(fontSize: 14, color: HomeScreen.cpsTextGrey),
          ),
        ),
      );
    }

    return Column(
      children: filteredReviews.map((review) => _buildIndividualReviewItem(review)).toList(),
    );
  }

  Widget _buildIndividualReviewItem(Map<String, dynamic> review) {
    List<String> tags = List<String>.from(review['tags'] ?? []);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: (review['avatarColor'] as Color?) ?? HomeScreen.themeBluePrimary.withOpacity(0.2),
                child: Text(
                  review['avatarInitial'] ?? '?',
                  style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.bold, color: (review['avatarColor'] as Color?) != null ? Colors.white : HomeScreen.themeBluePrimary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['userName'] ?? 'Ẩn danh',
                      style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: HomeScreen.cpsTextBlack),
                    ),
                    Text(
                      review['date'] ?? '',
                      style: GoogleFonts.montserrat(fontSize: 12, color: HomeScreen.cpsTextGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < (review['rating'] as int? ?? 0) ? Icons.star : Icons.star_border,
                color: HomeScreen.cpsStarYellow,
                size: 16,
              );
            }),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: HomeScreen.cpsCardBorderColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.montserrat(fontSize: 11, color: HomeScreen.cpsTextBlack),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            review['comment'] ?? '',
            style: GoogleFonts.montserrat(fontSize: 14, color: HomeScreen.cpsTextGrey, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Divider(color: HomeScreen.cpsCardBorderColor, height: 1),
        ],
      ),
    );
  }

  Widget _breadcrumbItem(String text, {bool isCurrent = false}) {
    return Text(
      text,
      style: GoogleFonts.montserrat(
        fontSize: 13,
        color: isCurrent ? HomeScreen.cpsTextBlack : HomeScreen.cpsTextGrey,
        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _breadcrumbIcon() {
    return Icon(Icons.chevron_right, size: 16, color: HomeScreen.cpsTextGrey);
  }

  Widget _paymentLogo(String assetPath) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Image.asset(assetPath, height: 20, errorBuilder: (c,e,s) => SizedBox(width:30, child: Text("logo", style: TextStyle(fontSize: 8)))),
    );
  }

  Widget _buildSimilarProductsSection() {
    if (_isLoadingSimilarProducts && _similarProductsFromApi.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        height: 360 + 16 + 16 + 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SẢN PHẨM TƯƠNG TỰ",
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: HomeScreen.cpsTextBlack,
              ),
            ),
            const SizedBox(height: 16),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      );
    }

    if (_similarProductsError != null && _similarProductsFromApi.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        height: 360 + 16 + 16 + 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SẢN PHẨM TƯƠNG TỰ",
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: HomeScreen.cpsTextBlack,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: Center(child: Text(_similarProductsError!, style: TextStyle(color: Colors.red)))),
          ],
        ),
      );
    }

    if (!_isLoadingSimilarProducts && _similarProductsFromApi.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        height: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SẢN PHẨM TƯƠNG TỰ",
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: HomeScreen.cpsTextBlack,
              ),
            ),
            const SizedBox(height: 16),
            Center(child: Text("Không tìm thấy sản phẩm tương tự.", style: TextStyle(color: HomeScreen.cpsTextGrey))),
          ],
        ),
      );
    }

    bool potentiallyScrollable = _similarProductsFromApi.length > (MediaQuery.of(context).size.width / (180 + 12));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "SẢN PHẨM TƯƠNG TỰ",
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: HomeScreen.cpsTextBlack,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 360,
                child: ListView.builder(
                  controller: _similarProductsScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: _similarProductsFromApi.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: index == _similarProductsFromApi.length - 1 ? 0 : 12),
                      child: _buildSimilarProductCard(_similarProductsFromApi[index]),
                    );
                  },
                ),
              ),
              if (_showSimilarLeftArrow && potentiallyScrollable)
                Positioned(
                  left: 0,
                  child: _buildScrollArrow(
                    icon: Icons.chevron_left,
                    onPressed: () => _scrollSimilarProducts(false),
                  ),
                ),
              if (_showSimilarRightArrow && potentiallyScrollable)
                Positioned(
                  right: 0,
                  child: _buildScrollArrow(
                    icon: Icons.chevron_right,
                    onPressed: () => _scrollSimilarProducts(true),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarProductCard(ProductListItem p) {
    String? imagePath = p.thumbnailUrl;
    double basePriceNum = double.tryParse(p.basePrice) ?? 0.0;
    String currentPriceStr = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(basePriceNum);
    String? oldPriceStr;
    String discountText = '';

    if (p.discount != null && p.discount!.isActive) {
      double discountPercentNum = double.tryParse(p.discount!.discountPercent) ?? 0.0;
      if (discountPercentNum > 0) {
        double discountedPrice = basePriceNum * (1 - (discountPercentNum / 100));
        currentPriceStr = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(discountedPrice);
        oldPriceStr = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(basePriceNum);
        discountText = 'Giảm ${p.discount!.discountPercent}%';
      }
    }

    String installmentText = "Trả góp 0%";
    String promotionText = "";
    int ratingStars = 0;

    void navigateToProductDetail(int productId) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailsScreen2(productId: productId),
        ),
      );
    }

    return InkWell(
      onTap: () => navigateToProductDetail(p.productId),
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HomeScreen.cpsCardBorderColor.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                  child: (imagePath != null && imagePath.isNotEmpty)
                      ? Image.asset(
                      imagePath,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        print("Lỗi tải similar product asset: $imagePath - $error");
                        return Image.asset(
                            'assets/images/placeholder_product_fallback.png',
                            height: 150, width: double.infinity, fit: BoxFit.contain);
                      })
                      : Image.asset(
                    'assets/images/placeholder_product_fallback.png',
                    height: 150, width: double.infinity, fit: BoxFit.contain,
                  ),
                ),
                if (discountText.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: HomeScreen.themeBluePrimary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        discountText,
                        style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (installmentText.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: HomeScreen.cpsInstallmentBlue),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        installmentText,
                        style: GoogleFonts.montserrat(fontSize: 10, color: HomeScreen.cpsInstallmentBlue, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: GoogleFonts.montserrat(fontSize: 13.5, color: HomeScreen.cpsTextBlack, fontWeight: FontWeight.w600, height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              currentPriceStr,
                              style: GoogleFonts.montserrat(fontSize: 14.5, color: HomeScreen.themeBluePrimary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            if (oldPriceStr != null)
                              Text(
                                oldPriceStr,
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: HomeScreen.cpsTextGrey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (promotionText.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: HomeScreen.themePageBackground,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              promotionText,
                              style: GoogleFonts.montserrat(fontSize: 9.5, color: HomeScreen.cpsTextBlack.withOpacity(0.8)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (ratingStars == 0) Text("Chưa có đánh giá", style: GoogleFonts.montserrat(fontSize: 10, color: HomeScreen.cpsTextGrey)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildScrollArrow({required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.white.withOpacity(0.85),
      shape: const CircleBorder(),
      elevation: 3.0,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(6.0),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: HomeScreen.themeBluePrimary,
            size: 28.0,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewFilters() {
    final primaryFilters = ['Tất cả', 'Có hình ảnh', 'Đã mua hàng'];
    final starFilters = [5, 4, 3, 2, 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lọc theo',
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, color: HomeScreen.cpsTextBlack),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(primaryFilters.length, (index) {
            return ChoiceChip(
              label: Text(primaryFilters[index]),
              selected: _selectedReviewPrimaryFilter == index,
              onSelected: (selected) {
                if (selected) setState(() => _selectedReviewPrimaryFilter = index);
              },
              labelStyle: GoogleFonts.montserrat(
                fontSize: 13,
                color: _selectedReviewPrimaryFilter == index ? Colors.white : HomeScreen.cpsTextBlack,
                fontWeight: FontWeight.w500,
              ),
              selectedColor: HomeScreen.themeBluePrimary,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: _selectedReviewPrimaryFilter == index ? HomeScreen.themeBluePrimary : HomeScreen.cpsCardBorderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            );
          }),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: starFilters.map((stars) {
            bool isSelected = _selectedReviewStarFilter == stars;
            return ChoiceChip(
              avatar: Icon(Icons.star, size: 16, color: isSelected ? Colors.white : HomeScreen.cpsStarYellow),
              label: Text('$stars'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedReviewStarFilter = stars;
                  } else if (_selectedReviewStarFilter == stars) {
                    _selectedReviewStarFilter = null;
                  }
                });
              },
              labelStyle: GoogleFonts.montserrat(
                fontSize: 13,
                color: isSelected ? Colors.white : HomeScreen.cpsTextBlack,
                fontWeight: FontWeight.w500,
              ),
              selectedColor: HomeScreen.themeBluePrimary,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? HomeScreen.themeBluePrimary : HomeScreen.cpsCardBorderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFixedChatButton() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
        label: Text(
          'Chat với nhân viên tư vấn',
          style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: HomeScreen.themeBluePrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return Positioned(
      bottom: 80,
      right: 16,
      child: FloatingActionButton(
        onPressed: () {
          print("Scroll to top pressed");
        },
        mini: true,
        backgroundColor: HomeScreen.themeBluePrimary.withOpacity(0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 18),
            Text("Lên đầu", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 7)),
          ],
        ),
        elevation: 4,
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final isLocalAsset = imageUrl.startsWith('assets/');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: isLocalAsset
            ? Image.asset(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 100, color: Colors.white);
          },
        )
            : FadeInImage.memoryNetwork(
          placeholder: kTransparentImage,
          image: imageUrl,
          fit: BoxFit.contain,
          imageErrorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 100, color: Colors.white);
          },
        ),
      ),
    );
  }
}