import 'package:cross_platform_mobile_app_development/screens/product_detail.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:transparent_image/transparent_image.dart';

class ProductCatalog extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const ProductCatalog(
      {super.key, required this.categoryId, required this.categoryName});

  @override
  State<ProductCatalog> createState() => _ProductCatalogState();
}

class _ProductCatalogState extends State<ProductCatalog> {
  List<Map<String, dynamic>> _products = [];
  int _skip = 0;
  static const int _limit = 20;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  Timer? _debounce; // Timer cho debounce
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      print("--- WEB WARNING ---");
      print(
          "Make sure the API server (https://tteaqwe3g9.ap-southeast-1.awsapprunner.com)");
      print(
          "is configured with correct CORS headers (Access-Control-Allow-Origin)");
      print(
          "to allow requests from the domain where this Flutter web app is hosted.");
      print("Otherwise, API calls will fail in the browser.");
      print("--------------------");
    }
    _loadProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        !_isLoading &&
        _hasMore) {
      _loadProducts();
    }
  }

  Future<void> _loadProducts({bool isSearch = false}) async {
    if (_isLoading || (!_hasMore && !isSearch)) return;

    setState(() {
      _isLoading = true;
      if (_skip == 0 || isSearch) {
        _errorMessage = null;
        if (isSearch) {
          _products.clear();
          _skip = 0;
          _hasMore = true;
        }
      }
    });

    try {
      // Gọi API với _searchQuery
      final response = await http
          .get(
            Uri.parse(
                'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/products?skip=$_skip&limit=$_limit&category_id=${widget.categoryId}${_searchQuery.isNotEmpty ? '&search=${Uri.encodeComponent(_searchQuery)}' : ''}'),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> productsJson =
            jsonDecode(utf8.decode(response.bodyBytes));
        if (productsJson is List) {
          final newProducts = productsJson.cast<Map<String, dynamic>>();
          setState(() {
            // List<Map<String, dynamic>> productsToAdd = newProducts;
            // if (_searchQuery.isNotEmpty) {
            //   productsToAdd = newProducts.where((p) => _matchesSearch(p)).toList();
            // }
            if (isSearch)
              _products.clear(); // Xóa sản phẩm cũ nếu là tìm kiếm mới
            _products.addAll(newProducts);
            _skip += newProducts.length;
            _hasMore = newProducts.length == _limit;
            _isLoading = false;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _hasMore = false;
            _isLoading = false;
            if (_products.isEmpty) {
              _errorMessage = 'Received unexpected data format from server.';
            }
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _hasMore = false;
          _isLoading = false;
          if (_products.isEmpty) {
            _errorMessage =
                'Failed to load products (Code: ${response.statusCode}). Check CORS configuration if running on web.';
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasMore = false;
        _isLoading = false;
        if (_products.isEmpty) {
          _errorMessage =
              'An error occurred: ${e.toString()}. Check network connection and CORS if on web.';
        }
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      // Đợi 700ms sau khi người dùng ngừng gõ
      if (_searchQuery != query.trim()) {
        // Chỉ tìm khi query thực sự thay đổi
        setState(() {
          _searchQuery = query.trim();
          // Reset trạng thái phân trang và danh sách sản phẩm để bắt đầu tìm kiếm mới
          _products.clear();
          _skip = 0;
          _hasMore = true;
          _errorMessage = null;
          // Không set _isLoading ở đây, _loadProducts sẽ làm
        });
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
        _loadProducts(isSearch: true); // Gọi _loadProducts với cờ isSearch
      }
    });
  }

  bool _matchesSearch(Map<String, dynamic> product) {
    final name = product['name']?.toString().toLowerCase() ?? '';
    return name.contains(_searchQuery.toLowerCase());
  }

  // void _performSearch(String query) {
  //   final trimmedQuery = query.trim();
  //   if (_searchQuery == trimmedQuery) return;

  //   setState(() {
  //     _searchQuery = trimmedQuery;
  //     _products.clear();
  //     _skip = 0;
  //     _hasMore = true;
  //     _errorMessage = null;
  //     _isLoading = false;
  //   });
  //   if (_scrollController.hasClients) {
  //     _scrollController.jumpTo(0);
  //   }
  //   _loadProducts();
  // }

  String _getThumbnailUrl(dynamic thumbnailUrl) {
    const baseUrl = 'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com';
    if (thumbnailUrl is String &&
        thumbnailUrl.isNotEmpty &&
        thumbnailUrl != 'string') {
      // Nếu thumbnail_url là asset cục bộ (bắt đầu bằng 'assets/')
      if (thumbnailUrl.startsWith('assets/')) {
        return thumbnailUrl; // Trả về đường dẫn asset cục bộ
      }
      // Nếu là URL tuyệt đối (bắt đầu bằng http:// hoặc https://)
      if (Uri.tryParse(thumbnailUrl)?.isAbsolute ?? false) {
        return thumbnailUrl;
      }
      // Nếu là đường dẫn tương đối trên server
      return '$baseUrl/${thumbnailUrl.startsWith('/') ? thumbnailUrl.substring(1) : thumbnailUrl}';
    }
    return 'https://via.placeholder.com/300x300/F0F0F0/B0B0B0?text=No+Image';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 2.0,
      ),
      body: Column(
        children: [
          _buildSearchBar(theme),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 2;
                if (constraints.maxWidth >= 1200) {
                  crossAxisCount = 5;
                } else if (constraints.maxWidth >= 900) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth >= 600) {
                  crossAxisCount = 3;
                }

                double childAspectRatio = 0.65;
                if (crossAxisCount > 3) {
                  childAspectRatio = 0.75;
                } else if (crossAxisCount == 3) {
                  childAspectRatio = 0.7;
                }

                return _buildBodyContent(
                    theme, crossAxisCount, childAspectRatio);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    final Color searchBlueColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Tìm trong ${widget.categoryName}...',
          prefixIcon: Icon(Icons.search,
              color: theme.colorScheme.primary.withOpacity(0.8)),
          filled: true,
          fillColor: theme.colorScheme.surface.withOpacity(0.1),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: theme.hintColor),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged(
                        ''); // Kích hoạt tìm kiếm lại với query rỗng
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: searchBlueColor, width: 2.0),
          ),
          hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.7)),
        ),
        cursorColor: searchBlueColor,
        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      ),
    );
  }

  Widget _buildBodyContent(
      ThemeData theme, int crossAxisCount, double childAspectRatio) {
    if (_isLoading && _products.isEmpty && _errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _products.isEmpty) {
      String finalErrorMessage = _errorMessage!;
      if (kIsWeb &&
          (_errorMessage!.contains('Network error') ||
              _errorMessage!.contains('Failed host lookup') ||
              _errorMessage!.contains('SocketException') ||
              _errorMessage!.contains('CORS'))) {
        finalErrorMessage +=
            '\n\n(Running on Web? Check Browser Console (F12) for CORS errors. API server needs `Access-Control-Allow-Origin` header.)';
      }
      return _buildInfoMessage(
        icon: Icons.error_outline,
        message: finalErrorMessage,
        color: theme.colorScheme.error,
      );
    }

    if (!_isLoading && _products.isEmpty && _errorMessage == null) {
      return _buildInfoMessage(
        icon: Icons.search_off_rounded,
        message: _searchQuery.isEmpty
            ? 'No products found in ${widget.categoryName}.'
            : 'No products match your search "$_searchQuery".',
        color: theme.hintColor,
      );
    }

    return Scrollbar(
      thumbVisibility: kIsWeb,
      controller: _scrollController,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 32),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: _products.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _products.length) {
            return _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  )
                : const SizedBox.shrink();
          }
          final product = _products[index];
          return kIsWeb
              ? MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: _buildProductCard(product, theme),
                )
              : _buildProductCard(product, theme);
        },
      ),
    );
  }

  Widget _buildInfoMessage(
      {required IconData icon, required String message, required Color color}) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: color.withOpacity(0.8)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, ThemeData theme) {
    final basePrice =
        double.tryParse(product['base_price']?.toString() ?? '0.0') ?? 0.0;
    final productName = product['name']?.toString() ?? 'Unnamed Product';
    final thumbnailUrl = product['thumbnail_url'];
    final imageUrl = _getThumbnailUrl(thumbnailUrl);
    final productId =
        product['product_id'] as int; // Lấy product_id từ dữ liệu sản phẩm

    return GestureDetector(
      onTap: () {
        // Điều hướng đến ProductDetailsScreen khi nhấn vào sản phẩm
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => ProductDetailsScreen(productId: productId),
        //   ),
        // );
      },
      child: Card(
        elevation: 3.0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.grey[200],
                child: FadeInImage.memoryNetwork(
                  placeholder: kTransparentImage,
                  image: imageUrl,
                  fit: BoxFit.cover,
                  imageErrorBuilder: (context, error, stackTrace) =>
                      const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      productName,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '\$${basePrice.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
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
