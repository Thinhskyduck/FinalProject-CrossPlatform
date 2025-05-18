
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:intl/intl.dart';
import '../models/product_list_item_model.dart';
import '../services/api_service.dart';
import '../screens/product_detail.dart';

class _HeaderColors {
  static const Color themeBluePrimary = Color(0xFF007BFF);
  static const Color themeBlueDark = Color(0xFF0056b3);
  static const Color cpsTextBlack = Color(0xFF222222);
  static const Color cpsSubtleTextGrey = Color(0xFF757575);
  static const Color cpsCardBorderColor = Color(0xFFE0E0E0);
}

class CustomHeader extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? currentUserData;
  final int cartItemCount;
  final VoidCallback? onCartPressed;
  final VoidCallback? onAccountPressed;
  final Function(Map<String, dynamic>)? onCategorySelected;
  final VoidCallback? onLogoTap;
  final Function(String)? onSearchSubmitted;

  const CustomHeader({
    super.key,
    required this.categories,
    this.currentUserData,
    this.cartItemCount = 0,
    this.onCartPressed,
    this.onAccountPressed,
    this.onCategorySelected,
    this.onLogoTap,
    this.onSearchSubmitted,
  });

  @override
  State<CustomHeader> createState() => _CustomHeaderState();
}

String? mapThumbnailToLocal(String url) {
  // Example: Map network URL to local asset path
  // You should adjust this logic to fit your asset naming and structure
  if (url.isEmpty) return null;
  // Example: if url contains a filename, map to assets/images/filename
  final uri = Uri.parse(url);
  final filename = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : url;
  return 'assets/images/$filename';
}

class _CustomHeaderState extends State<CustomHeader> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<ProductListItem> _searchSuggestions = [];
  bool _isLoadingSuggestions = false;
  String _lastQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<List<ProductListItem>> _fetchSuggestions(String query) async {
    if (query.trim().isEmpty || query == _lastQuery) {
      print('No fetch needed: query is empty or same as last query ($_lastQuery)');
      return _searchSuggestions;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _isLoadingSuggestions = true;
        _lastQuery = query;
      });

      try {
        final products = await _apiService.fetchProductSuggestions(query.trim(), limit: 5);
        print('Fetched ${products.length} suggestions for query "$query": ${products.map((p) => p.name).join(', ')}');
        setState(() {
          _searchSuggestions = products;
          _isLoadingSuggestions = false;
        });
      } catch (e) {
        print('Error in _fetchSuggestions: $e');
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    });

    return _searchSuggestions;
  }

  String _calculateSalePrice(ProductListItem product) {
    if (product.discount == null || !product.discount!.isActive) {
      return NumberFormat("#,##0₫", "vi_VN").format(double.parse(product.basePrice));
    }
    double basePrice = double.parse(product.basePrice);
    double discountedPrice = basePrice * (1 - (double.parse(product.discount!.discountPercent.toString()) / 100));
    return NumberFormat("#,##0₫", "vi_VN").format(discountedPrice);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 950;
    final bool isMediumScreen = screenWidth > 650;

    final bool isLoggedIn = widget.currentUserData != null &&
        widget.currentUserData!['full_name'] != null &&
        (widget.currentUserData!['full_name'] as String).isNotEmpty;

    String accountTooltipText = "Tài khoản";
    String accountDisplayText = "";
    if (isLoggedIn) {
      String fullName = widget.currentUserData!['full_name'] as String;
      accountTooltipText = fullName;
      if (isLargeScreen) {
        List<String> nameParts = fullName.split(' ');
        String nameToShow = nameParts.isNotEmpty ? nameParts.last : fullName;
        if (nameToShow.length > 10) {
          accountDisplayText = "${nameToShow.substring(0, 8)}...";
        } else {
          accountDisplayText = nameToShow;
        }
      }
    } else {
      if (isLargeScreen) accountDisplayText = "Tài khoản";
    }

    return Container(
      decoration: BoxDecoration(
        color: _HeaderColors.themeBluePrimary,
        border: Border(bottom: BorderSide(color: _HeaderColors.themeBlueDark.withOpacity(0.5), width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: kIsWeb ? (isLargeScreen ? screenWidth * 0.06 : screenWidth * 0.025) : 10,
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: widget.onLogoTap ?? () {
              if (Navigator.canPop(context)) {
                // Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: ShaderMask(
              shaderCallback: (Rect bounds) => const LinearGradient(
                colors: [Colors.white, Color(0xFFB3E5FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                'BlueStore',
                style: TextStyle(
                  fontSize: kIsWeb ? (isLargeScreen ? 28 : 22) : 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(0.25), offset: const Offset(1, 2), blurRadius: 3),
                  ],
                ),
              ),
            ),
          ),
          if (isMediumScreen || kIsWeb)
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: PopupMenuButton<Map<String, dynamic>>(
                onSelected: widget.onCategorySelected,
                tooltip: "Danh mục sản phẩm",
                itemBuilder: (BuildContext context) {
                  List<PopupMenuEntry<Map<String, dynamic>>> menuItems = [];
                  for (int i = 0; i < widget.categories.length; i++) {
                    final category = widget.categories[i];
                    menuItems.add(
                      PopupMenuItem<Map<String, dynamic>>(
                        value: category,
                        height: kIsWeb ? 48 : 42,
                        child: Row(
                          children: [
                            Icon(Icons.category_outlined, color: _HeaderColors.themeBluePrimary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                category['name']?.toString() ?? 'Danh mục',
                                style: TextStyle(
                                  color: _HeaderColors.cpsTextBlack,
                                  fontSize: kIsWeb ? 14 : 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, color: _HeaderColors.cpsSubtleTextGrey.withOpacity(0.8), size: 12),
                          ],
                        ),
                      ),
                    );
                    if (i < widget.categories.length - 1) menuItems.add(const PopupMenuDivider(height: 0.5));
                  }
                  return menuItems;
                },
                color: Colors.white,
                elevation: 7,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: _HeaderColors.cpsCardBorderColor.withOpacity(0.4), width: 0.5),
                ),
                offset: const Offset(0, 42),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 7.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_rounded, color: Colors.white, size: kIsWeb ? 22 : 20),
                      const SizedBox(width: 5),
                      if (isLargeScreen)
                        Text(
                          'Danh mục',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: kIsWeb ? 13 : 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            shadows: [Shadow(color: Colors.black.withOpacity(0.15), offset: const Offset(0.5, 0.5), blurRadius: 1)],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          if (isMediumScreen || kIsWeb)
            Expanded(
              flex: isLargeScreen ? 3 : 2,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: isLargeScreen ? 20 : 10),
                constraints: BoxConstraints(maxWidth: isLargeScreen ? 550 : 280),
                height: kIsWeb ? 34 : 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 2.5, offset: const Offset(0, 1)),
                  ],
                ),
                child: RawAutocomplete<ProductListItem>(
                  textEditingController: _searchController,
                  focusNode: _searchFocusNode,
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) {
                      print('optionsBuilder: Empty query, returning []');
                      return [];
                    }
                    return await _fetchSuggestions(textEditingValue.text);
                  },
                  onSelected: (ProductListItem product) {
                    print('Selected product: ${product.name}, ID: ${product.productId}');
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProductDetailsScreen2(productId: int.parse(product.productId.toString()))),
                    );
                    _searchController.clear();
                    _searchSuggestions.clear();
                    _searchFocusNode.unfocus();
                  },
                  fieldViewBuilder: (BuildContext context, TextEditingController controller, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: TextStyle(fontSize: kIsWeb ? 13 : 11.5, color: _HeaderColors.cpsTextBlack),
                      decoration: InputDecoration(
                        hintText: "Tìm kiếm sản phẩm...",
                        hintStyle: TextStyle(fontSize: kIsWeb ? 12.5 : 11, color: _HeaderColors.cpsSubtleTextGrey.withOpacity(0.7)),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: _HeaderColors.cpsSubtleTextGrey, size: kIsWeb ? 17 : 15),
                        suffixIcon: _isLoadingSuggestions
                            ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(_HeaderColors.themeBluePrimary),
                                ),
                              )
                            : null,
                        contentPadding: EdgeInsets.only(left: 0, right: 10, top: kIsWeb ? 0 : 2, bottom: kIsWeb ? 0 : 9),
                      ),
                      onSubmitted: (value) {
                        print('Search submitted: $value');
                        if (widget.onSearchSubmitted != null) widget.onSearchSubmitted!(value);
                      },
                    );
                  },
                  optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<ProductListItem> onSelected, Iterable<ProductListItem> options) {
                    print('optionsViewBuilder: Displaying ${options.length} options');
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: isLargeScreen ? 550 : 280,
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: options.isEmpty && !_isLoadingSuggestions
                              ? const ListTile(title: Text('Không tìm thấy sản phẩm'))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.all(8),
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final product = options.elementAt(index);
                                    String salePrice = _calculateSalePrice(product);
                                    return ListTile(
                                      leading: product.thumbnailUrl != null
                                          ? Image.asset(
                                              mapThumbnailToLocal(product.thumbnailUrl!)!,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                print('Error loading image for ${product.name}: $error');
                                                return const Icon(Icons.image_not_supported);
                                              },
                                            )
                                          : const Icon(Icons.image_not_supported),
                                      title: Text(
                                        product.name,
                                        style: TextStyle(fontSize: kIsWeb ? 14 : 13, color: _HeaderColors.cpsTextBlack),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(salePrice, style: const TextStyle(color: Colors.redAccent)),
                                      onTap: () => onSelected(product),
                                    );
                                  },
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (isLargeScreen) const Spacer(flex: 1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!(isMediumScreen || kIsWeb))
                _HeaderActionWidget(
                  icon: Icons.search,
                  tooltip: "Tìm kiếm",
                  onPressed: () {
                    if (widget.onSearchSubmitted != null) showSearch(context: context, delegate: _AppSearchDelegate(widget.onSearchSubmitted!));
                  },
                  isLargeScreen: isLargeScreen,
                ),
              SizedBox(width: (isMediumScreen || kIsWeb) ? (isLargeScreen ? 10 : 6) : 4),
              _HeaderActionWidget(
                icon: Icons.shopping_cart_outlined,
                displayText: isLargeScreen ? "Giỏ hàng" : null,
                tooltip: "Giỏ hàng",
                onPressed: widget.onCartPressed ?? () {},
                itemCount: widget.cartItemCount,
                isLargeScreen: isLargeScreen,
              ),
              SizedBox(width: isLargeScreen ? 8 : 4),
              _HeaderActionWidget(
                icon: Icons.person_outline_rounded,
                displayText: accountDisplayText,
                tooltip: accountTooltipText,
                onPressed: widget.onAccountPressed ?? () {
                  print('Account button pressed');
                },
                isLargeScreen: isLargeScreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderActionWidget extends StatelessWidget {
  final IconData icon;
  final String? displayText;
  final String tooltip;
  final VoidCallback onPressed;
  final int itemCount;
  final bool isLargeScreen;

  const _HeaderActionWidget({
    required this.icon,
    this.displayText,
    required this.tooltip,
    required this.onPressed,
    this.itemCount = 0,
    required this.isLargeScreen,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconDisplay = Icon(icon, color: Colors.white, size: kIsWeb ? (isLargeScreen ? 22 : 20) : 19);
    bool showText = isLargeScreen && displayText != null && displayText!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        splashColor: _HeaderColors.themeBlueDark.withOpacity(0.35),
        highlightColor: _HeaderColors.themeBlueDark.withOpacity(0.25),
        child: Tooltip(
          message: tooltip,
          preferBelow: true,
          waitDuration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          textStyle: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w400),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 8 : 7, vertical: 7),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (showText)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      iconDisplay,
                      Padding(
                        padding: const EdgeInsets.only(top: 2.5),
                        child: Text(
                          displayText!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 9.2,
                            height: 1.0,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.05,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  iconDisplay,
                if (itemCount > 0 && icon == Icons.shopping_cart_outlined)
                  Positioned(
                    top: -4,
                    right: showText ? -7 : -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 0.8),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$itemCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppSearchDelegate extends SearchDelegate<String> {
  final Function(String) onSearchSubmittedCallback;
  final ApiService _apiService = ApiService();

  _AppSearchDelegate(this.onSearchSubmittedCallback);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: _HeaderColors.themeBluePrimary,
        iconTheme: theme.primaryIconTheme.copyWith(color: Colors.white),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 18),
        elevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, size: 20),
          tooltip: "Xóa",
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        )
      else
        const SizedBox.shrink(),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, size: 20),
      tooltip: "Quay lại",
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onSearchSubmittedCallback(query.trim());
        close(context, query.trim());
      });
    }
    return Center(
      child: query.trim().isEmpty
          ? const Text("Nhập từ khóa để tìm kiếm.")
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text("Đang tìm kiếm cho: \"$query\""),
              ],
            ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text("Nhập để xem gợi ý..."));
    }

    return FutureBuilder<List<ProductListItem>>(
      future: _apiService.fetchProductSuggestions(query.trim(), limit: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print('Error in buildSuggestions: ${snapshot.error}');
          return Center(child: Text("Lỗi tải gợi ý: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Không tìm thấy sản phẩm."));
        }

        final suggestions = snapshot.data!;
        print('buildSuggestions: Displaying ${suggestions.length} suggestions');
        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final product = suggestions[index];
            String salePrice = _calculateSalePrice(product);
            return ListTile(
              leading: product.thumbnailUrl != null
                  ? Image.asset(
                      mapThumbnailToLocal(product.thumbnailUrl!)!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading image for ${product.name}: $error');
                        return const Icon(Icons.image_not_supported);
                      },
                    )
                  : const Icon(Icons.image_not_supported),
              title: Text(
                product.name,
                style: TextStyle(fontSize: 15, color: _HeaderColors.cpsTextBlack),
              ),
              subtitle: Text(salePrice, style: const TextStyle(color: Colors.redAccent)),
              onTap: () {
                print('Tapped suggestion: ${product.name}, ID: ${product.productId}');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProductDetailsScreen2(productId: int.parse(product.productId.toString()))),
                );
                close(context, product.name);
              },
            );
          },
        );
      },
    );
  }
}

String _calculateSalePrice(ProductListItem product) {
  if (product.discount == null || !product.discount!.isActive) {
    return NumberFormat("#,##0₫", "vi_VN").format(double.parse(product.basePrice));
  }
  double basePrice = double.parse(product.basePrice);
  double discountedPrice = basePrice * (1 - (double.parse(product.discount!.discountPercent.toString()) / 100));
  return NumberFormat("#,##0₫", "vi_VN").format(discountedPrice);
}