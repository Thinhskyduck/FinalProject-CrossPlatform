import 'package:cross_platform_mobile_app_development/screens/check_out_infor_screen.dart';
import 'package:cross_platform_mobile_app_development/screens/check_out_screen.dart';
import 'package:cross_platform_mobile_app_development/screens/profile_screen.dart';
import 'package:cross_platform_mobile_app_development/screens/shipper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/product_detail.dart';

import 'package:flutter/material.dart';
import 'screens/cart_product.dart';
import 'screens/home_screen.dart';

import 'firebase_options.dart';
import 'screens/login.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      // home: const HomeScreen(),
      home: const Login(),

      // home: const CartScreen(),
      // home: const CheckoutPaymentScreen(),
      // home: const CheckoutInfoScreen(),
      // home: const ProductDetailsScreen2()
      // home: const AccountPage(),
      // home:  ShipperApp(),
    );
  }
}
