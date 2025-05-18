import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert'; // Đảm bảo utf8 có thể được sử dụng
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ShipperApp());
}

class ShipperApp extends StatelessWidget {
  const ShipperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shipper App',
      theme: ThemeData(
        primaryColor: const Color(0xFF1E88E5),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        textTheme: GoogleFonts.poppinsTextTheme().apply(
          bodyColor: const Color(0xFF2D3748),
          displayColor: const Color(0xFF2D3748),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            elevation: 3,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
          ),
          prefixIconColor: const Color(0xFF1E88E5),
          labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
        ),
        cardTheme: CardTheme(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
        ),
      ),
      home: const LoginScreen(), // Hoặc AuthWrapper nếu bạn có logic kiểm tra đăng nhập
      routes: {
        '/home': (context) => const HomeScreen2(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        // Không cần route cho DeliveryTrackingScreen nếu bạn push trực tiếp
      },
    );
  }
}

//----- LOGIN SCREEN -----
// ... (Giữ nguyên LoginScreen)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? firebaseUid = prefs.getString('firebase_uid');
    // Thêm kiểm tra backend_user_id nếu cần
    if (firebaseUid != null && FirebaseAuth.instance.currentUser != null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _login() async {
    if (!mounted) return;
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      _handleError('Please enter both email and password.');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final String? firebaseUid = userCredential.user?.uid;
      if (firebaseUid == null) throw Exception('Could not retrieve Firebase UID.');

      final apiUrl = Uri.parse('https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/auth/login-success');
      final backendResponse = await http.post(apiUrl, headers: {'accept': 'application/json','Content-Type': 'application/json',},
        body: jsonEncode({'firebase_uid': firebaseUid,}),
      ).timeout(const Duration(seconds: 15));
      final responseData = jsonDecode(utf8.decode(backendResponse.bodyBytes));

      if (backendResponse.statusCode == 200) {
        final bool? isActive = responseData['is_active'] as bool?;
        final String? roleFromApi = responseData['role'] as String?;

        if (roleFromApi == null || roleFromApi.toLowerCase() != 'shipper') {
          await FirebaseAuth.instance.signOut();
          _handleError('Access denied. Only shipper accounts are allowed.');
          return;
        }

        if (isActive == null || !isActive) {
          await FirebaseAuth.instance.signOut();
          _handleError('Your account is inactive or disabled. Please contact support.');
          return;
        }
        final int? backendUserId = responseData['user_id'] as int?;
        final String? fullName = responseData['full_name'] as String?;
        final String? emailFromApi = responseData['email'] as String?;


        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('firebase_uid', firebaseUid);
        if (backendUserId != null) await prefs.setInt('backend_user_id', backendUserId);
        if (fullName != null) await prefs.setString('user_full_name', fullName);
        if (emailFromApi != null) await prefs.setString('user_email', emailFromApi);
        if (roleFromApi != null) await prefs.setString('user_role', roleFromApi);

        print("User data saved to SharedPreferences: UID: $firebaseUid, BackendID: $backendUserId, Role: $roleFromApi");
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        await FirebaseAuth.instance.signOut();
        throw Exception(responseData['detail']?.toString() ?? responseData['message']?.toString() ?? 'Server authentication failed (Code: ${backendResponse.statusCode}). Account may not be authorized.');
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found': msg = 'No user found for that email.'; break;
        case 'wrong-password': msg = 'Wrong password provided.'; break;
        case 'invalid-email': msg = 'The email address is not valid.'; break;
        case 'user-disabled': msg = 'This user account has been disabled by Firebase.'; break;
        case 'too-many-requests': msg = 'Too many requests. Try again later.'; break;
        case 'network-request-failed': msg = 'A network error occurred. Please check your connection.'; break;
        default: msg = 'Firebase Authentication Error: ${e.message} (Code: ${e.code})';
      }
      _handleError(msg);
    } on TimeoutException { _handleError('The request timed out. Please check your connection.');
    } on http.ClientException catch (e) { _handleError('Connection error: ${e.message}. Please check your internet.');
    } catch (e) { _handleError(e.toString().replaceFirst("Exception: ", "An unexpected error occurred: "));
    } finally { if (mounted) setState(() { _isLoading = false; }); }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() { _errorMessage = message; });
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red[600], duration: const Duration(seconds: 4),));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [const Color(0xFF1E88E5), const Color(0xFF42A5F5).withOpacity(0.8)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 700),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Shipper Hub', style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 2.0, color: Colors.black.withOpacity(0.3), offset: const Offset(1.0, 1.0),)]), textAlign: TextAlign.center,),
                      const SizedBox(height: 8),
                      Text('Manage your deliveries with ease', style: GoogleFonts.poppins(fontSize: 16, color: Colors.white.withOpacity(0.85),), textAlign: TextAlign.center,),
                      const SizedBox(height: 40),
                      Card(
                        elevation: 8,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined),), keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, enabled: !_isLoading,),
                              const SizedBox(height: 20),
                              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline),), obscureText: true, textInputAction: TextInputAction.done, onSubmitted: (_) => _isLoading ? null : _login(), enabled: !_isLoading,),
                              const SizedBox(height: 16),
                              if (_errorMessage != null && _errorMessage!.isNotEmpty)
                                Padding(padding: const EdgeInsets.only(bottom: 12.0, top: 4.0), child: Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.red[700], fontSize: 14), textAlign: TextAlign.center,),),
                              const SizedBox(height: 16),
                              _isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _login, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50),), child: const Text('Sign In'),),
                              const SizedBox(height: 20),
                              TextButton(onPressed: _isLoading ? null : () => Navigator.pushNamed(context, '/forgot-password'), child: Text('Forgot Password?', style: GoogleFonts.poppins(color: const Color(0xFF1E88E5), fontWeight: FontWeight.w500,),),),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}
class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSending = false;
  String? _message;
  bool _isError = false;

  Future<void> _sendResetLink() async {
    if (!mounted) return;
    final String email = _emailController.text.trim();
    if (email.isEmpty) { setState(() { _message = 'Vui lòng nhập địa chỉ email của bạn.'; _isError = true; _isSending = false; }); return; }
    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email)) { setState(() { _message = 'Vui lòng nhập địa chỉ email hợp lệ.'; _isError = true; _isSending = false; }); return; }
    setState(() { _isSending = true; _message = null; _isError = false; });
    try {
      final apiUrl = Uri.parse('https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/auth/password-reset');
      final response = await http.post(apiUrl, headers: {'accept': 'application/json','Content-Type': 'application/json',}, body: jsonEncode({'email': email}),).timeout(const Duration(seconds: 15));
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 202) {
        if (mounted) setState(() { _message = responseData['message']?.toString() ?? 'If an account with that email exists, a password reset email has been sent.'; _isError = false; _emailController.clear(); });
      } else {
        String errorMessage = responseData['detail']?.toString() ?? responseData['message']?.toString() ?? 'Failed to send reset link (Code: ${response.statusCode}).';
        if (mounted) setState(() { _message = errorMessage; _isError = true; });
      }
    } on TimeoutException { if (mounted) setState(() { _message = 'The request timed out. Please check your connection.'; _isError = true; });
    } on http.ClientException catch (e) { if (mounted) setState(() { _message = 'Connection error: ${e.message}.'; _isError = true; });
    } catch (e) { if (mounted) setState(() { _message = "An unexpected error occurred: ${e.toString()}"; _isError = true; });
    } finally { if (mounted) setState(() { _isSending = false; });}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu'), flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)], begin: Alignment.topLeft, end: Alignment.bottomRight,),),), foregroundColor: Colors.white, elevation: 0,),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Đặt lại mật khẩu', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF1E88E5),), textAlign: TextAlign.center,),
                  const SizedBox(height: 12),
                  Text('Nhập địa chỉ email đã đăng ký của bạn. Chúng tôi sẽ gửi cho bạn một liên kết để đặt lại mật khẩu.', style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[700],), textAlign: TextAlign.center,),
                  const SizedBox(height: 30),
                  TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined),), keyboardType: TextInputType.emailAddress, enabled: !_isSending, textInputAction: TextInputAction.done, onSubmitted: (_) => _isSending ? null : _sendResetLink(),),
                  const SizedBox(height: 20),
                  if (_message != null) Padding(padding: const EdgeInsets.only(bottom: 16.0, top:8.0), child: Text(_message!, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: _isError ? Colors.red[700] : Colors.green[700], fontSize: 14,),),),
                  const SizedBox(height: 10),
                  _isSending ? const Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _sendResetLink, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50),), child: const Text('Gửi liên kết đặt lại'),),
                  const SizedBox(height: 20),
                  TextButton(onPressed: _isSending ? null : () => Navigator.pop(context), child: Text('Quay lại Đăng nhập', style: GoogleFonts.poppins(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500),),),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen2 extends StatelessWidget {
  const HomeScreen2({super.key});
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Xóa tất cả SharedPreferences khi logout
    if (context.mounted) {
      // Đảm bảo không có route nào khác trên stack trước khi push LoginScreen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false, // Xóa tất cả các route trước đó
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shipper Dashboard'), flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)], begin: Alignment.topLeft, end: Alignment.bottomRight,),),), foregroundColor: Colors.white, elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context), tooltip: 'Logout',),],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeInUp(duration: const Duration(milliseconds: 600), child: Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), title: Text('View Orders to Deliver', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: const Color(0xFF2D3748),),), leading: const Icon(Icons.local_shipping, color: Color(0xFF1E88E5), size: 28), trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFF1E88E5)), onTap: () {Navigator.push(context, MaterialPageRoute(builder: (context) => const OrdersScreen()),);},),),),
            const SizedBox(height: 20),
            FadeInUp(duration: const Duration(milliseconds: 800), delay: const Duration(milliseconds: 100), child: Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), title: Text('View Return Requests', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: const Color(0xFF2D3748),),), leading: const Icon(Icons.assignment_return, color: Color(0xFF1E88E5), size: 28), trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFF1E88E5)), onTap: () {Navigator.push(context, MaterialPageRoute(builder: (context) => const ReturnRequestsScreen()),);},),),),
          ],
        ),
      ),
    );
  }
}

class DeliveryTrackingScreen extends StatefulWidget {
  final String orderId;
  final String orderCode;
  final String recipientName;
  final String shippingAddress;

  const DeliveryTrackingScreen({
    super.key,
    required this.orderId,
    required this.orderCode,
    required this.recipientName,
    required this.shippingAddress,
  });

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}
class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  bool _isUpdatingStatus = false;
  double _sliderValue = 0.0; // 0.0 to 1.0 for slider completion

  Future<void> _updateOrderStatusApi(String newStatus, {String? notes}) async {
    if (!mounted || _isUpdatingStatus) return;
    setState(() { _isUpdatingStatus = true; });

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đang cập nhật ĐH #${widget.orderCode} thành $newStatus...'),
      duration: const Duration(seconds: 3), // Longer duration for user to see
    ));

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? shipperUserId = prefs.getInt('backend_user_id');
      if (shipperUserId == null) {
        _showErrorSnackBar('Shipper User ID not found. Vui lòng đăng nhập lại.');
        if (mounted) setState(() { _isUpdatingStatus = false; });
        return;
      }

      final updateApiUrl = Uri.parse('https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/shipper/orders/${widget.orderId}/status');
      final response = await http.put(
        updateApiUrl,
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'X-User-ID': shipperUserId.toString(),
        },
        body: jsonEncode({
          'new_status': newStatus,
          'notes': "",
        }),
      ).timeout(const Duration(seconds: 20)); // Increased timeout

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ĐH #${widget.orderCode} đã được cập nhật thành $newStatus.'),
          backgroundColor: Colors.green[600],
        ));
        if (mounted) {
          Navigator.pop(context, true); // Return true to signal a change
        }
      } else {
        String err = 'Cập nhật thất bại (Code: ${response.statusCode}).';
        try {
          final eData = jsonDecode(utf8.decode(response.bodyBytes));
          err = eData['detail']?.toString() ?? eData['message']?.toString() ?? err;
        } catch (_) {}
        _showErrorSnackBar(err);
        if (mounted) setState(() { _isUpdatingStatus = false; _sliderValue = 0.0;}); // Reset slider on failure
      }
    } on TimeoutException {
      _showErrorSnackBar('Yêu cầu cập nhật quá thời gian. Vui lòng thử lại.');
      if (mounted) setState(() { _isUpdatingStatus = false; _sliderValue = 0.0;});
    } on http.ClientException catch (e) {
      _showErrorSnackBar('Lỗi kết nối khi cập nhật: ${e.message}');
      if (mounted) setState(() { _isUpdatingStatus = false; _sliderValue = 0.0;});
    } catch (e) {
      _showErrorSnackBar('Lỗi không mong muốn khi cập nhật: ${e.toString()}');
      if (mounted) setState(() { _isUpdatingStatus = false; _sliderValue = 0.0;});
    }
    // finally { // Removed finally block to allow individual error handling to set _isUpdatingStatus
    //   if (mounted && _isUpdatingStatus) { // Only set to false if it was true and not handled by error
    //     setState(() { _isUpdatingStatus = false; _sliderValue = 0.0; });
    //   }
    // }
  }

  void _confirmReturnToSender() {
    if (_isUpdatingStatus) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Xác nhận hoàn trả', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text('Bạn có chắc chắn muốn cập nhật đơn hàng #${widget.orderCode} thành "ReturnedToSender"? Hành động này không thể hoàn tác.', style: GoogleFonts.poppins()),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: <Widget>[
            TextButton(
              child: Text('Hủy', style: GoogleFonts.poppins(color: Colors.grey[700])),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Xác nhận hoàn trả'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _updateOrderStatusApi('ReturnedToSender', notes: 'Hàng được hoàn trả bởi shipper.');
              },
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Theo dõi ĐH #${widget.orderCode}'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView( // To prevent overflow if content is too long
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thông tin đơn hàng', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                        const SizedBox(height: 10),
                        _buildDetailItem(Icons.person_outline, 'Người nhận:', widget.recipientName),
                        _buildDetailItem(Icons.location_on_outlined, 'Địa chỉ:', widget.shippingAddress),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Mockup Map
                Container(
                  height: 200, // Fixed height for the map area
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    image: const DecorationImage(
                      // Replace with a generic map placeholder or a more relevant static map image
                        image: NetworkImage('https://www.mapsofworld.com/physical-map/world-physical-map.jpg'),
                        fit: BoxFit.cover,
                        opacity: 0.6
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.map_outlined, size: 80, color: Theme.of(context).primaryColor.withOpacity(0.7)),
                ),
                const SizedBox(height: 24),

                Text('Trượt để xác nhận đã giao hàng:', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[800])),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50) // Rounded ends for the container
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.green.shade500,
                            inactiveTrackColor: Colors.green.shade100,
                            trackShape: const RoundedRectSliderTrackShape(), // Makes track have rounded ends
                            trackHeight: 16.0, // Make slider thicker
                            thumbColor: Colors.green.shade700,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 20.0, elevation: 4), // Larger thumb
                            overlayColor: Colors.green.withAlpha(50),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 30.0),
                          ),
                          child: Slider(
                            value: _sliderValue,
                            min: 0.0,
                            max: 1.0,
                            divisions: 20, // Fewer divisions can make it feel more "snappy" to complete
                            label: _sliderValue >= 0.98 ? "Hoàn thành!" : "Kéo sang phải",
                            onChanged: _isUpdatingStatus ? null : (double value) {
                              setState(() {
                                _sliderValue = value;
                              });
                            },
                            onChangeEnd: (double value) {
                              if (value >= 0.98 && !_isUpdatingStatus) { // High threshold for completion
                                _updateOrderStatusApi('Completed', notes: 'Shipper marked as completed via app.');
                              } else if (value < 0.98) {
                                // Reset slider if not fully swiped
                                setState(() {
                                  _sliderValue = 0.0;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.local_shipping, color: Colors.green.shade700, size: 28),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                OutlinedButton.icon(
                  icon: Icon(Icons.assignment_return_outlined, color: Colors.red.shade700),
                  label: Text('Báo cáo hoàn trả', style: GoogleFonts.poppins(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 16)),
                  onPressed: _isUpdatingStatus ? null : _confirmReturnToSender,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: BorderSide(color: Colors.red.shade300, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 20), // For bottom padding
              ],
            ),
          ),
          if (_isUpdatingStatus)
            Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 15),
                      Text("Đang xử lý...", style: TextStyle(color: Colors.white, fontSize: 16))
                    ],
                  )
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor.withOpacity(0.9)),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
          const SizedBox(width: 5),
          Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 15, color: const Color(0xFF2D3748)))),
        ],
      ),
    );
  }
}


class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final String orderCode;
  const OrderDetailScreen({super.key, required this.orderId, required this.orderCode,});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}
class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _orderDetail;
  bool _isLoading = true;
  String? _error;
  Map<int, Map<String, dynamic>> _variantDetails = {};

  @override
  void initState() { super.initState(); _fetchOrderDetail(); }

  Future<void> _fetchOrderDetail() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? shipperUserId = prefs.getInt('backend_user_id');
      if (shipperUserId == null) throw Exception('Shipper User ID not found. Please re-login.');
      final apiUrl = Uri.parse('https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/shipper/orders/${widget.orderId}');
      final response = await http.get(apiUrl, headers: {
        'accept': 'application/json',
        'X-User-ID': shipperUserId.toString(),
      }).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _orderDetail = jsonDecode(utf8.decode(response.bodyBytes));
            _isLoading = false;
          });
          // Gọi API để lấy chi tiết variant sau khi có _orderDetail
          await _fetchVariantDetails();
        }
      } else {
        String err = 'Failed to load order details (Code: ${response.statusCode})';
        try {
          final eData = jsonDecode(utf8.decode(response.bodyBytes));
          err = eData['detail']?.toString() ?? eData['message']?.toString() ?? err;
        } catch (_) {}
        throw Exception(err);
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = "Could not load order details: ${e.toString()}"; });
    }
  }

  Future<void> _fetchVariantDetails() async {
    if (_orderDetail == null || _orderDetail!['items'] == null) return;
    final items = _orderDetail!['items'] as List<dynamic>;
    for (var item in items) {
      final variantId = item['variant']?['id'] ?? item['variant_id'];
      if (variantId == null) continue;
      try {
        final apiUrl = Uri.parse('https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/variants/$variantId/price');
        SharedPreferences prefs = await SharedPreferences.getInstance();
        final int? shipperUserId = prefs.getInt('backend_user_id');
        final response = await http.get(apiUrl, headers: {
          'accept': 'application/json',
          if (shipperUserId != null) 'X-User-ID': shipperUserId.toString(),
        }).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final variantData = jsonDecode(utf8.decode(response.bodyBytes));
          if (mounted) {
            setState(() {
              _variantDetails[variantId] = variantData;
            });
          }
        }
      } catch (e) {
        // Không set lỗi toàn cục, chỉ bỏ qua variant này
        print('Error fetching variant $variantId: $e');
      }
    }
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, {bool isStatus = false}) {
    Color valueColor = const Color(0xFF2D3748); FontWeight valueWeight = FontWeight.normal;
    if (isStatus) { valueColor = _getStatusColor(value); valueWeight = FontWeight.w500; }
    return Padding( padding: const EdgeInsets.symmetric(vertical: 6.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [ Icon(icon, size: 18, color: Theme.of(context).primaryColor.withOpacity(0.8)), const SizedBox(width: 12), Text('$label: ', style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[700], fontWeight: FontWeight.w500),), Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 15, color: valueColor, fontWeight: valueWeight),),),],),);
  }
  Color _getStatusColor(String status) { /* giữ nguyên */ switch (status.toLowerCase()) { case 'pending': return Colors.grey.shade700; case 'confirmed': return Colors.blue.shade600; case 'shipping': return Colors.orange.shade700; case 'delivered': case 'completed': return Colors.green.shade700; case 'cancelled': return Colors.red.shade700; case 'returnedtosender': return Colors.purple.shade400; default: return Colors.black54;}}
  String _formatDateTime(String? dateTimeString) { if (dateTimeString == null || dateTimeString.isEmpty) return 'N/A'; try { final DateTime dateTime = DateTime.parse(dateTimeString).toLocal(); return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}"; } catch (e) { return dateTimeString; }}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết ĐH #${_orderDetail?['order_code'] ?? widget.orderCode}'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: GoogleFonts.poppins(color: Colors.red[700], fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Thử lại"),
                onPressed: _fetchOrderDetail,
              ),
            ],
          ),
        ),
      )
          : _orderDetail == null
          ? const Center(child: Text("Không tìm thấy thông tin đơn hàng."))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Thông tin người nhận'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    _buildDetailRow(context, Icons.person_outline, 'Tên',
                        _orderDetail!['recipient_name'] ?? 'N/A'),
                    _buildDetailRow(context, Icons.phone_outlined, 'SĐT',
                        _orderDetail!['recipient_phone'] ?? 'N/A'),
                    _buildDetailRow(context, Icons.location_on_outlined, 'Địa chỉ',
                        _orderDetail!['shipping_address'] ?? 'N/A'),
                    if (_orderDetail!['notes'] != null &&
                        (_orderDetail!['notes'] as String).isNotEmpty)
                      _buildDetailRow(context, Icons.notes_outlined, 'Ghi chú',
                          _orderDetail!['notes']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle(context, 'Thông tin đơn hàng'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    _buildDetailRow(context, Icons.label_outline, 'Mã ĐH',
                        _orderDetail!['order_code'] ?? 'N/A'),
                    _buildDetailRow(context, Icons.paid_outlined, 'Phương thức TT',
                        _orderDetail!['payment_method'] ?? 'N/A'),
                    _buildDetailRow(context, Icons.receipt_long_outlined, 'Trạng thái',
                        _orderDetail!['status'] ?? 'N/A', isStatus: true),
                    _buildDetailRow(context, Icons.calendar_today_outlined, 'Ngày đặt',
                        _formatDateTime(_orderDetail!['ordered_at'])),
                    _buildDetailRow(context, Icons.update_outlined, 'Cập nhật cuối',
                        _formatDateTime(_orderDetail!['updated_at'])),
                    _buildDetailRow(context, Icons.money_outlined, 'Tổng tiền',
                        "${double.tryParse(_orderDetail!['total_amount']?.toString() ?? '0.0')?.toStringAsFixed(0) ?? '0'} VND"),
                    _buildDetailRow(context, Icons.local_offer_outlined, 'Coupon',
                        _orderDetail!['coupon']?['code'] ?? 'Không có'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle(context, 'Sản phẩm (${_orderDetail!['items']?.length ?? 0})'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: (_orderDetail!['items'] as List?)?.isEmpty ?? true
                    ? const Text("Không có sản phẩm.")
                    : Column(
                  children: (_orderDetail!['items'] as List<dynamic>).map((item) {
                    final variant = item['variant'];
                    final variantId = item['variant']?['id'] ?? item['variant_id'];
                    final variantDetail = _variantDetails[variantId];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${variantDetail?['product_name'] ?? variant?['variant_name'] ?? 'Sản phẩm không tên'} (x${item['quantity']})",
                                  style: GoogleFonts.poppins(
                                      fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  "Giá: ${double.tryParse(item['price_at_purchase']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'} VND",
                                  style: GoogleFonts.poppins(
                                      fontSize: 14, color: Colors.grey[700]),
                                ),
                                if (variant?['variant_code'] != null)
                                  Text(
                                    "Mã SP: ${variant['variant_code']}",
                                    style: GoogleFonts.poppins(
                                        fontSize: 13, color: Colors.grey[600]),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_orderDetail!['status_history'] != null &&
                (_orderDetail!['status_history'] as List).isNotEmpty) ...[
              _buildSectionTitle(context, 'Lịch sử trạng thái'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: (_orderDetail!['status_history'] as List<dynamic>).map((history) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_getHistoryStatusIcon(history['status']),
                            color: _getStatusColor(history['status'])),
                        title: Text(history['status'],
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                color: _getStatusColor(history['status']))),
                        trailing: Text(_formatDateTime(history['changed_at']),
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_orderDetail!['shipper'] != null && _orderDetail!['shipper']['user'] != null) ...[
              _buildSectionTitle(context, 'Thông tin Shipper'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      _buildDetailRow(context, Icons.person_outline, 'Tên Shipper',
                          _orderDetail!['shipper']['user']['full_name'] ?? 'N/A'),
                      _buildDetailRow(context, Icons.phone_android_outlined, 'SĐT Shipper',
                          _orderDetail!['shipper']['user']['phone_number'] ?? 'N/A'),
                      _buildDetailRow(context, Icons.delivery_dining_outlined, 'Trạng thái giao',
                          _orderDetail!['shipper']['status'] ?? 'N/A'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
  Widget _buildSectionTitle(BuildContext context, String title) { return Padding(padding: const EdgeInsets.only(bottom: 8.0, top: 8.0), child: Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor,),),); }
  IconData _getHistoryStatusIcon(String status) { return _getStatusColor(status) == Colors.green.shade700 ? Icons.check_circle : _getStatusColor(status) == Colors.red.shade700 ? Icons.cancel : Icons.arrow_right_alt_rounded; }
}





//----- ORDERS SCREEN -----
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoadingOrders = true;
  String? _ordersError;

  @override
  void initState() {
    super.initState();
    _fetchOrdersForShipper();
  }

  Future<void> _fetchOrdersForShipper() async {
    if (!mounted) return;
    setState(() { _isLoadingOrders = true; _ordersError = null; });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? shipperUserId = prefs.getInt('backend_user_id');
      if (shipperUserId == null) throw Exception('Shipper User ID not found. Please re-login.');

      // API sẽ trả về tất cả các đơn hàng được gán cho shipper này (không lọc client-side nữa)
      // Thay đổi limit nếu cần để tải nhiều đơn hàng hơn
      String apiUrlString = 'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/shipper/orders?skip=0&limit=50';

      final Uri apiUrl = Uri.parse(apiUrlString);
      final response = await http.get(apiUrl, headers: {'accept': 'application/json','X-User-ID': shipperUserId.toString(),},).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _orders = responseData.map((orderData) {
              return {
                'id': orderData['order_id']?.toString() ?? 'N/A',
                'order_code': orderData['order_code'] ?? 'N/A',
                'status': orderData['status'] ?? 'Unknown',
                'recipient_name': orderData['recipient_name'] ?? 'N/A',
                'recipient_phone': orderData['recipient_phone'] ?? 'N/A',
                'recipient_info': "Tên: ${orderData['recipient_name'] ?? 'N/A'}\nSĐT: ${orderData['recipient_phone'] ?? 'N/A'}",
                'address': orderData['shipping_address'] ?? 'No address',
                'payment_method': orderData['payment_method'] ?? 'N/A',
                'total_amount': double.tryParse(orderData['total_amount']?.toString() ?? "0.0") ?? 0.0,
                'notes': orderData['notes'] ?? '',
                'items_summary': _extractItemsSummary(orderData['items']),
                'ordered_at': orderData['ordered_at'] ?? 'N/A',
              };
            }).toList();
            // KHÔNG CÓ LỌC CLIENT-SIDE NỮA
            // _orders = _orders.where((order) {
            //     final status = order['status'].toString().toLowerCase();
            //     return status == 'confirmed' || status == 'shipping';
            // }).toList();
            _isLoadingOrders = false;
          });
        }
      } else {
        String err = 'Failed to load orders (Code: ${response.statusCode})';
        try { final eData = jsonDecode(utf8.decode(response.bodyBytes)); err = eData['detail']?.toString() ?? eData['message']?.toString() ?? err; } catch (_) {}
        throw Exception(err);
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingOrders = false; _ordersError = "Could not load orders: ${e.toString()}";});
    }
  }

  String _extractItemsSummary(dynamic itemsData) {
    if (itemsData != null && (itemsData is List) && itemsData.isNotEmpty) return itemsData.map((item) => "${item['quantity']} x ${item['variant']?['variant_name'] ?? 'Item'}").join(', ');
    return "N/A";
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.grey.shade700;
      case 'confirmed': return Colors.blue.shade600;
      case 'shipping': return Colors.orange.shade700;
      case 'delivered': // Fall-through
      case 'completed': return Colors.green.shade700;
      case 'cancelled': return Colors.red.shade700;
      case 'returnedtosender': return Colors.purple.shade400;
      default: return Colors.black54;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Icons.hourglass_empty_rounded;
      case 'confirmed': return Icons.playlist_add_check_rounded;
      case 'shipping': return Icons.local_shipping_rounded;
      case 'delivered': // Fall-through
      case 'completed': return Icons.check_circle_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      case 'returnedtosender': return Icons.assignment_return_outlined;
      default: return Icons.help_outline_rounded;
    }
  }

  Future<void> _startShipping(Map<String, dynamic> order) async {
    if (!mounted) return;
    final String orderId = order['id'].toString();
    final String orderCode = order['order_code'] ?? orderId;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xác nhận giao ĐH #$orderCode...'), duration: const Duration(seconds: 2),));

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? shipperUserId = prefs.getInt('backend_user_id');
      if (shipperUserId == null) {
        _showErrorSnackBar('Shipper User ID not found. Please re-login.');
        return;
      }

      final updateApiUrl = Uri.parse('https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/shipper/orders/$orderId/status');
      final response = await http.put(updateApiUrl, headers: {'accept': 'application/json','Content-Type': 'application/json','X-User-ID': shipperUserId.toString(),},
        body: jsonEncode({'new_status': 'Shipping','notes': 'Shipper started delivery via app.',}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeliveryTrackingScreen(
              orderId: orderId,
              orderCode: orderCode,
              recipientName: order['recipient_name'],
              shippingAddress: order['address'],
            ),
          ),
        );

        // Luôn fetch lại danh sách đơn hàng sau khi DeliveryTrackingScreen đóng,
        // bất kể result là gì, để đảm bảo UI luôn cập nhật.
        _fetchOrdersForShipper();

      } else {
        String err = 'Xác nhận thất bại (Code: ${response.statusCode}).';
        try { final eData = jsonDecode(utf8.decode(response.bodyBytes)); err = eData['detail']?.toString() ?? eData['message']?.toString() ?? err; } catch (_) {}
        _showErrorSnackBar(err);
      }
    } on TimeoutException { _showErrorSnackBar('Yêu cầu xác nhận quá thời gian.');
    } on http.ClientException catch (e) { _showErrorSnackBar('Lỗi kết nối khi xác nhận: ${e.message}');
    } catch (e) { _showErrorSnackBar('Lỗi không mong muốn khi xác nhận: ${e.toString()}'); }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red[600],));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách đơn hàng'), // Đổi title cho phù hợp
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)], begin: Alignment.topLeft, end: Alignment.bottomRight,),),),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingOrders
          ? const Center(child: CircularProgressIndicator())
          : _ordersError != null
          ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Text(_ordersError!, style: GoogleFonts.poppins(color: Colors.red[700], fontSize: 16), textAlign: TextAlign.center), const SizedBox(height: 10), ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text("Thử lại"), onPressed: _fetchOrdersForShipper,)],),))
          : _orders.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Text("Không có đơn hàng nào được gán.", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center,)])) // Cập nhật thông báo
          : RefreshIndicator(
        onRefresh: _fetchOrdersForShipper,
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            final order = _orders[index];
            final String currentStatus = order['status'].toString().toLowerCase();
            bool canStartShipping = currentStatus == 'confirmed';
            bool isShipping = currentStatus == 'shipping';

            return FadeInUp(
              duration: Duration(milliseconds: 300 + (index * 80)),
              child: Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // Luôn cho phép xem chi tiết đơn hàng
                    Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailScreen(orderId: order['id'].toString(), orderCode: order['order_code'].toString(),),),);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text('Mã ĐH: ${order['order_code']}', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: const Color(0xFF2D3748),),)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                              decoration: BoxDecoration(
                                  color: _getStatusColor(order['status']).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                order['status'],
                                style: GoogleFonts.poppins(fontSize: 13, color: _getStatusColor(order['status']), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16, thickness: 0.5),
                        _buildInfoRow(Icons.receipt_long_outlined, "Người nhận:", order['recipient_info'] ?? 'N/A'),
                        _buildInfoRow(Icons.location_on_outlined, "Địa chỉ:", order['address'] ?? 'N/A'),
                        _buildInfoRow(Icons.attach_money_outlined, "Tổng tiền:", "${(order['total_amount'] as double).toStringAsFixed(0)} VND"),
                        const SizedBox(height: 12),

                        if (canStartShipping)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.local_shipping_outlined, size: 20),
                            label: const Text('Bắt đầu giao hàng'),
                            onPressed: () => _startShipping(order),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              backgroundColor: Colors.orange.shade700,
                            ),
                          ),
                        if (isShipping)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.track_changes_outlined, size: 20),
                            label: const Text('Theo dõi đơn hàng'),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DeliveryTrackingScreen(
                                    orderId: order['id'].toString(),
                                    orderCode: order['order_code'].toString(),
                                    recipientName: order['recipient_name'],
                                    shippingAddress: order['address'],
                                  ),
                                ),
                              );
                              // Luôn fetch lại danh sách đơn hàng sau khi DeliveryTrackingScreen đóng
                              _fetchOrdersForShipper();
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        // Hiển thị trạng thái text nếu không có nút action đặc biệt
                        if (!canStartShipping && !isShipping)
                          Row(
                            children: [
                              Icon(_getStatusIcon(order['status']), size: 18, color: _getStatusColor(order['status'])),
                              const SizedBox(width: 6),
                              Text('Trạng thái: ${order['status']}', style: GoogleFonts.poppins(fontSize: 14, color: _getStatusColor(order['status']), fontWeight: FontWeight.w500,),),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  Widget _buildInfoRow(IconData icon, String label, String value) { return Padding( padding: const EdgeInsets.symmetric(vertical: 3.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [ Icon(icon, size: 16, color: Colors.blueGrey[600]), const SizedBox(width: 8), Text(label, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w500)), const SizedBox(width: 4), Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF2D3748)), maxLines: 2, overflow: TextOverflow.ellipsis,)),],),); }
}




class ReturnRequestsScreen extends StatefulWidget {
  const ReturnRequestsScreen({super.key});
  @override
  _ReturnRequestsScreenState createState() => _ReturnRequestsScreenState();
}

class _ReturnRequestsScreenState extends State<ReturnRequestsScreen> {
  List<Map<String, dynamic>> _returnRequests = [];
  bool _isLoadingReturns = true;
  String? _returnsError;

  @override
  void initState() {
    super.initState();
    _fetchReturnRequests();
  }

  Future<void> _fetchReturnRequests({bool isRefreshing = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingReturns = true;
      if (isRefreshing) _returnsError = null;
      if (isRefreshing || _returnRequests.isNotEmpty) {
        _returnRequests.clear();
      }
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? shipperUserId = prefs.getInt('backend_user_id');
      if (shipperUserId == null) {
        throw Exception('Shipper User ID not found. Vui lòng đăng nhập lại.');
      }

      String apiUrlString = 'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/shipper/returns/requests?skip=0&limit=50';

      final Uri apiUrl = Uri.parse(apiUrlString);
      final response = await http.get(
        apiUrl,
        headers: {
          'accept': 'application/json',
          'X-User-ID': shipperUserId.toString(),
        },
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            List<Map<String, dynamic>> newRequests = responseData.map((req) {
              String productName = 'N/A';
              if (req['order'] != null &&
                  req['order']['items'] != null &&
                  (req['order']['items'] as List).isNotEmpty) {
                var firstItem = req['order']['items'][0];
                if (firstItem['variant'] != null &&
                    firstItem['variant']['variant_name'] != null) {
                  productName = firstItem['variant']['variant_name'];
                }
              } else if (req['serial_info'] != null &&
                  req['serial_info']['variant'] != null &&
                  req['serial_info']['variant']['variant_name'] != null) {
                productName = req['serial_info']['variant']['variant_name'];
              }

              String? serialCode = req['serial_info']?['serial_code'] as String?;
              String? orderShippingAddress = req['order']?['shipping_address'] as String?;
              orderShippingAddress ??= req['user']?['shipping_address'] as String?;

              String? deliveryAddressForExchange;
              if (req['return_type']?.toString().toLowerCase() == 'exchange' && req['replacement_serial_info'] != null) {
                deliveryAddressForExchange = req['order']?['shipping_address'] as String?;
              }

              return {
                'id': req['return_id']?.toString() ?? 'N/A',
                'code': req['code'] ?? 'N/A',
                'order_id': req['order_id']?.toString() ?? 'N/A',
                'order_code': req['order']?['order_code'] ?? 'N/A',
                'status': req['status']?.toString().toLowerCase() ?? 'unknown',
                'reason': req['reason'] ?? 'N/A',
                'customer_name': req['user']?['full_name'] ?? 'N/A',
                'customer_phone': req['user']?['phone_number'] ?? 'N/A',
                'customer_address': req['user']?['shipping_address'] ?? 'N/A',
                'return_type': req['return_type']?.toString().toLowerCase() ?? 'n/a',
                'pickup_address': orderShippingAddress ?? 'N/A',
                'delivery_address': deliveryAddressForExchange,
                'product_name': productName,
                'serial_code': serialCode,
                'shipping_address_original_order': orderShippingAddress ?? 'N/A',
                'date_requested': _formatDateTime(req['created_at']),
                // Vẫn lấy pickup_shipper_id và delivery_shipper_id để hiển thị thông tin chung nếu cần
                // nhưng không dùng để quyết định hiển thị nút cho 'success_shipping' và 'reject_shipping'
                'pickup_shipper_id': req['pickup_shipper_id'],
                'delivery_shipper_id': req['delivery_shipper_id'],
                'current_shipper_id': shipperUserId,
              };
            }).toList();

            _returnRequests = newRequests;
            _isLoadingReturns = false;
          });
        }
      } else {
        String err = 'Không thể tải yêu cầu trả hàng (Code: ${response.statusCode})';
        try {
          final eData = jsonDecode(utf8.decode(response.bodyBytes));
          err = eData['detail']?.toString() ?? eData['message']?.toString() ?? err;
        } catch (_) {}
        throw Exception(err);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReturns = false;
          _returnsError = "Không thể tải yêu cầu trả hàng: ${e.toString().replaceFirst("Exception: ", "")}";
        });
      }
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return 'N/A';
    try {
      final DateTime dateTime = DateTime.parse(dateTimeString).toLocal();
      return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}";
    } catch (e) {
      return dateTimeString;
    }
  }

  Color _getReturnStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.blueGrey.shade600;
      case 'approved': return Colors.blue.shade700;
      case 'pickup_scheduled': return Colors.lightBlue.shade700;
      case 'picked_up': return Colors.cyan.shade700;
      case 'received': return Colors.indigo.shade600;
      case 'checking': return Colors.orange.shade700;
      case 'delivery_scheduled': return Colors.purple.shade400;
      case 'exchanged': return Colors.teal.shade600;
      case 'refunded': return Colors.lime.shade700;
      case 'completed': return Colors.green.shade700;
      case 'cancelled': return Colors.grey.shade700;
      case 'rejected': return Colors.red.shade700;
      case 'failed_pickup': return Colors.red.shade400;
      case 'failed_exchange_delivery': return Colors.red.shade400;
      case 'success_shipping': return Colors.lightGreen.shade600;
      case 'reject_shipping': return Colors.orange.shade900;
      default: return Colors.black54;
    }
  }

  IconData _getReturnStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Icons.hourglass_empty_rounded;
      case 'approved': return Icons.thumb_up_alt_outlined;
      case 'pickup_scheduled': return Icons.local_shipping_outlined;
      case 'picked_up': return Icons.inventory_2_outlined;
      case 'received': return Icons.warehouse_outlined;
      case 'checking': return Icons.rule_folder_outlined;
      case 'delivery_scheduled': return Icons.delivery_dining_outlined;
      case 'exchanged': return Icons.sync_alt_rounded;
      case 'refunded': return Icons.price_check_rounded;
      case 'completed': return Icons.check_circle_outline_rounded;
      case 'cancelled': return Icons.do_not_disturb_alt_outlined;
      case 'rejected': return Icons.cancel_outlined;
      case 'failed_pickup': return Icons.running_with_errors_outlined;
      case 'failed_exchange_delivery': return Icons.no_transfer_outlined;
      case 'success_shipping': return Icons.thumb_up_rounded;
      case 'reject_shipping': return Icons.thumb_down_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  Future<void> _updateReturnStatus(Map<String, dynamic> request, String newStatus) async {
    if (!mounted) return;
    final returnId = request['id'];
    final returnCode = request['code'];
    final String currentStatusFromRequest = request['status']; // Lấy status hiện tại từ request

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        String actionText = "";
        if (newStatus == 'received' && currentStatusFromRequest == 'approved') {
          actionText = 'Xác nhận ĐÃ NHẬN HÀNG từ khách';
        } else if (newStatus == 'completed' && currentStatusFromRequest == 'success_shipping') {
          actionText = 'Xác nhận HOÀN TẤT yêu cầu';
        } else if (newStatus == 'rejected' && currentStatusFromRequest == 'reject_shipping') {
          actionText = 'Xác nhận TỪ CHỐI yêu cầu';
        } else {
          actionText = 'cập nhật trạng thái từ "$currentStatusFromRequest" thành "$newStatus"';
        }
        return AlertDialog(
          title: Text('Xác nhận hành động', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text('Bạn có chắc muốn $actionText cho YC #$returnCode?', style: GoogleFonts.poppins()),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: <Widget>[
            TextButton(
              child: Text('Hủy', style: GoogleFonts.poppins(color: Colors.grey[700])),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              child: const Text('Xác nhận'),
              style: ElevatedButton.styleFrom(backgroundColor: _getReturnStatusColor(newStatus)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      if (currentStatusFromRequest != newStatus) {
        _fetchReturnRequests(isRefreshing: true);
      }
      return;
    }

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đang cập nhật YC #$returnCode...'), duration: const Duration(seconds: 3)));

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? shipperUserId = prefs.getInt('backend_user_id');
      if (shipperUserId == null) throw Exception('Shipper User ID not found.');

      final updateApiUrl = Uri.parse('https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/shipper/returns/requests/$returnId/status');
      final response = await http.put(
        updateApiUrl,
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'X-User-ID': shipperUserId.toString(),
        },
        body: jsonEncode({
          'new_status': newStatus,
          'notes': 'Cập nhật bởi shipper $shipperUserId từ trạng thái "$currentStatusFromRequest" qua ứng dụng.'
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('YC #$returnCode đã cập nhật thành "$newStatus"'),
            backgroundColor: Colors.green[600],
          ));
          _fetchReturnRequests(isRefreshing: true);
        }
      } else {
        String err = 'Cập nhật thất bại (Code: ${response.statusCode}).';
        try {
          final eData = jsonDecode(utf8.decode(response.bodyBytes));
          err = eData['detail']?.toString() ?? eData['message']?.toString() ?? err;
        } catch (_) {}
        throw Exception(err);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi cập nhật YC #$returnCode: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red[600],
        ));
        _fetchReturnRequests(isRefreshing: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yêu cầu đổi trả'),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingReturns && _returnRequests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _returnsError != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_returnsError!, style: GoogleFonts.poppins(color: Colors.red[700], fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Thử lại"),
                onPressed: () => _fetchReturnRequests(isRefreshing: true),
              ),
            ],
          ),
        ),
      )
          : _returnRequests.isEmpty
          ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Không có yêu cầu đổi trả nào được gán cho bạn.", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Làm mới"),
                onPressed: () => _fetchReturnRequests(isRefreshing: true),
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1), foregroundColor: Theme.of(context).primaryColor),
              ),
            ],
          ))
          : RefreshIndicator(
        onRefresh: () => _fetchReturnRequests(isRefreshing: true),
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: _returnRequests.length,
          itemBuilder: (context, index) {
            final request = _returnRequests[index];
            final String currentStatus = request['status'];

            bool showProcessApprovedButton = false;
            bool showCompleteSuccessShippingButton = false;
            bool showConfirmRejectShippingButton = false;

            // Nút 1: 'approved' -> 'received'
            // Điều kiện: status là 'approved' VÀ shipper hiện tại là pickup_shipper_id
            if (currentStatus == 'approved') {
              showProcessApprovedButton = true;
            }

            // Nút 2: 'success_shipping' -> 'completed'
            // Điều kiện: CHỈ status là 'success_shipping'
            if (currentStatus == 'success_shipping') {
              showCompleteSuccessShippingButton = true;
            }

            // Nút 3: 'reject_shipping' -> 'rejected'
            // Điều kiện: CHỈ status là 'reject_shipping'
            if (currentStatus == 'reject_shipping') {
              showConfirmRejectShippingButton = true;
            }

            // Thông tin taskTypeDisplay, taskAddress, taskTitle (vẫn giữ để hiển thị thông tin chung)
            String taskTypeDisplay = "";
            String taskAddress = 'N/A';
            String taskTitle = "";
            final String? originalOrderShippingAddress = request['shipping_address_original_order'] as String?;
            final String? deliveryAddressForExchangeFromRequest = request['delivery_address'] as String?;
            final String returnType = request['return_type']; // Lấy lại để hiển thị loại YC


            final String? serialCode = request['serial_code'] as String?;
            final String productName = request['product_name'] as String? ?? 'N/A';
            final String productDisplay = serialCode ?? productName;
            final String productLabel = serialCode != null ? "Serial:" : "Sản phẩm:";
            final IconData productIcon = serialCode != null ? Icons.qr_code_scanner_rounded : Icons.inventory_2_outlined;

            List<String> editableStatusesForShipper = [];
            if (taskTypeDisplay == "pickup" && (currentStatus == 'approved' || currentStatus == 'pickup_scheduled')) {
              editableStatusesForShipper = [currentStatus, 'pickup_scheduled', 'picked_up', 'failed_pickup'];
            } else if (taskTypeDisplay == "delivery_exchange" && currentStatus == 'delivery_scheduled') {
              editableStatusesForShipper = [currentStatus, 'exchanged', 'failed_exchange_delivery'];
            } else {
              editableStatusesForShipper = [currentStatus];
            }
            if (!editableStatusesForShipper.contains(currentStatus)) {
              editableStatusesForShipper.insert(0, currentStatus);
            }
            editableStatusesForShipper = editableStatusesForShipper.toSet().toList();

            bool canShowDropdown = editableStatusesForShipper.length > 1 &&
                !showProcessApprovedButton &&
                !showCompleteSuccessShippingButton &&
                !showConfirmRejectShippingButton;

            return FadeInUp(
              duration: Duration(milliseconds: 300 + (index * 80)),
              child: Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'YC #${request['code']} (ĐH: ${request['order_code']})',
                              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: const Color(0xFF2D3748)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (showProcessApprovedButton)
                            ElevatedButton.icon(
                              icon: Icon(Icons.inventory_outlined, size: 18, color: Colors.white.withOpacity(0.9)),
                              label: Text('Đã nhận hàng', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                              onPressed: () => _updateReturnStatus(request, 'received'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getReturnStatusColor('received').withOpacity(0.9),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            )
                          else if (showCompleteSuccessShippingButton)
                            ElevatedButton.icon(
                              icon: Icon(Icons.check_circle_outline, size: 18, color: Colors.white.withOpacity(0.9)),
                              label: Text('Hoàn tất YC', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                              onPressed: () => _updateReturnStatus(request, 'completed'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getReturnStatusColor('completed').withOpacity(0.9),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            )
                          else if (showConfirmRejectShippingButton)
                              ElevatedButton.icon(
                                icon: Icon(Icons.cancel_outlined, size: 18, color: Colors.white.withOpacity(0.9)),
                                label: Text('Từ chối YC', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                                onPressed: () => _updateReturnStatus(request, 'rejected'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getReturnStatusColor('rejected').withOpacity(0.9),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              )
                            else if (canShowDropdown)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  decoration: BoxDecoration(color: _getReturnStatusColor(currentStatus).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: currentStatus,
                                      icon: Icon(Icons.arrow_drop_down, color: _getReturnStatusColor(currentStatus)),
                                      items: editableStatusesForShipper.map((String statusValue) {
                                        return DropdownMenuItem<String>(
                                          value: statusValue,
                                          child: Text(statusValue, style: GoogleFonts.poppins(fontSize: 14, color: _getReturnStatusColor(statusValue))),
                                        );
                                      }).toList(),
                                      onChanged: (newStatus) {
                                        if (newStatus != null && newStatus != currentStatus) {
                                          _updateReturnStatus(request, newStatus);
                                        }
                                      },
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                                  decoration: BoxDecoration(color: _getReturnStatusColor(currentStatus).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                  child: Text(currentStatus, style: GoogleFonts.poppins(fontSize: 13, color: _getReturnStatusColor(currentStatus), fontWeight: FontWeight.w600)),
                                ),
                        ],
                      ),
                      const Divider(height: 16, thickness: 0.5),

                      if (taskTypeDisplay.isNotEmpty && taskTitle.isNotEmpty)
                        _buildInfoRowReturn(
                          taskTypeDisplay == "pickup" ? Icons.arrow_upward_rounded : Icons.delivery_dining_outlined,
                          taskTitle,
                          taskAddress,
                          highlight: true,
                        ),
                      if (taskTypeDisplay.isNotEmpty && taskTitle.isNotEmpty) const SizedBox(height: 5),

                      _buildInfoRowReturn(Icons.person_pin_circle_outlined, "Khách hàng:", "${request['customer_name']} - ${request['customer_phone']}"),
                      _buildInfoRowReturn(productIcon, productLabel, productDisplay),
                      _buildInfoRowReturn(Icons.info_outline_rounded, "Loại YC:", returnType == 'refund' ? 'Hoàn tiền' : 'Đổi hàng'),
                      if (originalOrderShippingAddress != null && originalOrderShippingAddress.isNotEmpty && originalOrderShippingAddress != taskAddress)
                        _buildInfoRowReturn(Icons.home_work_outlined, "Đ/c đơn gốc:", originalOrderShippingAddress),
                      const SizedBox(height: 8),

                      if (!showProcessApprovedButton && !showCompleteSuccessShippingButton && !showConfirmRejectShippingButton && !canShowDropdown)
                        Row(
                          children: [
                            Icon(_getReturnStatusIcon(currentStatus), size: 18, color: _getReturnStatusColor(currentStatus)),
                            const SizedBox(width: 6),
                            Text('Trạng thái: $currentStatus', style: GoogleFonts.poppins(fontSize: 14, color: _getReturnStatusColor(currentStatus), fontWeight: FontWeight.w500)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRowReturn(IconData icon, String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: highlight ? Theme.of(context).primaryColor : Colors.blueGrey[600]),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 14, color: highlight ? Theme.of(context).primaryColor : Colors.grey[800], fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 14, color: highlight ? Theme.of(context).primaryColor.withOpacity(0.9) : const Color(0xFF2D3748), fontWeight: highlight ? FontWeight.w600 : FontWeight.normal),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}