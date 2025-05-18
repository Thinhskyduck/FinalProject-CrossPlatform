import 'package:cross_platform_mobile_app_development/screens/home_screen.dart';
import 'package:cross_platform_mobile_app_development/screens/login.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-commerce App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(),
        '/login': (context) => Login(),
        // '/products': (context) => ProductListScreen(),
      },
      // Optional: Handle unknown routes
      onUnknownRoute: (settings) {
        return null;

        // return MaterialPageRoute(builder: (context) => HomeScreen());
      },
    );
  }
}
