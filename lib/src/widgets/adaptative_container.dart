import 'dart:ui';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/material.dart';
import 'package:fover/main.dart';

class AdaptativeContainer extends StatelessWidget {
  const AdaptativeContainer({super.key, required this.config, required this.child, required this.padding});
  final LiquidGlassConfig config;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return is26OrNewer ? LiquidGlassContainer(config: config , child: child) :
     BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: 
    Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child:child,
      ),
    );
  }
}