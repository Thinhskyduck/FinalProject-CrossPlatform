import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChangeProfile extends StatefulWidget {
  final String uid;

  const ChangeProfile({super.key, required this.uid});

  @override
  State<ChangeProfile> createState() => _ChangeProfileState();
}

class _ChangeProfileState extends State<ChangeProfile> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String? _errorMessage;

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _emailController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print("ChangeProfile: Loading user data for backend ID: ${widget.uid}");
    try {
      final apiUrl = Uri.parse(
          'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/auth/auth/users/me');
      final response = await http.get(
        apiUrl,
        headers: {
          'accept': 'application/json',
          'X-User-ID': widget.uid,
        },
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("ChangeProfile: User data received: $data");
        setState(() {
          _fullNameController.text = data['full_name'] ?? '';
          _phoneController.text = data['phone_number'] ?? '';
          _addressController.text = data['shipping_address'] ?? '';
          _emailController.text = data['email'] ?? '';
        });
      } else {
        print(
            "ChangeProfile: Error loading data - Status: ${response.statusCode}, Body: ${response.body}");
        setState(() {
          _errorMessage = "Lỗi tải dữ liệu người dùng (${response.statusCode}).";
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      print("ChangeProfile: Timeout loading data.");
      setState(() {
        _errorMessage = "Hết thời gian tải dữ liệu.";
      });
    } on SocketException {
      if (!mounted) return;
      print("ChangeProfile: Network error loading data.");
      setState(() {
        _errorMessage = "Lỗi mạng khi tải dữ liệu.";
      });
    } catch (e) {
      if (!mounted) return;
      print("ChangeProfile: Unexpected error loading data: $e");
      setState(() {
        _errorMessage = "Lỗi không xác định khi tải dữ liệu.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print("ChangeProfile: Saving profile for backend ID: ${widget.uid}");
      try {
        final apiUrl = Uri.parse(
            'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/auth/auth/users/me');
        final body = jsonEncode({
          "full_name": _fullNameController.text.trim(),
          "phone_number": _phoneController.text.trim(),
          "shipping_address": _addressController.text.trim(),
        });
        print("ChangeProfile: Request body: $body");

        final response = await http.put(
          apiUrl,
          headers: {
            'accept': 'application/json',
            'X-User-ID': widget.uid,
            'Content-Type': 'application/json',
          },
          body: body,
        ).timeout(const Duration(seconds: 15));

        if (!mounted) return;

        print(
            "ChangeProfile: Save response status: ${response.statusCode}, body: ${response.body}");
        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cập nhật hồ sơ thành công!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else {
          String errorMsg = "Lỗi cập nhật hồ sơ (${response.statusCode}).";
          try {
            final errorData = jsonDecode(response.body);
            errorMsg +=
            " ${errorData['detail'] ?? errorData['message'] ?? 'Vui lòng thử lại.'}";
          } catch (_) {
            errorMsg += " Vui lòng thử lại.";
          }
          if (mounted) {
            setState(() {
              _errorMessage = errorMsg;
            });
          }
        }
      } on TimeoutException {
        if (!mounted) return;
        print("ChangeProfile: Timeout saving profile.");
        setState(() {
          _errorMessage = "Hết thời gian cập nhật.";
        });
      } on SocketException {
        if (!mounted) return;
        print("ChangeProfile: Network error saving profile.");
        setState(() {
          _errorMessage = "Lỗi mạng khi lưu.";
        });
      } catch (e) {
        if (!mounted) return;
        print("ChangeProfile: Unexpected error saving profile: $e");
        setState(() {
          _errorMessage = "Lỗi không xác định khi lưu.";
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      print("ChangeProfile: Form validation failed.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        title: const Text("Chỉnh sửa Hồ sơ"),
      ),
      body: _isLoading && _errorMessage == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: "Họ và tên",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập họ và tên';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: "Số điện thoại",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập số điện thoại';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: "Địa chỉ giao hàng",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                maxLines: null,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập địa chỉ giao hàng';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email (Không thể thay đổi)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                readOnly: true,
                enabled: false,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 35),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                      if (states.contains(MaterialState.disabled)) {
                        return primaryColor.withOpacity(0.5);
                      }
                      return primaryColor;
                    },
                  ),
                  foregroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                      if (states.contains(MaterialState.disabled)) {
                        return Colors.white.withOpacity(0.8);
                      }
                      return Colors.white;
                    },
                  ),
                  padding: MaterialStateProperty.all<EdgeInsets>(
                    const EdgeInsets.symmetric(vertical: 14),
                  ),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textStyle: MaterialStateProperty.all<TextStyle>(
                    const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  elevation: MaterialStateProperty.all<double>(2),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text("Lưu thay đổi"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}