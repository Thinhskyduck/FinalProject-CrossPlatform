import 'package:flutter/material.dart';

class BottomNavModel {
  final Widget page;
  final GlobalKey<NavigatorState> navKey;

  BottomNavModel({required this.page, required this.navKey});
}
