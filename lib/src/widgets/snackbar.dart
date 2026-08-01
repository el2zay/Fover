import 'dart:ui';

import 'package:flutter/material.dart';

class MySnackBar {
  static void show({BuildContext? context, String? message, IconData? icon}) {
    final snackBar = SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: Container(
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              SizedBox(width: 8),
              Icon(icon, color: Colors.white.withAlpha(204)),
              SizedBox(width: 8),
              Text(
                message!, 
                style: TextStyle(
                  color: Colors.white.withAlpha(220), 
                  fontWeight: FontWeight.w500, 
                  fontSize: 16
                ),
              ),
            ],
          )
        ),
      ),
    );
    ScaffoldMessenger.of(context!).showSnackBar(snackBar);
  }
}