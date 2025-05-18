import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class Base64ImageWidget extends StatelessWidget {
  final String base64String;

  const Base64ImageWidget({super.key, required this.base64String});

  @override
  Widget build(BuildContext context) {
    // Cắt bỏ "data:image/png;base64," nếu có
    final String base64Data = base64String.split(',').last;

    // Chuyển base64 thành Uint8List
    Uint8List bytes = base64Decode(base64Data);

    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.broken_image, size: 50);
      },
    );
  }
}
