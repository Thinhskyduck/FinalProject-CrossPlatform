import 'dart:async';
import 'dart:convert'; // Cho utf8, jsonEncode, jsonDecode
import 'dart:io'; // For SocketException

import 'package:cross_platform_mobile_app_development/screens/reset_password.dart'; // Giữ đường dẫn thực tế của bạn
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart'; // Giữ đường dẫn thực tế của bạn
import 'signup.dart'; // Giữ đường dẫn thực tế của bạn

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Firebase API Key (Web API Key for your Firebase project)
  final String FIREBASE_API_KEY = "AIzaSyBrt45E927d_oAoVqUx1t_SW51wZGcnm48"; // Giữ API Key của bạn

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập email và mật khẩu.';
        _isLoading = false; // Đảm bảo reset isLoading
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Gửi request đến Firebase Authentication
      final firebaseAuthUrl = Uri.parse(
          "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$FIREBASE_API_KEY");
      final firebasePayload = {
        "email": _emailController.text.trim(),
        "password": _passwordController.text.trim(),
        "returnSecureToken": true,
      };

      final firebaseResponse = await http.post(
        firebaseAuthUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(firebasePayload),
      ).timeout(const Duration(seconds: 15));

      // Sử dụng utf8.decode cho Firebase response để đảm bảo (mặc dù thường không cần)
      final decodedFirebaseBody = utf8.decode(firebaseResponse.bodyBytes);
      final firebaseResult = jsonDecode(decodedFirebaseBody);
      print("Firebase Response: $firebaseResult");
      print("Firebase Status Code: ${firebaseResponse.statusCode}");

      if (firebaseResponse.statusCode == 200 && firebaseResult['idToken'] != null) {
        String? firebaseUserId = firebaseResult['localId'] as String?;
        print("Firebase UID: $firebaseUserId");

        if (firebaseUserId == null) {
          setState(() { // setState này sẽ được bao trong try-finally
            _errorMessage = 'Không thể lấy user_id từ Firebase.';
          });
          return; // Dừng sớm, isLoading sẽ được reset bởi finally
        }

        // 2. Gọi API Backend để xác thực với firebase_uid
        final apiUrl = Uri.parse('https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/auth/login-success');

        final apiResponse = await http.post(
          apiUrl,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "firebase_uid": firebaseUserId,
          }),
        ).timeout(const Duration(seconds: 10));

        // LUÔN DECODE PHẢN HỒI TỪ API BACKEND BẰNG UTF-8
        final decodedApiResponseBody = utf8.decode(apiResponse.bodyBytes);
        print("Backend API Response Status: ${apiResponse.statusCode}");
        print("Backend API Response Body (decoded): $decodedApiResponseBody");

        if (apiResponse.statusCode == 200) {
          final userData = jsonDecode(decodedApiResponseBody);
          print("Backend User Data (parsed): $userData");

          bool? isActive = userData['is_active'] as bool?;
          if (isActive == null || !isActive) {
            // Không cần setState cho isLoading ở đây, finally sẽ xử lý
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Tài khoản bị vô hiệu hóa'),
                content: const Text('Tài khoản của bạn chưa được kích hoạt hoặc đã bị vô hiệu hóa. Vui lòng liên hệ hỗ trợ.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return; // Dừng lại nếu tài khoản không active
          }

          if (userData['email'] == null || userData['full_name'] == null || userData['user_id'] == null) {
            setState(() { // setState này sẽ được bao trong try-finally
              _errorMessage = 'Dữ liệu người dùng từ server không đầy đủ.';
            });
            return; // Dừng sớm
          }

          try {
            final dynamic backendUserIdRaw = userData['user_id'];
            final String fullName = userData['full_name'] as String; // fullName này đã từ decodedApiResponseBody
            final String backendUserIdString = backendUserIdRaw.toString();
            // Lấy các thông tin khác nếu có từ API backend
            final String? avatarUrl = userData['avatar_url'] as String?;
            final String? phone = userData['phone'] as String?;
            // Email đã có từ Firebase, nhưng có thể lấy từ backend nếu muốn đồng bộ
            final String emailFromBackend = userData['email'] as String? ?? _emailController.text.trim();


            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_uid', backendUserIdString);
            await prefs.setString('user_fullName', fullName); // Lưu tên đã được decode đúng
            if (avatarUrl != null) await prefs.setString('user_avatarUrl', avatarUrl);
            if (phone != null) await prefs.setString('user_phone', phone);
            await prefs.setString('user_email', emailFromBackend); // Có thể lưu email từ backend


            print("Đã lưu Backend User ID ('${backendUserIdString}') và Full Name ('$fullName') vào SharedPreferences.");

            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
          } catch (e) {
            print("Lỗi khi lưu SharedPreferences: $e");
            if (mounted) {
              setState(() { _errorMessage = 'Lỗi lưu trạng thái đăng nhập.'; });
            }
          }
        } else { // Lỗi từ API Backend
          final errorData = jsonDecode(decodedApiResponseBody);
          String apiErrorMessage = 'Không thể xác minh người dùng với server.';
          if (errorData['detail'] != null) {
            apiErrorMessage = errorData['detail'].toString();
          } else if (errorData['message'] != null) {
            apiErrorMessage = errorData['message'].toString();
          }
          setState(() { // setState này sẽ được bao trong try-finally
            _errorMessage = 'Xác thực thất bại: $apiErrorMessage';
          });
        }
      } else { // Lỗi từ Firebase
        String errorDetail;
        if (firebaseResult['error'] != null && firebaseResult['error']['message'] != null) {
          switch (firebaseResult['error']['message']) {
            case 'EMAIL_NOT_FOUND':
              errorDetail = 'Email không tồn tại.';
              break;
            case 'INVALID_PASSWORD':
            case 'INVALID_LOGIN_CREDENTIALS':
              errorDetail = 'Mật khẩu không đúng.';
              break;
            case 'USER_DISABLED':
              errorDetail = 'Tài khoản đã bị vô hiệu hóa bởi quản trị viên.';
              break;
            case 'INVALID_EMAIL':
              errorDetail = 'Địa chỉ email không hợp lệ.';
              break;
            default:
              errorDetail = firebaseResult['error']['message']?.toString() ?? 'Lỗi không xác định từ Firebase.';
          }
        } else {
          errorDetail = 'Lỗi không xác định từ Firebase.';
        }
        setState(() { // setState này sẽ được bao trong try-finally
          _errorMessage = 'Đăng nhập thất bại: $errorDetail';
        });
      }
    } on SocketException {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không có kết nối internet. Vui lòng kiểm tra lại.';
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _errorMessage = 'Yêu cầu quá thời gian. Vui lòng thử lại.';
        });
      }
    } on http.ClientException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi kết nối: ${e.message}. Vui lòng thử lại sau.';
        });
      }
    } catch (e) {
      print("Lỗi không mong muốn trong _signIn: ${e.toString()}");
      if (mounted) {
        setState(() {
          _errorMessage = "Đã xảy ra lỗi: ${e.toString()}";
        });
      }
    } finally {
      // Đảm bảo _isLoading luôn được đặt lại nếu widget vẫn còn mounted
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primaryColor = Colors.blue[700]!;
    final Color lightBackgroundColor = Colors.blue[50]!;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor.withOpacity(0.6), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.5],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.storefront,
                      size: 80,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Welcome Back!",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please login to continue",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 40),

                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: "Enter your email",
                        prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: lightBackgroundColor,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 15.0),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _passwordController,
                      obscureText: _obscureText,
                      decoration: InputDecoration(
                        hintText: "Enter your password",
                        prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey[600],
                          ),
                          onPressed: () {
                            setState(() { _obscureText = !_obscureText; });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: lightBackgroundColor,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 15.0),
                      ),
                    ),
                    const SizedBox(height: 15),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: primaryColor,
                        ),
                        child: const Text("Forgot Password?"),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700], fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    SizedBox(
                      height: 50,
                      child: _isLoading
                          ? Center(child: CircularProgressIndicator(color: primaryColor))
                          : ElevatedButton(
                        onPressed: _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          "LOGIN",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                        ),
                        GestureDetector(
                          onTap: _isLoading ? null : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignUp()),
                            );
                          },
                          child: Text(
                            "Sign Up",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}