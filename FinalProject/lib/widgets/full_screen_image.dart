import 'dart:convert';

import 'package:flutter/material.dart';

class FullScreenImage extends StatelessWidget {
  final String imageData;

  const FullScreenImage({Key? key, required this.imageData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: imageData,
            child: Image.memory(
              base64Decode(imageData.split(',')[1]),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
