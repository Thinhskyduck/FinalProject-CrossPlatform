import 'package:flutter/material.dart';

class GridviewProductModel {
  final String imageUrl;
  final String title;
  final VoidCallback onTap;
  final String category;


  GridviewProductModel({
    required this.imageUrl,
    required this.title,
    required this.onTap,
    required this.category,
  });
}
