import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'dart:math' as math;
import 'cart_product.dart';
import 'home_screen.dart';
import 'package:http/http.dart' as http;
import 'login.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ThemeData theme;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? currentUserData;
  final Function(int, String) onNavigateToCatalog;
  final VoidCallback onCartPressed;
  final VoidCallback onAccountPressed;

  const CustomAppBar({
    super.key,
    required this.theme,
    required this.categories,
    this.currentUserData,
    required this.onNavigateToCatalog,
    required this.onCartPressed,
    required this.onAccountPressed,
  });

  Widget _buildHeaderActionIcon({
    IconData? icon,
    String? avatarUrl,
    required String text,
    required VoidCallback onPressed,
    int itemCount = 0,
    bool isLargeScreen = false,
    required BuildContext context,
  }) {
    Widget iconWidget;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      iconWidget = CircleAvatar(
        radius: isLargeScreen ? 15 : 13,
        backgroundColor: Colors.white.withOpacity(0.8),
        backgroundImage: NetworkImage(avatarUrl),
      );
    } else if (icon != null) {
      iconWidget = Icon(icon,
          color: Colors.white, size: kIsWeb ? (isLargeScreen ? 22 : 20) : 19);
    } else {
      // Fallback for empty avatarUrl or no icon
      iconWidget = CircleAvatar(
        radius: isLargeScreen ? 15 : 13,
        backgroundColor: Colors.white.withOpacity(0.8),
        child: Icon(Icons.person_rounded,
            size: isLargeScreen ? 18 : 16, color: HomeScreen.themeBluePrimary),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        splashColor: HomeScreen.themeBlueDark.withOpacity(0.3),
        highlightColor: HomeScreen.themeBlueDark.withOpacity(0.2),
        child: Tooltip(
          message: text.isNotEmpty
              ? text.replaceAll("\n", " ")
              : (icon == Icons.shopping_cart_outlined
                  ? "Giỏ hàng"
                  : "Tài khoản"),
          preferBelow: true,
          child: Padding(
            padding: EdgeInsets.all(isLargeScreen ? 7.0 : 6.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    iconWidget,
                    if (text.isNotEmpty && isLargeScreen)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 9,
                              height: 1.05,
                              fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                if (itemCount > 0 && icon == Icons.shopping_cart_outlined)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                          color: HomeScreen.cpsStarYellow,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 0.5)),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$itemCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    bool isLargeScreen = screenWidth > 950;
    bool isMediumScreen = screenWidth > 650;

    final int cartItemCount = 0; // Example cart item count
    final bool isLoggedIn = currentUserData != null;
    final String? userAvatarUrl = currentUserData?['avatar_url'];
    final String userName =
        currentUserData?['full_name']?.split(' ').last ?? 'Tài khoản';

    return Container(
      decoration: BoxDecoration(
        color: HomeScreen.themeBluePrimary,
        border: Border(
            bottom: BorderSide(
                color: HomeScreen.themeBlueDark.withOpacity(0.5), width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: kIsWeb
            ? (isLargeScreen ? screenWidth * 0.06 : screenWidth * 0.025)
            : 10,
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const HomeScreen()), // Giả sử CartScreen đã được import
              );
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
                  color: Colors
                      .white, // This color is a base, ShaderMask applies the gradient.
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          if (isMediumScreen || kIsWeb)
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: PopupMenuButton<Map<String, dynamic>>(
                onSelected: (category) {
                  final int categoryId = category['category_id'] as int? ?? 0;
                  final String categoryName =
                      category['name'] as String? ?? 'Danh mục';
                  if (categoryId != 0) {
                    onNavigateToCatalog(categoryId, categoryName);
                  }
                },
                itemBuilder: (BuildContext context) {
                  if (categories.isEmpty) {
                    return <PopupMenuEntry<Map<String, dynamic>>>[
                      const PopupMenuItem<Map<String, dynamic>>(
                          enabled: false, child: Text('Không có danh mục')),
                    ];
                  }
                  return categories.map((Map<String, dynamic> category) {
                    return PopupMenuItem<Map<String, dynamic>>(
                      value: category,
                      child: Row(
                        children: [
                          Icon(Icons.category_outlined,
                              color: HomeScreen.themeBluePrimary, size: 20),
                          const SizedBox(width: 10),
                          Text(category['name'] ?? 'N/A'),
                        ],
                      ),
                    );
                  }).toList();
                },
                color: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                offset: const Offset(0, 45), // Offset below the button
                child: Padding(
                  padding: const EdgeInsets.all(7.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_rounded,
                          color: Colors.white, size: kIsWeb ? 24 : 22),
                      if (isLargeScreen) ...[
                        const SizedBox(width: 4),
                        const Text('Danh mục',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          if (isMediumScreen || kIsWeb)
            Expanded(
              flex: isLargeScreen ? 2 : 3,
              child: Container(
                constraints:
                    BoxConstraints(maxWidth: isLargeScreen ? 600 : 300),
                height: kIsWeb ? 36 : 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  style: TextStyle(
                      fontSize: kIsWeb ? 13.5 : 12,
                      color: HomeScreen.cpsTextBlack),
                  decoration: InputDecoration(
                    hintText: "Tìm sản phẩm...",
                    hintStyle: TextStyle(
                        fontSize: kIsWeb ? 13 : 11.5,
                        color: HomeScreen.cpsSubtleTextGrey),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search_rounded,
                        color: HomeScreen.cpsSubtleTextGrey,
                        size: kIsWeb ? 18 : 16),
                    contentPadding: EdgeInsets.symmetric(
                            vertical: kIsWeb ? 6 : 4, horizontal: 10)
                        .copyWith(
                            bottom: kIsWeb
                                ? 10
                                : 8), // Adjust for vertical centering
                  ),
                ),
              ),
            ),
          if (isLargeScreen) const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: (isMediumScreen || kIsWeb)
                      ? (isLargeScreen ? 15 : 8)
                      : 5),
              _buildHeaderActionIcon(
                context: context,
                icon: Icons.shopping_cart_outlined,
                text: isLargeScreen ? "Giỏ hàng" : "",
                onPressed: onCartPressed,
                itemCount: cartItemCount,
                isLargeScreen: isLargeScreen,
              ),
              SizedBox(width: isLargeScreen ? 10 : 5),
              _buildHeaderActionIcon(
                context: context,
                avatarUrl: isLoggedIn ? userAvatarUrl : null, // Pass avatar URL
                icon: isLoggedIn &&
                        (userAvatarUrl == null || userAvatarUrl.isEmpty)
                    ? Icons.person_outline_rounded
                    : (isLoggedIn
                        ? null
                        : Icons
                            .person_outline_rounded), // Show icon if no avatar or not logged in
                text:
                    isLargeScreen ? (isLoggedIn ? userName : "Tài khoản") : "",
                onPressed: onAccountPressed,
                isLargeScreen: isLargeScreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kIsWeb ? 60.0 : 55.0);
}

class ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;
  final double gapFraction;

  ProgressRingPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
    this.gapFraction = 0.12, // Default gap from previous example
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius =
        math.min(size.width / 2, size.height / 2) - strokeWidth / 2;
    Paint backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    Paint progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    double totalAngle = 2 * math.pi;
    double gapAngle = totalAngle * gapFraction;
    double arcAngleWithoutProgress = totalAngle - gapAngle;
    double sweepAngle = arcAngleWithoutProgress * progress;
    double startAngle = -math.pi / 2 + gapAngle / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      arcAngleWithoutProgress,
      false,
      backgroundPaint,
    );
    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gapFraction != gapFraction;
  }
}

const String _kUserUidKey = 'user_uid';
const String _kUserFullNameKey = 'user_fullName';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String _selectedSidebarItem = 'Trang chủ';
  static const String _localAvatarAssetPath =
      'assets/spidermen.jpg'; // Ensure this asset exists and path is correct in pubspec.yaml
  Map<String, dynamic>? _currentUserData;
  bool _isLoadingUser = true;
  String? _userErrorMessage;

  final List<Map<String, dynamic>> _categories = [
    {'category_id': 1, 'name': 'Điện thoại'},
    {'category_id': 2, 'name': 'Laptop'},
    {'category_id': 3, 'name': 'Phụ kiện'},
    {'category_id': 4, 'name': 'Máy tính bảng'},
  ];

  @override
  void initState() {
    super.initState();
    _initializePageAndFetchData();
  }

  Future<void> _initializePageAndFetchData() async {
    setState(() {
      _isLoadingUser = true;
      _userErrorMessage = null;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString(_kUserUidKey);
    final String? cachedFullName = prefs.getString(_kUserFullNameKey);

    if (userId == null || userId.isEmpty) {
      setState(() {
        _userErrorMessage = 'Vui lòng đăng nhập để xem thông tin tài khoản.';
        _isLoadingUser = false;
        _currentUserData = null;
      });
      return;
    }

    if (cachedFullName != null && cachedFullName.isNotEmpty) {
      setState(() {
        _currentUserData = {'full_name': cachedFullName};
      });
    } else {
      setState(() {
        _currentUserData = null;
      });
    }

    await _fetchUserDataFromApi(userId);
  }

  Future<void> _fetchUserDataFromApi(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/auth/users/me'),
        headers: {
          'accept': 'application/json',
          'X-User-ID': userId,
        },
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        setState(() {
          _currentUserData = data;
        });
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kUserFullNameKey, data['full_name'] ?? '');
      } else {
        setState(() {
          _userErrorMessage =
              'Lỗi tải thông tin người dùng: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _userErrorMessage = 'Lỗi kết nối: $e';
      });
    } finally {
      setState(() {
        _isLoadingUser = false;
      });
    }
  }

  void _onNavigateToCatalog(int categoryId, String categoryName) {
    print('Navigating to category: $categoryName (ID: $categoryId)');
    // Implement actual navigation e.g.
    // Navigator.push(context, MaterialPageRoute(builder: (context) => CatalogScreen(categoryId: categoryId, categoryName: categoryName)));
  }

  void _onCartPressed() {
    print('Cart pressed');
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const CartScreen()));
  }

  void _onAccountPressed() {
    print(
        'Account icon/name in AppBar pressed - Navigating to Account Info Form');
    if (_currentUserData != null) {
      setState(() {
        _selectedSidebarItem = 'Tài khoản của bạn';
      });
    } else {
      print(
          'Cannot navigate to account info, user data not loaded or not logged in.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        theme: Theme.of(context),
        categories: _categories,
        currentUserData: _currentUserData,
        onNavigateToCatalog: _onNavigateToCatalog,
        onCartPressed: _onCartPressed,
        onAccountPressed: _onAccountPressed,
      ),
      body: _isLoadingUser
          ? const Center(child: CircularProgressIndicator())
          : _userErrorMessage != null
              ? _buildErrorWidget()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSidebar(context),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 20),
                        child: _buildConditionalMainContent(context),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 60, color: HomeScreen.imageRedAccent.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            _userErrorMessage ?? 'Có lỗi xảy ra',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, color: HomeScreen.cpsSubtleTextGrey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializePageAndFetchData,
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeScreen.imageRedAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 250,
      height: double.infinity,
      color: HomeScreen.imagePageBackground,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarItem(context, Icons.home_outlined, 'Trang chủ'),
          _buildSidebarItem(
              context, Icons.list_alt_outlined, 'Lịch sử mua hàng'),
          _buildSidebarItem(context, Icons.person_outline, 'Tài khoản của bạn',
              badgeText: 'MỚI'),
          const Divider(
              height: 20,
              indent: 16,
              endIndent: 16,
              color: HomeScreen.cpsCardBorderColor),
          const Spacer(),
          _buildSidebarItem(context, Icons.logout_outlined, 'Đăng Xuất',
              isLogout: true),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, IconData icon, String title,
      {String? badgeText, bool isLogout = false}) {
    bool currentIsSelected = title == _selectedSidebarItem;
    Color itemColor = currentIsSelected
        ? HomeScreen.imageRedAccent
        : (isLogout ? HomeScreen.imageRedAccent : HomeScreen.cpsTextGrey);
    Color backgroundColor = currentIsSelected
        ? HomeScreen.imageLightRedBackground
        : Colors.transparent;
    FontWeight fontWeight =
        currentIsSelected ? FontWeight.bold : FontWeight.normal;

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () async {
          if (isLogout) {
            showDialog(
              context: context,
              builder: (alertDialogContext) => AlertDialog(
                title: const Text('Đăng xuất'),
                content: const Text(
                    'Bạn có chắc muốn đăng xuất và xóa tất cả dữ liệu đã lưu?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(alertDialogContext),
                      child: const Text('Hủy')),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(alertDialogContext);

                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      await prefs
                          .clear(); // Clears ALL data from SharedPreferences

                      setState(() {
                        _currentUserData = null;
                        _selectedSidebarItem = 'Trang chủ';
                        _userErrorMessage =
                            "Bạn đã đăng xuất. Vui lòng đăng nhập lại.";
                        _isLoadingUser = false;
                      });

                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Login()),
                          (Route<dynamic> route) => false,
                        );
                      }
                    },
                    child: const Text('Đăng xuất',
                        style: TextStyle(color: HomeScreen.imageRedAccent)),
                  ),
                ],
              ),
            );
          } else {
            if (title == 'Tài khoản của bạn' &&
                _currentUserData == null &&
                _userErrorMessage == null &&
                !_isLoadingUser) {
              print(
                  'Sidebar: Cannot select "$title", user data not available. Please log in or retry.');
              return;
            }
            setState(() {
              _selectedSidebarItem = title;
            });
            print('Sidebar: $title tapped');
          }
        },
        splashColor: HomeScreen.imageRedAccent.withOpacity(0.1),
        highlightColor: HomeScreen.imageRedAccent.withOpacity(0.05),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: currentIsSelected
                ? Border.all(color: HomeScreen.imageRedAccent.withOpacity(0.5))
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: itemColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      color: itemColor, fontSize: 14, fontWeight: fontWeight),
                ),
              ),
              if (badgeText != null) _buildBadge(badgeText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    Color badgeBgColor = (text == 'HOT' || text == 'MỚI')
        ? HomeScreen.imageRedAccent
        : HomeScreen.cpsStarYellow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeBgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildConditionalMainContent(BuildContext context) {
    if (_currentUserData == null) {
      return const Center(
          child: Text(
              'Không có thông tin người dùng. Vui lòng thử lại hoặc đăng nhập.',
              style: TextStyle(fontSize: 18)));
    }

    if (_selectedSidebarItem == 'Tài khoản của bạn') {
      return AccountInfoForm(
        localAvatarAssetPath: _localAvatarAssetPath,
        currentUserData: _currentUserData,
        onUpdateSuccess: _initializePageAndFetchData,
      );
    } else if (_selectedSidebarItem == 'Trang chủ') {
      return _buildHomePageContent(context);
    } else if (_selectedSidebarItem == 'Lịch sử mua hàng') {
      return OrderHistoryPageContent(
        localAvatarAssetPath: _localAvatarAssetPath,
        currentUserData: _currentUserData!,
      );
    }
    return Center(
        child: Text('Nội dung cho: $_selectedSidebarItem',
            style: const TextStyle(fontSize: 18)));
  }

  Widget _buildHomePageContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserInfoCard(context),
        const SizedBox(height: 20),
        _buildStatsSection(context),
        const SizedBox(height: 20),
        _buildUpdateBanner(context),
        const SizedBox(height: 24),
        _buildQuickActionsGrid(context),
      ],
    );
  }

  Widget _buildUserInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildProgressAvatarForHomePage(context,
              progress: (double.tryParse(
                          _currentUserData?['loyalty_points']?.toString() ??
                              '0') ??
                      0.0) /
                  100.0),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentUserData?['full_name'] ?? 'Người dùng',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: HomeScreen.cpsTextBlack),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tích lũy xét hạng: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(double.tryParse(_currentUserData?['total_spent']?.toString() ?? '0') ?? 0.0)}',
                  style: const TextStyle(
                      fontSize: 15,
                      color: HomeScreen.cpsTextBlack,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tính từ ngày ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(_currentUserData?['created_at']?.toString() ?? '') ?? DateTime.now())}',
                  style: const TextStyle(
                      fontSize: 13, color: HomeScreen.cpsSubtleTextGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressAvatarForHomePage(BuildContext context,
      {required double progress, String? assetPath}) {
    final double avatarActualRadius = 28;
    final double ringStrokeWidth = 6;
    final double painterRadius = avatarActualRadius + ringStrokeWidth / 2;
    final Color progressRingColor = const Color(0xFF1E88E5);
    final Color ringTrackColor = Colors.grey.shade200;

    String? effectiveAssetPath = assetPath;
    if (effectiveAssetPath == null || effectiveAssetPath.isEmpty) {
      effectiveAssetPath = _currentUserData?['avatar_url']?.toString();
    }
    if (effectiveAssetPath == null || effectiveAssetPath.isEmpty) {
      effectiveAssetPath = _localAvatarAssetPath;
    }

    ImageProvider? backgroundImage;
    if (effectiveAssetPath != null && effectiveAssetPath.isNotEmpty) {
      if (effectiveAssetPath.startsWith('http')) {
        backgroundImage = NetworkImage(effectiveAssetPath);
      } else {
        // Before using AssetImage, ensure the asset is declared in pubspec.yaml
        // and the path is correct e.g. 'assets/spidermen.jpg'
        try {
          backgroundImage = AssetImage(effectiveAssetPath);
        } catch (e) {
          print(
              "Error loading local asset for avatar: $e. Path: $effectiveAssetPath");
          backgroundImage = null; // Fallback if asset not found
        }
      }
    }

    return SizedBox(
      width: painterRadius * 2,
      height: painterRadius * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(painterRadius * 2, painterRadius * 2),
            painter: ProgressRingPainter(
              progress: progress.clamp(0.0, 1.0),
              progressColor: progressRingColor,
              backgroundColor: ringTrackColor,
              strokeWidth: ringStrokeWidth,
            ),
          ),
          CircleAvatar(
            radius: avatarActualRadius,
            backgroundColor: Colors.white,
            backgroundImage: backgroundImage,
            child: (backgroundImage == null)
                ? Icon(Icons.person,
                    size: avatarActualRadius * 0.8,
                    color: progressRingColor.withOpacity(0.7))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
              _currentUserData?['order_count']?.toString() ?? '0', 'đơn hàng'),
          Container(
              height: 40,
              width: 1,
              color: HomeScreen.cpsCardBorderColor,
              margin: const EdgeInsets.symmetric(horizontal: 8)),
          _buildStatItem(
              NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(
                  double.tryParse(
                          _currentUserData?['total_spent']?.toString() ??
                              '0') ??
                      0.0),
              'Tổng tiền tích lũy từ 01/01/2024'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: HomeScreen.cpsTextBlack)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  color: HomeScreen.cpsSubtleTextGrey,
                  height: 1.2)),
        ],
      ),
    );
  }

  Widget _buildUpdateBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: HomeScreen.imageUpdateBannerBlue,
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: HomeScreen.themeBluePrimary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Cập nhật thông tin cá nhân và địa chỉ để có trải nghiệm đặt hàng nhanh và thuận tiện hơn.',
              style: TextStyle(
                  fontSize: 13, color: HomeScreen.cpsTextBlack, height: 1.3),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              if (_currentUserData != null) {
                setState(() {
                  _selectedSidebarItem = 'Tài khoản của bạn';
                });
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              side: BorderSide(
                  color: HomeScreen.themeBluePrimary.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Cập nhật',
                style: TextStyle(
                    color: HomeScreen.themeBluePrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _buildQuickActionItem(
            context, Icons.receipt_long_outlined, 'Lịch sử mua hàng'),
        _buildQuickActionItem(context, Icons.location_on_outlined, 'Sổ địa chỉ',
            badgeText: 'MỚI'),
        _buildQuickActionItem(context, Icons.person, 'Tài khoản của bạn',
            badgeText: 'MỚI'),
      ],
    );
  }

  Widget _buildQuickActionItem(
      BuildContext context, IconData icon, String label,
      {String? badgeText}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (label == 'Sổ địa chỉ') {
              print(
                  'Quick Action: $label tapped - Implement navigation for Address Book');
              // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => const AddressBookPage()));
            } else if (_currentUserData != null ||
                (label != 'Tài khoản của bạn' && label != 'Sổ địa chỉ')) {
              // Allow Lịch sử mua hàng even if user data is briefly null
              setState(() {
                _selectedSidebarItem = label;
              });
              print('Quick Action: $label tapped');
            } else {
              print(
                  'Quick Action: Cannot select "$label", user data not available. Please log in.');
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                      color: HomeScreen.imageLightRedBackground,
                      shape: BoxShape.circle),
                  child: Icon(icon, size: 24, color: HomeScreen.imageRedAccent),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12,
                            color: HomeScreen.cpsTextBlack,
                            fontWeight: FontWeight.w500,
                            height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 4),
                      _buildBadge(badgeText)
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AccountInfoForm extends StatefulWidget {
  final String localAvatarAssetPath;
  final Map<String, dynamic>? currentUserData;
  final VoidCallback? onUpdateSuccess;

  const AccountInfoForm({
    super.key,
    required this.localAvatarAssetPath,
    this.currentUserData,
    this.onUpdateSuccess,
  });

  @override
  State<AccountInfoForm> createState() => _AccountInfoFormState();
}

class _AccountInfoFormState extends State<AccountInfoForm> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _resetEmailController = TextEditingController();
  bool _isUpdating = false;
  String? _updateError;
  String _selectedSidebarItem = 'Trang chủ';
  bool _isEditingName = false;
  bool _isEditingPhone = false;
  bool _isEditingAddress = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController.text = widget.currentUserData?['full_name'] ?? '';
    _emailController.text = widget.currentUserData?['email'] ?? '';
    _phoneController.text = widget.currentUserData?['phone_number'] ?? '';
    _addressController.text = widget.currentUserData?['shipping_address'] ??
        'Chưa có địa chỉ mặc định';
    _resetEmailController.text = widget.currentUserData?['email'] ?? '';
  }

  Future<void> _updateUserInfo() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập họ và tên')));
      return;
    }
    if (_phoneController.text.trim().isEmpty ||
        !RegExp(r'^\d{10}$').hasMatch(_phoneController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Số điện thoại không hợp lệ (10 chữ số)')));
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vui lòng nhập địa chỉ')));
      return;
    }

    setState(() {
      _isUpdating = true;
      _updateError = null;
    });

    try {
      final response = await http.put(
        Uri.parse(
            'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/auth/users/me'),
        headers: {
          'accept': 'application/json',
          'X-User-ID': widget.currentUserData?['user_id']?.toString() ?? '2',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'full_name': _nameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'shipping_address': _addressController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật thông tin thành công')));
        widget.onUpdateSuccess?.call();
      } else {
        setState(() {
          _updateError = 'Lỗi cập nhật: ${response.statusCode}';
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_updateError!)));
      }
    } catch (e) {
      setState(() {
        _updateError = 'Lỗi kết nối: $e';
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_updateError!)));
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  void _showResetPasswordConfirmationDialog() {
    if (_resetEmailController.text.trim().isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
            .hasMatch(_resetEmailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập email hợp lệ')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        title: const Text('Xác nhận yêu cầu reset mật khẩu',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        content: Text(
          'Bạn có chắc chắn muốn gửi yêu cầu reset mật khẩu tới email: ${_resetEmailController.text.trim()}?',
          style: const TextStyle(fontSize: 14, color: HomeScreen.cpsTextGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy',
                style: TextStyle(fontSize: 14, color: HomeScreen.cpsTextGrey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _requestPasswordReset();
            },
            child: const Text('Xác nhận',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HomeScreen.imageRedAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPasswordReset() async {
    // Kiểm tra email trước khi gửi (giữ nguyên)
    if (_resetEmailController.text.trim().isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
            .hasMatch(_resetEmailController.text.trim())) {
      if (mounted) {
        // Kiểm tra mounted trước khi dùng context
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng nhập email hợp lệ')));
      }
      return;
    }

    setState(() {
      _isUpdating =
          true; // Có thể đổi tên biến này thành _isSendingRequest hoặc tương tự
      _updateError = null; // Đảm bảo reset lỗi cũ
    });

    try {
      final response = await http
          .post(
            Uri.parse(
                'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/auth/password-reset'), // Đảm bảo URL đúng
            headers: {
              'accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'email': _resetEmailController.text.trim()}),
          )
          .timeout(const Duration(seconds: 15)); // Thêm timeout

      if (!mounted) return; // Kiểm tra mounted sau await

      // API của bạn trả về 202 cho thành công
      if (response.statusCode == 202) {
        // <<<< SỬA ĐIỀU KIỆN Ở ĐÂY
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Yêu cầu reset mật khẩu đã được gửi. Vui lòng kiểm tra email của bạn (bao gồm cả thư mục spam).'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5), // Tăng thời gian hiển thị
        ));
        // Không cần setState _selectedSidebarItem ở đây nữa
        // Người dùng có thể tự điều hướng nếu muốn sau khi thấy thông báo
      } else {
        // Xử lý các mã lỗi khác từ API
        String apiErrorMessage = 'Lỗi gửi yêu cầu reset mật khẩu.';
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorData is Map && errorData.containsKey('detail')) {
            apiErrorMessage = errorData['detail'].toString();
          } else if (errorData is Map && errorData.containsKey('message')) {
            // Một số API có thể trả về 'message'
            apiErrorMessage = errorData['message'].toString();
          } else {
            apiErrorMessage += ' (Code: ${response.statusCode})';
          }
        } catch (e) {
          // Nếu không parse được JSON, sử dụng response.body thô (đã decode UTF-8)
          apiErrorMessage +=
              ' Phản hồi không hợp lệ từ server: ${utf8.decode(response.bodyBytes)}';
        }
        setState(() {
          _updateError = apiErrorMessage;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_updateError!), backgroundColor: Colors.red));
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _updateError = 'Yêu cầu quá thời gian. Vui lòng thử lại.';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_updateError!), backgroundColor: Colors.orange));
    } on SocketException {
      // Xử lý lỗi mạng
      if (!mounted) return;
      setState(() {
        _updateError = 'Lỗi kết nối mạng. Vui lòng kiểm tra lại.';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_updateError!), backgroundColor: Colors.orange));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updateError = 'Lỗi không mong muốn: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_updateError!), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Widget _buildFormAvatar(BuildContext context) {
    final double avatarActualRadius = 36;
    return SizedBox(
      width: avatarActualRadius * 2,
      height: avatarActualRadius * 2,
      child: CircleAvatar(
        radius: avatarActualRadius,
        backgroundColor: HomeScreen.imageLightRedBackground,
        backgroundImage: (widget.localAvatarAssetPath.isNotEmpty)
            ? AssetImage(widget.localAvatarAssetPath)
            : null,
        child: (widget.localAvatarAssetPath.isEmpty)
            ? Icon(Icons.person,
                size: avatarActualRadius * 0.8,
                color: HomeScreen.imageRedAccent.withOpacity(0.7))
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color labelColor = HomeScreen.cpsSubtleTextGrey.withOpacity(0.9);
    final Color valueColor = HomeScreen.cpsTextBlack;
    final Color dividerColor = Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      decoration: const BoxDecoration(color: Colors.white),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    _buildFormAvatar(context),
                    const SizedBox(height: 10),
                    Text(
                      _nameController.text,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: HomeScreen.cpsTextBlack),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildInfoRow(context, 'Họ và tên:', _nameController, labelColor,
                  valueColor, dividerColor,
                  canEdit: true,
                  isEditing: _isEditingName,
                  onEdit: () => setState(() => _isEditingName = true)),
              _buildInfoRow(context, 'Số điện thoại:', _phoneController,
                  labelColor, valueColor, dividerColor,
                  canEdit: true,
                  isEditing: _isEditingPhone,
                  onEdit: () => setState(() => _isEditingPhone = true)),
              _buildInfoRow(context, 'Email:', _emailController, labelColor,
                  valueColor, dividerColor,
                  canEdit: false),
              _buildInfoRow(context, 'Địa chỉ:', _addressController, labelColor,
                  valueColor, dividerColor,
                  canEdit: true,
                  isEditing: _isEditingAddress,
                  onEdit: () => setState(() => _isEditingAddress = true)),
              _buildInfoRow(
                  context,
                  'Điểm thành viên:',
                  TextEditingController(
                      text: widget.currentUserData?['loyalty_points']
                              ?.toString() ??
                          '0'),
                  labelColor,
                  valueColor,
                  dividerColor,
                  canEdit: false),
              _buildInfoRow(
                  context,
                  'Ngày tạo tài khoản:',
                  TextEditingController(
                      text: DateFormat('dd/MM/yyyy').format(DateTime.parse(
                          widget.currentUserData?['created_at'] ??
                              DateTime.now().toString()))),
                  labelColor,
                  valueColor,
                  dividerColor,
                  canEdit: false),
              _buildInfoRow(context, 'Yêu cầu reset mật khẩu:',
                  _resetEmailController, labelColor, valueColor, dividerColor,
                  isAction: true, onEdit: _showResetPasswordConfirmationDialog),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isUpdating ? null : _updateUserInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeScreen.imageRedAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Cập nhật thông tin',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          if (_isUpdating)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context,
      String label,
      TextEditingController controller,
      Color labelColor,
      Color valueColor,
      Color dividerColor,
      {bool canEdit = false,
      bool isEditing = false,
      VoidCallback? onEdit,
      bool isAction = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(fontSize: 13.5, color: labelColor)),
              const SizedBox(width: 10),
              Expanded(
                child: isEditing
                    ? TextField(
                        controller: controller,
                        style: TextStyle(fontSize: 13.5, color: valueColor),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onSubmitted: (value) => setState(() {
                          if (label == 'Họ và tên:') _isEditingName = false;
                          if (label == 'Số điện thoại:')
                            _isEditingPhone = false;
                          if (label == 'Địa chỉ:') _isEditingAddress = false;
                        }),
                      )
                    : Text(
                        controller.text,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 13.5,
                            color: valueColor,
                            fontWeight:
                                isAction ? FontWeight.normal : FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              SizedBox(
                width: 40,
                child: (canEdit || isAction)
                    ? IconButton(
                        icon: Icon(Icons.edit_outlined,
                            size: 20,
                            color:
                                HomeScreen.cpsSubtleTextGrey.withOpacity(0.7)),
                        onPressed: onEdit,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: dividerColor, height: 1, thickness: 0.5),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }
}

class OrderHistoryPageContent extends StatefulWidget {
  final String localAvatarAssetPath;
  final Map<String, dynamic> currentUserData;

  const OrderHistoryPageContent({
    super.key,
    required this.localAvatarAssetPath,
    required this.currentUserData,
  });

  @override
  State<OrderHistoryPageContent> createState() =>
      _OrderHistoryPageContentState();
}

class _OrderHistoryPageContentState extends State<OrderHistoryPageContent>
    with SingleTickerProviderStateMixin {
  DateTimeRange? _selectedDateRange;
  late TabController _tabController;
  String _activeTab = 'Tất cả';
  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _skip = 0;
  final int _limit = 20;
  final Map<int, Map<String, dynamic>> _variantCache = {};
  List<Map<String, dynamic>> _allReturnRequests = [];
  final List<String> _orderStatusTabs = [
    'Tất cả',
    'Chờ xác nhận',
    'Đã xác nhận',
    'Đang vận chuyển',
    'Đã giao hàng',
    'Đã huỷ',
    'Hoàn trả',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 365)),
      end: DateTime.now(),
    );
    _tabController =
        TabController(length: _orderStatusTabs.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    // Initial fetch based on the default active tab (usually the first one)
    if (_orderStatusTabs.isNotEmpty && _orderStatusTabs[0] == 'Hoàn trả') {
      _fetchReturnRequests();
    } else {
      _fetchOrders();
    }
  }

  Future<void> _fetchReturnRequests({bool loadMore = false}) async {
    if (_isLoading) return; // Reuse existing _isLoading

    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _errorMessage = null; // Reuse existing _errorMessage
        _skip = 0; // Reuse existing _skip
        _allReturnRequests.clear();
      }
    });

    try {
      final userId = widget.currentUserData['user_id']?.toString() ?? '2';
      final uri = Uri.parse(
              'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/returns/requests')
          .replace(
        queryParameters: {
          'skip': _skip.toString(),
          'limit': _limit.toString(),
        },
      );

      final response = await http.get(uri, headers: {
        'accept': 'application/json',
        'X-User-ID': userId
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(decodedBody);
        // Assuming _mapApiReturnRequestToLocal will be created
        final newReturnRequests = data
            .map((returnData) => _mapApiReturnRequestToLocal(returnData))
            .toList();

        setState(() {
          if (loadMore) {
            _allReturnRequests.addAll(newReturnRequests);
          } else {
            _allReturnRequests = newReturnRequests;
          }
          _skip += newReturnRequests.length;
        });
      } else {
        setState(() {
          _errorMessage =
              'Không thể tải lịch sử hoàn trả. Mã lỗi: ${response.statusCode}';
        });
      }
    } on TimeoutException catch (_) {
      setState(() {
        _errorMessage = 'Kết nối timeout khi tải lịch sử hoàn trả.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi kết nối khi tải lịch sử hoàn trả: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _mapApiReturnRequestToLocal(
      Map<String, dynamic> apiReturnRequest) {
    final orderInfo = apiReturnRequest['order'] as Map<String, dynamic>? ?? {};
    final serialInfo =
        apiReturnRequest['serial_info'] as Map<String, dynamic>? ?? {};
    final variantInfo = serialInfo['variant'] as Map<String, dynamic>? ?? {};

    // Lấy lịch sử trạng thái của yêu cầu hoàn trả
    final List<dynamic> returnStatusHistoryRaw =
        apiReturnRequest['status_history'] as List<dynamic>? ?? [];
    final List<Map<String, String>> returnStatusHistory =
        returnStatusHistoryRaw.map((historyItem) {
      if (historyItem is Map<String, dynamic>) {
        return {
          'status': historyItem['status']?.toString() ?? 'unknown',
          'changed_at': historyItem['changed_at']?.toString() ??
              DateTime.now().toIso8601String(),
          // Thêm các trường khác từ historyItem nếu cần, ví dụ: 'notes'
          'notes': historyItem['notes']?.toString() ?? '',
        };
      }
      return {
        'status': 'error',
        'changed_at': DateTime.now().toIso8601String(),
        'notes': 'Dữ liệu lịch sử lỗi'
      };
    }).toList();

    String imageUrl = variantInfo['image_url'] != null &&
            (variantInfo['image_url'] as String).isNotEmpty
        ? 'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/${variantInfo['image_url']}'
        : 'assets/images/placeholder.png';

    return {
      'return_id': apiReturnRequest['return_id'],
      'return_code':
          apiReturnRequest['code'] ?? 'N/A-${apiReturnRequest['return_id']}',
      'order_code': orderInfo['order_code'] ?? 'N/A',
      'product_name': variantInfo['variant_name'] ?? 'Sản phẩm không xác định',
      'image_url': imageUrl,
      'reason': apiReturnRequest['reason'] ?? 'Không có lý do',
      'return_type': apiReturnRequest['return_type'] ?? 'N/A',
      'status': apiReturnRequest['status'] ?? 'N/A',
      'created_at': apiReturnRequest['created_at'] != null
          ? DateFormat('dd/MM/yyyy HH:mm')
              .format(DateTime.parse(apiReturnRequest['created_at']).toLocal())
          : 'Không xác định',
      'updated_at': apiReturnRequest['updated_at'] != null
          ? DateFormat('dd/MM/yyyy HH:mm')
              .format(DateTime.parse(apiReturnRequest['updated_at']).toLocal())
          : 'Không xác định',
      'status_history': returnStatusHistory, // LƯU LỊCH SỬ TRẠNG THÁI Ở ĐÂY
      'raw_data': apiReturnRequest,
    };
  }

  String _mapReturnStatusToVietnamese(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Chờ xử lý';
      case 'approved':
        return 'Đã chấp nhận';
      case 'rejected':
        return 'Đã từ chối';
      case 'processing':
        return 'Đang xử lý';
      case 'item_received':
        return 'Đã nhận hàng';
      case 'refunding':
        return 'Đang hoàn tiền';
      case 'received':
        return 'Đã nhận hàng từ khách hàng';
      case 'checking':
        return 'Đang kiểm tra sản phẩm';
      case 'exchanging':
        return 'Đang đổi hàng';
      case 'completed':
        return 'Đã hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  String _mapReturnTypeToVietnamese(String returnType) {
    switch (returnType.toLowerCase()) {
      case 'refund':
        return 'Hoàn tiền';
      case 'exchange':
        return 'Đổi hàng';
      default:
        return returnType;
    }
  }

  Widget _buildReturnStatusTag(String status) {
    Color bgColor;
    Color textColor;
    String statusText = _mapReturnStatusToVietnamese(status);

    switch (status.toLowerCase()) {
      case 'pending':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        break;
      case 'approved':
      case 'processing':
      case 'item_received':
      case 'refunding':
      case 'exchanging':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      case 'completed':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'rejected':
      case 'cancelled':
        bgColor = HomeScreen.imageRedAccent.withOpacity(0.1);
        textColor = HomeScreen.imageRedAccent;
        break;
      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusText,
        style: TextStyle(
            fontSize: 10.5,
            color: textColor,
            fontWeight: FontWeight.w500,
            fontFamily: 'Roboto'),
      ),
    );
  }

  Widget _buildReturnRequestItemCard(Map<String, dynamic> returnRequest) {
    // Lấy danh sách lịch sử trạng thái từ dữ liệu đã map
    final List<Map<String, String>> statusHistory =
        (returnRequest['status_history'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, String>)
            .toList();
    return Card(
      elevation: 2.0, // Tăng nhẹ độ nổi để tạo chiều sâu
      margin: const EdgeInsets.symmetric(
          vertical: 8.0, horizontal: 16.0), // Thêm margin ngang cho cân đối
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0)), // Bo góc mềm mại hơn
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Tăng padding cho thoáng hơn
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hình ảnh sản phẩm
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    color: HomeScreen.imagePageBackground,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    image: DecorationImage(
                      image: returnRequest['image_url'] != null &&
                              (returnRequest['image_url'] as String)
                                  .startsWith('http')
                          ? NetworkImage(returnRequest['image_url'])
                          : const AssetImage('assets/images/placeholder.png')
                              as ImageProvider,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Thông tin chính
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yêu cầu Hoàn trả: #${returnRequest['return_code']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: HomeScreen.cpsSubtleTextGrey.withOpacity(0.8),
                          fontFamily: 'Roboto',
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        returnRequest['product_name'] ?? 'Tên sản phẩm',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HomeScreen.cpsTextBlack,
                          height: 1.2,
                          fontFamily: 'Roboto',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lý do: ${returnRequest['reason']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: HomeScreen.cpsTextGrey.withOpacity(0.9),
                          fontFamily: 'Roboto',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      _buildReturnStatusTag(returnRequest['status'] ?? 'N/A'),
                    ],
                  ),
                ),
                // Ngày tạo
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    returnRequest['created_at'] ?? 'Không xác định',
                    style: TextStyle(
                      fontSize: 12,
                      color: HomeScreen.cpsSubtleTextGrey.withOpacity(0.7),
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Loại yêu cầu và nút chi tiết
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Loại: ${_mapReturnTypeToVietnamese(returnRequest['return_type'] ?? 'N/A')}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                    color: (returnRequest['return_type'] ?? '') == 'refund'
                        ? Colors.orange.shade700
                        : Colors.blue.shade700,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0)),
                        title: Text(
                          'Chi tiết YC Hoàn Trả #${returnRequest['return_code']}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _buildDetailRowDialog('Mã đơn hàng gốc:',
                                  returnRequest['order_code'] ?? 'N/A'),
                              _buildDetailRowDialog('Sản phẩm:',
                                  returnRequest['product_name'] ?? 'N/A'),
                              _buildDetailRowDialog(
                                  'Lý do:', returnRequest['reason'] ?? 'N/A'),
                              _buildDetailRowDialog(
                                  'Loại yêu cầu:',
                                  _mapReturnTypeToVietnamese(
                                      returnRequest['return_type'] ?? 'N/A')),
                              _buildDetailRowDialog(
                                  'Trạng thái hiện tại:',
                                  _mapReturnStatusToVietnamese(
                                      returnRequest['status'] ?? 'N/A')),
                              _buildDetailRowDialog('Ngày tạo:',
                                  returnRequest['created_at'] ?? 'N/A'),
                              _buildDetailRowDialog('Cập nhật lần cuối:',
                                  returnRequest['updated_at'] ?? 'N/A'),
                              const SizedBox(height: 12),
                              Text(
                                'Lịch sử trạng thái:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: HomeScreen.cpsTextBlack,
                                ),
                              ),
                              const Divider(height: 20),
                              if (statusHistory.isEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    'Không có lịch sử trạng thái.',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13),
                                  ),
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: statusHistory.map((history) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _mapReturnStatusToVietnamese(
                                                  history['status']!),
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                          Text(
                                            history['changed_at'] != null
                                                ? DateFormat('dd/MM/yy HH:mm')
                                                    .format(DateTime.parse(
                                                            history[
                                                                'changed_at']!)
                                                        .toLocal())
                                                : 'N/A',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text(
                              'Đóng',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: HomeScreen
                        .imageRedAccent, // Nút nổi bật hơn với màu chính
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0)),
                    elevation: 1.0,
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Xem chi tiết'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Hàm helper để build các dòng chi tiết trong Dialog
  Widget _buildDetailRowDialog(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: HomeScreen.cpsTextBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchOrders({bool loadMore = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _errorMessage = null;
        _skip = 0;
        _allOrders.clear();
      }
    });

    try {
      final userId = widget.currentUserData['user_id']?.toString() ?? '2';
      final status =
          _activeTab == 'Tất cả' ? null : _mapStatusToApi(_activeTab);
      final uri = Uri.parse(
              'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/orders')
          .replace(
        queryParameters: {
          'skip': _skip.toString(),
          'limit': _limit.toString(),
          if (status != null) 'status': status,
        },
      );

      final response = await http.get(uri, headers: {
        'accept': 'application/json',
        'X-User-ID': userId
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(decodedBody);
        final newOrders = await Future.wait(
          data.map((order) async => await _mapApiOrderToLocal(order)).toList(),
        );
        setState(() {
          if (loadMore) {
            _allOrders.addAll(newOrders);
          } else {
            _allOrders = newOrders;
          }
          _skip += newOrders.length;
          _filterOrders();
        });
      } else {
        setState(() {
          _errorMessage =
              'Không thể tải đơn hàng. Mã lỗi: ${response.statusCode}';
        });
      }
    } on TimeoutException catch (_) {
      setState(() {
        _errorMessage = 'Kết nối timeout. Vui lòng thử lại.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi kết nối: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _mapApiOrderToLocal(
      Map<String, dynamic> apiOrder) async {
    final items = (apiOrder['items'] as List<dynamic>?) ?? [];
    final firstItem = items.isNotEmpty ? items[0] : null;
    final extraItemsCount = items.length > 1 ? items.length - 1 : 0;
    final statusHistory = (apiOrder['status_history'] as List<dynamic>?)
            ?.map((h) => (h['status'] as String?) ?? 'unknown')
            .toList() ??
        [];

    String variantName = 'Sản phẩm không xác định';
    String imageUrl = 'assets/images/placeholder.png';
    if (firstItem != null && firstItem['variant_id'] != null) {
      final variantId = firstItem['variant_id'] as int;
      final variantData = await _fetchVariantDetails(variantId);
      if (variantData != null) {
        variantName = variantData['product_name'] ?? 'Sản phẩm không xác định';
        imageUrl = variantData['image_url'] != null
            ? 'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/${variantData['image_url']}'
            : 'assets/images/placeholder.png';
      }
    }

    return {
      'id': apiOrder['order_code']?.toString() ??
          'DH${apiOrder['order_id'] ?? 'unknown'}',
      'image': imageUrl,
      'name': variantName,
      'extra_items':
          extraItemsCount > 0 ? 'và $extraItemsCount sản phẩm khác' : null,
      'status_tags': statusHistory,
      'price': NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(
        double.tryParse(apiOrder['total_amount']?.toString() ?? '0') ?? 0,
      ),
      'date': apiOrder['ordered_at'] != null
          ? DateFormat('dd/MM/yyyy HH:mm')
              .format(DateTime.parse(apiOrder['ordered_at']))
          : 'Không xác định',
      'actions': _getOrderActions(apiOrder['status'] ?? 'unknown'),
      'category': _mapApiStatusToCategory(apiOrder['status'] ?? 'unknown'),
      'items': items, // Lưu trữ tất cả sản phẩm
      'raw_data': apiOrder, // Lưu trữ toàn bộ dữ liệu đơn hàng
    };
  }

  Future<Map<String, dynamic>?> _fetchVariantDetails(int variantId) async {
    if (_variantCache.containsKey(variantId)) {
      return _variantCache[variantId];
    }

    try {
      final response = await http.get(
        Uri.parse(
            'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/variants/$variantId/price'),
        headers: {
          'accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final variantData = jsonDecode(decodedBody);
        _variantCache[variantId] = variantData;
        return variantData;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String? _mapStatusToApi(String tab) {
    switch (tab) {
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
      case 'Hoàn trả':
        return 'ReturnedToSender';
      default:
        return null;
    }
  }

  List<String> _getOrderActions(String status) {
    switch (status) {
      case 'Pending':
        return ['Xem chi tiết'];
      case 'Confirmed':
      case 'Shipping':
        return ['Xem chi tiết'];
      case 'Completed':
        return ['Xem chi tiết'];
      case 'Cancelled':
      case 'ReturnedToSender':
        return ['Xem chi tiết'];
      default:
        return ['Xem chi tiết'];
    }
  }

  String _mapApiStatusToCategory(String status) {
    switch (status) {
      case 'Pending':
        return 'Chờ xác nhận';
      case 'Confirmed':
        return 'Đã xác nhận';
      case 'Shipping':
        return 'Đang vận chuyển';
      case 'Completed':
        return 'Đã giao hàng';
      case 'Cancelled':
        return 'Đã huỷ';
      case 'ReturnedToSender':
        return 'Hoàn trả';
      default:
        return 'Tất cả';
    }
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging && mounted) {
      // Check if mounted
      setState(() {
        _activeTab = _orderStatusTabs[_tabController.index];
        // Reset skip for the new tab's data
        _skip = 0;
        if (_activeTab == 'Hoàn trả') {
          _fetchReturnRequests();
        } else {
          _fetchOrders();
        }
      });
    }
  }

  void _filterOrders() {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    _filteredOrders = _allOrders.where((order) {
      bool matchesDate = true;
      if (_selectedDateRange != null && order['date'] != null) {
        try {
          final orderDate = dateFormat.parse(order['date']);
          matchesDate = orderDate.isAfter(_selectedDateRange!.start
                  .subtract(const Duration(days: 1))) &&
              orderDate.isBefore(
                  _selectedDateRange!.end.add(const Duration(days: 1)));
        } catch (e) {
          matchesDate = false;
        }
      }
      return matchesDate;
    }).toList();
    setState(() {});
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: HomeScreen.imageRedAccent,
              onPrimary: Colors.white,
              onSurface: HomeScreen.cpsTextBlack,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: HomeScreen.imageRedAccent,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
        _filterOrders();
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // Đã cập nhật
        if (_activeTab == 'Hoàn trả') {
          await _fetchReturnRequests();
        } else {
          await _fetchOrders();
        }
      },
      child: SingleChildScrollView(
        child: Container(
          color: Colors.white, // Hoặc màu nền bạn muốn
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserInfoSection(),
              _buildOrderStatsSection(),
              _buildDateFilterAndTabs(),

              // PHẦN HIỂN THỊ DANH SÁCH ĐÃ ĐƯỢC CẬP NHẬT
              if (_errorMessage != null &&
                  (_activeTab == 'Hoàn trả'
                      ? _allReturnRequests.isEmpty
                      : _filteredOrders.isEmpty))
                _buildErrorWidget()
              else
                _buildListContent(),
              // KẾT THÚC PHẦN HIỂN THỊ DANH SÁCH ĐÃ CẬP NHẬT
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoSection() {
    String phoneNumber =
        widget.currentUserData['phone_number']?.toString() ?? '03*****957';
    return Padding(
      padding: const EdgeInsets.all(16.0).copyWith(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: widget.localAvatarAssetPath.isNotEmpty
                ? AssetImage(widget.localAvatarAssetPath)
                : null,
            backgroundColor: HomeScreen.imageLightRedBackground,
            child: widget.localAvatarAssetPath.isEmpty
                ? const Icon(Icons.person, color: HomeScreen.imageRedAccent)
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.currentUserData['full_name']?.toString() ?? 'Người dùng',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: HomeScreen.cpsTextBlack,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    phoneNumber,
                    style: const TextStyle(
                      fontSize: 13,
                      color: HomeScreen.cpsSubtleTextGrey,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.visibility_outlined,
                      size: 16, color: HomeScreen.cpsSubtleTextGrey),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatsSection() {
    String totalOrders = _allOrders.length.toString();
    String totalAccumulated =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(
      _allOrders.fold(
        0.0,
        (sum, order) =>
            sum +
            (double.tryParse(
                    order['price']?.replaceAll('đ', '').replaceAll('.', '') ??
                        '0') ??
                0),
      ),
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: HomeScreen.imagePageBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItemSmall(totalOrders, "đơn hàng"),
          Container(height: 30, width: 1, color: HomeScreen.cpsCardBorderColor),
          _buildStatItemSmall(
              totalAccumulated, "Tổng tiền tích lũy từ 01/01/2024"),
        ],
      ),
    );
  }

  Widget _buildStatItemSmall(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: HomeScreen.cpsTextBlack,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: HomeScreen.cpsSubtleTextGrey,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }

  Widget _buildDateFilterAndTabs() {
    String formattedDateRange = _selectedDateRange != null
        ? "${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}"
        : "Chọn khoảng ngày";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          InkWell(
            onTap: () => _selectDateRange(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: HomeScreen.cpsCardBorderColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        formattedDateRange,
                        style: const TextStyle(
                          fontSize: 13,
                          color: HomeScreen.cpsTextBlack,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_drop_down,
                      color: HomeScreen.cpsSubtleTextGrey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: HomeScreen.imageRedAccent,
              unselectedLabelColor: HomeScreen.cpsTextGrey,
              indicatorColor: HomeScreen.imageRedAccent,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Roboto'),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.normal,
                  fontFamily: 'Roboto'),
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: _orderStatusTabs.map((label) => Tab(text: label)).toList(),
            ),
          ),
          const Divider(
              height: 1, color: HomeScreen.cpsCardBorderColor, thickness: 0.5),
        ],
      ),
    );
  }

  Widget _buildEmptyList() {
    bool isReturnTab = _activeTab == 'Hoàn trả';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isReturnTab
                  ? Icons.assignment_return_outlined
                  : Icons.receipt_long_outlined,
              size: 60,
              color: HomeScreen.cpsSubtleTextGrey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isReturnTab
                  ? "Không có yêu cầu hoàn trả nào"
                  : "Không có đơn hàng nào",
              style: const TextStyle(
                  fontSize: 16,
                  color: HomeScreen.cpsSubtleTextGrey,
                  fontFamily: 'Roboto'),
            ),
            if (!isReturnTab && _activeTab != "Tất cả")
              Text(
                "trong mục '${_activeTab.toLowerCase()}'",
                style: const TextStyle(
                    fontSize: 14,
                    color: HomeScreen.cpsSubtleTextGrey,
                    fontFamily: 'Roboto'),
              ),
          ],
        ),
      ),
    );
  }

  // Modify _buildErrorWidget to use the correct fetch method on retry
  @override
  Widget _buildErrorWidget() {
    // Make sure this is the one used in the build method
    bool isReturnTab = _activeTab == 'Hoàn trả';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 60, color: HomeScreen.imageRedAccent.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? "Có lỗi xảy ra",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  color: HomeScreen.cpsSubtleTextGrey,
                  fontFamily: 'Roboto'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (isReturnTab) {
                  _fetchReturnRequests();
                } else {
                  _fetchOrders();
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: HomeScreen.imageRedAccent,
                  foregroundColor: Colors.white),
              child:
                  const Text('Thử lại', style: TextStyle(fontFamily: 'Roboto')),
            ),
          ],
        ),
      ),
    );
  }

  // New _buildListContent method
  Widget _buildListContent() {
    final bool isReturnTab = _activeTab == 'Hoàn trả';
    final items = isReturnTab ? _allReturnRequests : _filteredOrders;
    final itemCount = items.length +
        (_isLoading && items.length >= _skip
            ? 1
            : 0); // Show loader if loading more

    if (_isLoading && items.isEmpty) {
      // Initial load
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator()));
    }
    // _errorMessage is already handled by the main build structure now if you prefer
    if (items.isEmpty && !_isLoading) {
      // Done loading, but no items
      return _buildEmptyList();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!_isLoading &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200 &&
            (isReturnTab ? _allReturnRequests.length : _allOrders.length) >=
                _skip) {
          // Check correct list length for pagination
          if (isReturnTab) {
            _fetchReturnRequests(loadMore: true);
          } else {
            _fetchOrders(loadMore: true);
          }
        }
        return false;
      },
      child: ListView.builder(
        shrinkWrap: true, // Important if inside another SingleChildScrollView
        physics:
            const NeverScrollableScrollPhysics(), // Important if inside another SingleChildScrollView
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == items.length && _isLoading) {
            // Loader at the bottom for load more
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator()));
          }
          if (index >= items.length)
            return const SizedBox
                .shrink(); // Should not happen if itemCount is correct

          final itemData = items[index];
          return isReturnTab
              ? _buildReturnRequestItemCard(itemData)
              : _buildOrderItemCard(itemData);
        },
      ),
    );
  }

  Widget _buildOrderItemCard(Map<String, dynamic> order) {
    // status_tags này là danh sách lịch sử trạng thái từ apiOrder['status_history']
    List<String> statusTagsFromOrderHistory =
        List<String>.from(order['status_tags'] ?? []);

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: HomeScreen.imagePageBackground,
                    image: DecorationImage(
                      image: order['image'] != null && order['image'].isNotEmpty
                          ? AssetImage(order['image'])
                          : const AssetImage('assets/images/placeholder.png')
                              as ImageProvider,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['name'] ?? 'Tên sản phẩm',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: HomeScreen.cpsTextBlack,
                          height: 1.3,
                          fontFamily: 'Roboto',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (order['extra_items'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3.0),
                          child: Text(
                            order['extra_items'],
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: HomeScreen.cpsSubtleTextGrey,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      // CHỈ HIỂN THỊ CÁC THẺ LỊCH SỬ TRẠNG THÁI KHI Ở TAB "Hoàn trả"
                      if (_activeTab == 'Hoàn trả' &&
                          statusTagsFromOrderHistory.isNotEmpty)
                        Wrap(
                          spacing: 6.0,
                          runSpacing: 4.0,
                          // Sử dụng statusTagsFromOrderHistory để tạo các thẻ
                          children: statusTagsFromOrderHistory
                              .map((tag) => _buildOrderStatusTag(tag))
                              .toList(),
                        )
                      // Nếu không phải tab "Hoàn trả", hoặc tab "Hoàn trả" nhưng không có lịch sử trạng thái,
                      // thì không hiển thị cụm thẻ này.
                      // Bạn có thể cân nhắc hiển thị trạng thái chính của đơn hàng ở đây nếu muốn,
                      // ví dụ: else { _buildOrderStatusTag(order['raw_data']?['status'] ?? 'unknown'); }
                      // nhưng theo yêu cầu là "không hiển thị", nên để trống.
                    ],
                  ),
                ),
                Text(
                  order['date'] ?? 'Không xác định',
                  style: const TextStyle(
                    fontSize: 11,
                    color: HomeScreen.cpsSubtleTextGrey,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order['price'] ?? '0đ',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: HomeScreen.imageRedAccent,
                    fontFamily: 'Roboto',
                  ),
                ),
                Row(
                  children: (order['actions'] as List<String>? ?? [])
                      .map((actionText) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: OutlinedButton(
                        onPressed: () {
                          if (actionText == 'Xem chi tiết') {
                            final String orderCode =
                                order['raw_data']?['order_code']?.toString() ??
                                    order['id'] ??
                                    'unknown';
                            final int? orderIdNumeric =
                                order['raw_data']?['order_id'] as int?;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderDetailsPage(
                                  orderCode: orderCode,
                                  orderIdNumeric: orderIdNumeric,
                                  orderData: order['raw_data'],
                                ),
                              ),
                            );
                          } else {
                            print('$actionText cho đơn ${order['id']}');
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HomeScreen.imageRedAccent,
                          side: BorderSide(
                              color:
                                  HomeScreen.imageRedAccent.withOpacity(0.7)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Roboto',
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          minimumSize: const Size(0, 28),
                        ),
                        child: Text(
                          actionText,
                          style: const TextStyle(fontFamily: 'Roboto'),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusTag(String tagText) {
    Color tagBgColor;
    Color tagTextColor;

    if (tagText.toLowerCase().contains('cancelled') ||
        tagText.toLowerCase().contains('returned')) {
      tagBgColor = HomeScreen.imageRedAccent.withOpacity(0.1);
      tagTextColor = HomeScreen.imageRedAccent;
    } else if (tagText.toLowerCase().contains('completed') ||
        tagText.toLowerCase().contains('confirmed')) {
      tagBgColor = Colors.green.shade50;
      tagTextColor = Colors.green.shade700;
    } else if (tagText.toLowerCase().contains('shipping')) {
      tagBgColor = Colors.blue.shade50;
      tagTextColor = Colors.blue.shade700;
    } else {
      tagBgColor = HomeScreen.cpsSubtleTextGrey.withOpacity(0.1);
      tagTextColor = HomeScreen.cpsSubtleTextGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tagBgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _mapStatusTagToVietnamese(tagText),
        style: TextStyle(
          fontSize: 10.5,
          color: tagTextColor,
          fontWeight: FontWeight.w500,
          fontFamily: 'Roboto',
        ),
      ),
    );
  }

  String _mapStatusTagToVietnamese(String tag) {
    switch (tag) {
      case 'Pending':
        return 'Chờ xác nhận';
      case 'Confirmed':
        return 'Đã xác nhận';
      case 'Shipping':
        return 'Đang vận chuyển';
      case 'Completed':
        return 'Đã giao hàng';
      case 'Cancelled':
        return 'Đã huỷ';
      case 'ReturnedToSender':
        return 'Hoàn trả';
      default:
        return tag;
    }
  }
}

class OrderDetailsPage extends StatefulWidget {
  final String orderCode; // Đổi tên từ orderId thành orderCode để rõ ràng hơn
  final int?
      orderIdNumeric; // Thêm order_id dạng số nếu có thể truyền từ trang trước
  final Map<String, dynamic>? orderData; // Dữ liệu đơn hàng có thể đã có sẵn

  const OrderDetailsPage({
    super.key,
    required this.orderCode, // Bắt buộc phải có order_code
    this.orderIdNumeric, // order_id dạng số có thể có hoặc không
    this.orderData,
  });

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  Map<String, dynamic>? _orderData;
  bool _isLoading = true;
  String? _errorMessage;
  int? _currentOrderIdNumeric; // Lưu order_id (integer) để sử dụng

  @override
  void initState() {
    super.initState();
    if (widget.orderData != null) {
      _orderData = widget.orderData;
      // Cố gắng lấy order_id (int) từ widget.orderData nếu có
      _currentOrderIdNumeric = widget.orderData!['order_id'] as int?;
      if (_currentOrderIdNumeric != null) {
        // Nếu đã có orderData và order_id (int), kiểm tra xem có sold_serials không
        // Nếu không có, có thể fetch lại bằng order_id (int) để đảm bảo
        final items = _orderData!['items'] as List<dynamic>? ?? [];
        bool hasSoldSerials = items.isNotEmpty &&
            items.any((item) =>
                item['sold_serials'] != null &&
                (item['sold_serials'] as List).isNotEmpty);

        if (hasSoldSerials) {
          print(
              'OrderData (from props) contains sold_serials for order_id: $_currentOrderIdNumeric');
          _isLoading = false;
        } else {
          print(
              'OrderData (from props) for order_id: $_currentOrderIdNumeric DOES NOT have sold_serials. Refetching by order_id (int).');
          _fetchOrderDetailsByNumericId(
              _currentOrderIdNumeric!); // Fetch lại để có sold_serials
        }
      } else {
        // widget.orderData có nhưng không có order_id (int) -> lỗi logic truyền dữ liệu
        print(
            'Error: widget.orderData exists but missing order_id (int). Fetching by order_code.');
        _fetchOrderDetailsByOrderCode();
      }
    } else if (widget.orderIdNumeric != null) {
      // Có order_id (int) truyền vào, fetch trực tiếp bằng nó
      _currentOrderIdNumeric = widget.orderIdNumeric;
      print(
          'Fetching order details by numeric order_id (from props): $_currentOrderIdNumeric');
      _fetchOrderDetailsByNumericId(_currentOrderIdNumeric!);
    } else {
      // Chỉ có order_code, cần fetch theo order_code trước để lấy order_id (int)
      print(
          'Fetching order details by order_code (from props): ${widget.orderCode}');
      _fetchOrderDetailsByOrderCode();
    }
  }

  // Hàm fetch theo order_code để lấy order_id (int), sau đó fetch theo order_id (int)
  Future<void> _fetchOrderDetailsByOrderCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final uriGetId = Uri.parse(
          'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/orders?order_code=${widget.orderCode}');
      final responseGetId = await http.get(
        uriGetId,
        headers: {
          'accept': 'application/json',
          'X-User-ID': _orderData?['user_id']?.toString() ??
              '2', // Lấy User-ID từ _orderData nếu có, hoặc mặc định
        },
      ).timeout(const Duration(seconds: 15));

      if (responseGetId.statusCode == 200) {
        final List<dynamic> data =
            jsonDecode(utf8.decode(responseGetId.bodyBytes));
        if (data.isNotEmpty && data[0]['order_id'] != null) {
          _currentOrderIdNumeric = data[0]['order_id'] as int;
          print(
              'Successfully fetched order_id (int): $_currentOrderIdNumeric using order_code. Now fetching full details.');
          // Gọi hàm fetch bằng order_id (int) vừa lấy được
          await _fetchOrderDetailsByNumericId(_currentOrderIdNumeric!);
        } else {
          setState(() {
            _errorMessage =
                'Không tìm thấy đơn hàng với mã: ${widget.orderCode} hoặc thiếu order_id.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage =
              'Lỗi tải thông tin ban đầu: ${responseGetId.statusCode}';
          _isLoading = false;
        });
      }
    } on TimeoutException catch (_) {
      setState(() {
        _errorMessage = 'Timeout khi tải thông tin ban đầu.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi kết nối (tải thông tin ban đầu): $e';
        _isLoading = false;
      });
    }
  }

  // Hàm fetch chi tiết đơn hàng bằng order_id (integer) - API này sẽ trả về sold_serials
  Future<void> _fetchOrderDetailsByNumericId(int numericOrderId) async {
    // Nếu chưa ở trạng thái loading, thì set
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final uri = Uri.parse(
          'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/orders/$numericOrderId');
      final response = await http.get(
        uri,
        headers: {
          'accept': 'application/json',
          'X-User-ID': _orderData?['user_id']?.toString() ??
              widget.orderData?['user_id']?.toString() ??
              '2', // Ưu tiên User-ID từ _orderData
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(response.bodyBytes));
        print(
            'Successfully fetched full order details for order_id: $numericOrderId. Data includes sold_serials.');
        setState(() {
          _orderData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Lỗi tải chi tiết đơn hàng ($numericOrderId): ${response.statusCode}';
          _isLoading = false;
        });
      }
    } on TimeoutException catch (_) {
      setState(() {
        _errorMessage = 'Timeout khi tải chi tiết đơn hàng ($numericOrderId).';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Lỗi kết nối (tải chi tiết đơn hàng $numericOrderId): $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Hiển thị order_code trên AppBar
        title: Text(
            'Chi tiết đơn hàng #${_orderData?['order_code'] ?? widget.orderCode}'),
        backgroundColor: HomeScreen.imageRedAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget() // _buildErrorWidget đã có nút thử lại, có thể cần điều chỉnh action của nút thử lại
              : _orderData == null
                  ? Center(
                      child: Text('Không có dữ liệu đơn hàng.',
                          style:
                              TextStyle(color: HomeScreen.cpsSubtleTextGrey)))
                  : _buildOrderDetails(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 60, color: HomeScreen.imageRedAccent.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Có lỗi xảy ra',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, color: HomeScreen.cpsSubtleTextGrey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Quyết định hàm fetch nào sẽ gọi lại dựa trên thông tin có sẵn
              if (_currentOrderIdNumeric != null) {
                _fetchOrderDetailsByNumericId(_currentOrderIdNumeric!);
              } else {
                _fetchOrderDetailsByOrderCode();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeScreen.imageRedAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails() {
    final items = _orderData!['items'] as List<dynamic>? ?? [];
    final statusHistory = _orderData!['status_history'] as List<dynamic>? ?? [];
    final invoice = _orderData!['invoice'];
    final loyaltyPointsUsed =
        int.tryParse(_orderData!['loyalty_points_used']?.toString() ?? '0') ??
            0;
    final loyaltyPointsDiscountAmount = loyaltyPointsUsed * 1000.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Thông tin đơn hàng'),
          Card(
            elevation: 1.5,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                      'Mã đơn hàng', _orderData!['order_code'] ?? 'N/A'),
                  _buildInfoRow(
                    'Ngày đặt hàng',
                    _orderData!['ordered_at'] != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(
                            DateTime.parse(_orderData!['ordered_at']).toLocal())
                        : 'N/A',
                  ),
                  _buildInfoRow('Phương thức thanh toán',
                      _orderData!['payment_method'] ?? 'N/A'),
                  // _buildInfoRow('Tổng tiền sản phẩm', _orderData!['subtotal'] ?? '0'),
                  // _buildInfoRow('Giảm giá', '-${_orderData!['coupon_discount_amount'] ?? '0'}'),
                  // _buildInfoRow('Phí giao hàng', _orderData!['shipping_fee'] ?? '0'),

                  _buildInfoRow(
                    'Tổng tiền sản phẩm',
                    NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(
                        double.tryParse(
                                _orderData!['subtotal']?.toString() ?? '0') ??
                            0),
                  ),
                  _buildInfoRow(
                    'Giảm giá',
                    NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(
                        double.tryParse(_orderData!['coupon_discount_amount']
                                    ?.toString() ??
                                '0') ??
                            0),
                  ),
                  _buildInfoRow(
                    'Phí giao hàng',
                    NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(
                        double.tryParse(
                                _orderData!['shipping_fee']?.toString() ??
                                    '0') ??
                            0),
                  ),
                  _buildInfoRow(
                    'Số tiền giảm điểm thưởng',
                    NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(
                        double.tryParse(
                                loyaltyPointsDiscountAmount.toString()) ??
                            0),
                  ),
                  // _buildInfoRow('Số tiền giảm điểm thưởng', '-' + loyaltyPointsDiscountAmount.toString() ),
                  _buildInfoRow(
                    'Phải thanh toán',
                    NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(
                        double.tryParse(
                                _orderData!['total_amount']?.toString() ??
                                    '0') ??
                            0),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('Sản phẩm'),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Không có sản phẩm trong đơn hàng',
                style: TextStyle(
                    fontSize: 14, color: HomeScreen.cpsSubtleTextGrey),
              ),
            )
          else
            ...items.map((item) => _buildItemCard(item)).toList(),
          const SizedBox(height: 16),
          _buildSectionTitle('Lịch sử trạng thái'),
          Card(
            elevation: 1.5,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: statusHistory
                    .map((status) => _buildStatusRow(status))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (invoice != null) ...[
            _buildSectionTitle('Hóa đơn'),
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                        'Mã hóa đơn', invoice['invoice_number'] ?? 'N/A'),
                    _buildInfoRow(
                      'Ngày xuất',
                      invoice['issued_at'] != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(
                              DateTime.parse(invoice['issued_at']).toLocal())
                          : 'N/A',
                    ),
                    _buildInfoRow(
                      'Tổng thuế',
                      NumberFormat.currency(locale: 'vi_VN', symbol: 'đ')
                          .format(double.tryParse(
                                  invoice['tax_amount']?.toString() ?? '0') ??
                              0),
                    ),
                    _buildInfoRow(
                      'Tổng tiền',
                      NumberFormat.currency(locale: 'vi_VN', symbol: 'đ')
                          .format(double.tryParse(
                                  invoice['total_amount']?.toString() ?? '0') ??
                              0),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: HomeScreen.cpsTextBlack),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14, color: HomeScreen.cpsSubtleTextGrey)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: HomeScreen.cpsTextBlack)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final variant = item['variant'] as Map<String, dynamic>? ?? {};
    final imageUrl = variant['image_url'] != null
        ? 'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/${variant['image_url']}'
        : 'assets/images/placeholder.png';

    final status = _orderData!['status']?.toString() ?? '';
    final orderedAt = _orderData!['ordered_at'] != null
        ? DateTime.tryParse(_orderData!['ordered_at'].toString())?.toLocal() ??
            DateTime.now()
        : DateTime.now();
    final currentDate = DateTime.now(); // 10:07 AM +07, 14/05/2025
    final difference = currentDate.difference(orderedAt).inDays;
    bool canReturn = status == 'Completed' && difference <= 30;

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: HomeScreen.imagePageBackground,
                image: DecorationImage(
                  image: imageUrl.startsWith('http')
                      ? NetworkImage(imageUrl)
                      : const AssetImage('assets/images/placeholder.png')
                          as ImageProvider,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variant['variant_name']?.toString() ??
                        'Sản phẩm không xác định',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: HomeScreen.cpsTextBlack,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Số lượng: ${item['quantity']?.toString() ?? '0'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: HomeScreen.cpsSubtleTextGrey,
                    ),
                  ),
                  Text(
                    NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(
                      double.tryParse(item['total_price']?.toString() ?? '0') ??
                          0,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: HomeScreen.imageRedAccent,
                    ),
                  ),
                ],
              ),
            ),
            if (status == 'Completed') ...[
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: canReturn
                    ? () {
                        _showReturnRequestDialog(context, item);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      canReturn ? HomeScreen.imageRedAccent : Colors.grey,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  textStyle: const TextStyle(fontSize: 12),
                  minimumSize: const Size(80, 30),
                ),
                child: const Text('Trả hàng'),
              ),
            ],
          ],
        ),
      ),
    );
  }
  // ... _buildOrderDetails, _buildSectionTitle, _buildInfoRow, _buildItemCard ...
  // GIỮ NGUYÊN HÀM _showReturnRequestDialog VÀ CÁC HÀM LIÊN QUAN ĐÃ ĐƯỢC CẬP NHẬT Ở CÂU TRẢ LỜI TRƯỚC
  // ĐẢM BẢO `_orderData` trong `_showReturnRequestDialog` là dữ liệu đã được fetch từ API `/orders/{order_id}`

  Future<void> _showReturnRequestDialog(
      BuildContext context, Map<String, dynamic> item) async {
    // Kiểm tra xem _orderData có null không, mặc dù ở _buildOrderDetails đã kiểm tra
    if (_orderData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Lỗi: Dữ liệu đơn hàng không đầy đủ để thực hiện trả hàng.')),
      );
      return;
    }

    final variant = item['variant'] as Map<String, dynamic>? ?? {};
    final TextEditingController serialIdDisplayController =
        TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    final TextEditingController refundAccountInfoController =
        TextEditingController();
    String returnType = 'refund';
    XFile?
        selectedImageForDialog; // Đổi tên để tránh nhầm lẫn với state của widget

    final List<dynamic> soldSerialsRaw =
        item['sold_serials'] as List<dynamic>? ?? [];
    print(
        "Item for return dialog: $item"); // Debug xem item có sold_serials không
    print("Raw sold_serials for this item: $soldSerialsRaw");

    final List<Map<String, dynamic>> availableSerials = soldSerialsRaw
        .map((s) {
          // Đảm bảo s là Map trước khi truy cập key
          if (s is Map<String, dynamic>) {
            return {
              'display': s['serial_code']?.toString() ?? 'N/A',
              'value': s['serial_id'] as int?,
            };
          }
          return {
            'display': 'Lỗi dữ liệu serial',
            'value': null
          }; // Xử lý trường hợp s không phải Map
        })
        .where((s) => s['value'] != null)
        .toList();
    print("Available serials for dropdown: $availableSerials");

    int? selectedActualSerialId;

    if (availableSerials.length == 1) {
      serialIdDisplayController.text = availableSerials[0]['display'];
      selectedActualSerialId = availableSerials[0]['value'];
    }

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // Sử dụng dialogContext cho pop
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                  'Yêu cầu trả hàng: ${variant['variant_name'] ?? 'Sản phẩm'}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (availableSerials.length > 1) ...[
                      const Text('Chọn Serial sản phẩm:',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          hintText: 'Chọn Serial ID',
                        ),
                        value: selectedActualSerialId,
                        items: availableSerials.map((serialData) {
                          return DropdownMenuItem<int>(
                            value: serialData['value'] as int,
                            child: Text(serialData['display'] as String),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setStateDialog(() {
                            selectedActualSerialId = value;
                            final selectedSerialDisplay = availableSerials
                                .firstWhere((s) => s['value'] == value,
                                    orElse: () => {'display': ''})['display'];
                            serialIdDisplayController.text =
                                selectedSerialDisplay;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Vui lòng chọn Serial ID' : null,
                      ),
                    ] else ...[
                      TextField(
                        controller: serialIdDisplayController,
                        decoration: InputDecoration(
                          labelText:
                              'Serial sản phẩm ${availableSerials.isEmpty ? "(bắt buộc nhập tay)" : "(tự động)"}',
                          hintText: availableSerials.isEmpty
                              ? 'Nhập Serial sản phẩm'
                              : '',
                        ),
                        keyboardType: TextInputType.text,
                        readOnly: availableSerials.length == 1 &&
                            availableSerials.isNotEmpty,
                      ),
                      if (availableSerials.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Không tìm thấy serial tự động. Vui lòng nhập Serial Code của sản phẩm.',
                            style:
                                TextStyle(fontSize: 10, color: Colors.orange),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Lý do trả hàng (bắt buộc)',
                        hintText: 'Nhập lý do (ít nhất 10 ký tự)',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: returnType,
                      decoration: const InputDecoration(
                        labelText: 'Loại yêu cầu',
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'refund', child: Text('Hoàn tiền')),
                        DropdownMenuItem(
                            value: 'exchange', child: Text('Đổi sản phẩm')),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          returnType = value!;
                        });
                      },
                    ),
                    if (returnType == 'refund') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: refundAccountInfoController,
                        decoration: const InputDecoration(
                          labelText: 'Thông tin tài khoản nhận tiền (bắt buộc)',
                          hintText: 'Nhập thông tin tài khoản',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text('Ảnh sản phẩm (nếu có):',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    GestureDetector(
                      onTap: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setStateDialog(() {
                            selectedImageForDialog = image;
                          });
                        }
                      },
                      child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.image_outlined,
                                  color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedImageForDialog?.name ??
                                      'Chọn ảnh (tối đa 5MB)',
                                  style: TextStyle(
                                      color: selectedImageForDialog == null
                                          ? Colors.grey
                                          : Colors.black),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )),
                    ),
                    if (selectedImageForDialog != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: kIsWeb
                            ? Image.network(selectedImageForDialog!.path,
                                height: 100, fit: BoxFit.cover)
                            : Image.file(File(selectedImageForDialog!.path),
                                height: 100, fit: BoxFit.cover),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Pop dialog trả hàng
                  },
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String serialIdValueToSubmit;

                    if (availableSerials.isNotEmpty) {
                      if (selectedActualSerialId == null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                              content: Text('Vui lòng chọn Serial sản phẩm.')),
                        );
                        return;
                      }
                      serialIdValueToSubmit = selectedActualSerialId.toString();
                    } else {
                      // availableSerials is empty, user must type
                      if (serialIdDisplayController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                              content: Text('Vui lòng nhập Serial sản phẩm.')),
                        );
                        return;
                      }
                      serialIdValueToSubmit =
                          serialIdDisplayController.text.trim();
                    }

                    if (reasonController.text.trim().length < 10) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        //Sử dụng context của dialog
                        const SnackBar(
                            content: Text('Lý do phải có ít nhất 10 ký tự')),
                      );
                      return;
                    }
                    if (returnType == 'refund' &&
                        refundAccountInfoController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Vui lòng nhập thông tin tài khoản nhận tiền')),
                      );
                      return;
                    }

                    final orderIdFromData = _orderData!['order_id'] as int?;
                    if (orderIdFromData == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Không tìm thấy ID đơn hàng để gửi yêu cầu.')),
                      );
                      return;
                    }
                    if (selectedImageForDialog == null) {
                      // Hiển thị thông báo lỗi cho người dùng biết ảnh là bắt buộc
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng chọn ảnh sản phẩm.'),
                          backgroundColor: Colors.red, // Màu đỏ để nổi bật lỗi
                        ),
                      );
                      // Ngừng xử lý tiếp, không lưu hoặc gửi dữ liệu
                      return;
                    }
                    // Show loading inside the dialog or a new one
                    showDialog(
                      context: dialogContext, // Use dialog context
                      barrierDismissible: false,
                      builder: (BuildContext loadingDialogContext) {
                        return const Center(child: CircularProgressIndicator());
                      },
                    );

                    try {
                      var request = http.MultipartRequest(
                        'POST',
                        Uri.parse(
                            'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/returns/requests'),
                      );
                      request.headers['accept'] = 'application/json';
                      request.headers['X-User-ID'] =
                          _orderData?['user_id']?.toString() ?? '2';

                      request.fields['order_id'] = orderIdFromData.toString();
                      request.fields['serial_id'] = serialIdValueToSubmit;
                      request.fields['reason'] = reasonController.text.trim();
                      request.fields['return_type'] = returnType;
                      if (returnType == 'refund') {
                        request.fields['refund_account_info'] =
                            refundAccountInfoController.text.trim();
                      }

                      if (selectedImageForDialog != null) {
                        final bytes =
                            await selectedImageForDialog!.readAsBytes();
                        final mimeType = lookupMimeType(
                                selectedImageForDialog!.path,
                                headerBytes: bytes.sublist(
                                    0, math.min(bytes.length, 256))) ??
                            'application/octet-stream';
                        request.files.add(http.MultipartFile.fromBytes(
                          'image',
                          bytes,
                          filename: selectedImageForDialog!.name,
                          contentType: MediaType.parse(mimeType),
                        ));
                      }

                      final response = await request.send();
                      final responseBody =
                          await response.stream.bytesToString();

                      Navigator.of(dialogContext).pop(); // Pop loading dialog

                      if (response.statusCode == 201) {
                        Navigator.of(dialogContext)
                            .pop(); // Pop return request dialog
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          // Use widget's context for SnackBar after dialogs are closed
                          const SnackBar(
                              content: Text(
                                  'Yêu cầu trả hàng đã được gửi thành công!')),
                        );
                      } else {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Lỗi gửi yêu cầu: ${response.statusCode} - $responseBody'),
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    } catch (e) {
                      Navigator.of(dialogContext).pop(); // Pop loading dialog
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                            content: Text('Lỗi kết nối khi gửi yêu cầu: $e')),
                      );
                    }
                  },
                  child: const Text('Gửi yêu cầu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusRow(Map<String, dynamic> status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _mapStatusToVietnamese(status['status'] ?? 'unknown'),
            style:
                const TextStyle(fontSize: 14, color: HomeScreen.cpsTextBlack),
          ),
          Text(
            status['changed_at'] != null
                ? DateFormat('dd/MM/yyyy HH:mm')
                    .format(DateTime.parse(status['changed_at']).toLocal())
                : 'N/A',
            style: const TextStyle(
                fontSize: 12, color: HomeScreen.cpsSubtleTextGrey),
          ),
        ],
      ),
    );
  }

  String _mapStatusToVietnamese(String status) {
    switch (status) {
      case 'Pending':
        return 'Chờ xác nhận';
      case 'Confirmed':
        return 'Đã xác nhận';
      case 'Shipping':
        return 'Đang vận chuyển';
      case 'Completed':
        return 'Đã giao hàng';
      case 'Cancelled':
        return 'Đã huỷ';
      case 'ReturnedToSender':
        return 'Hoàn trả';
      default:
        return status;
    }
  }
}
