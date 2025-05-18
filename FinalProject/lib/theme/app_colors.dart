// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Colors from HomeScreen (or your central theme colors)
  static const Color themeBluePrimary = Color(0xFF007BFF);
  static const Color themeBlueDark = Color(0xFF0056b3);
  static const Color cpsTextBlack = Color(0xFF222222);
  static const Color cpsTextGrey = Color(0xFF4A4A4A);
  static const Color cpsSubtleTextGrey = Color(0xFF757575);
  static const Color cpsCardBorderColor = Color(0xFFE0E0E0);
  static const Color cpsStarYellow = Color(0xFFFFC107);

  // CellphoneS-like theme colors (đã đổi themeBluePrimary thành imageRedAccent trong code gốc của bạn)
  static const Color imageRedAccent = Color(0xFF007BFF); // Bạn đã đổi sang xanh
  static const Color imageLightRedBackground = Color(0xFFE0EFFF); // Màu này cũng theo xanh
  static const Color imagePageBackground = Color(0xFFF5F5F5);
  static const Color imageUpdateBannerBlue = Color(0xFFEBF4FF);

  // Tag colors
  static const Color sNullTagBackground = Color(0xFFFCE4EC); // Pinkish
  static const Color sNullTagText = Color(0xFFC2185B);      // Dark pink
  static const Color sStudentTagBackground = Color(0xFFE3F2FD); // Light blue
  static const Color sStudentTagText = Color(0xFF1E88E5);     // Blue

  // Theme page background (thường dùng cho scaffold)
  static const Color themePageBackground = Color(0xFFF0F2F5);

  // Other specific colors
  static const Color cpsInstallmentBlue = Color(0xFF007AFF);

  // You can add more colors as needed

  static const Color primaryRed = Color(0xFF007BFF);
  static const Color textBlack = Color(0xFF222222);
  static const Color textGrey = Color(0xFF4A4A4A);
  static const Color textLightGrey = Color(0xFF757575);
  static const Color borderGrey = Color(0xFFE0E0E0);
  static const Color lightGreyBackground = Color(0xFFF8F8F8);
}