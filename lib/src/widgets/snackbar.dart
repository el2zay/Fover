import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fover/main.dart';

class MySnackBar {
  static void show({BuildContext? context, String? message, IconData? icon}) {
    final snackBar = SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            // color: Colors.greenAccent,
            border: Border.all(color: box.get("primaryColor"), width: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
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