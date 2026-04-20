import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/material.dart';
import 'package:fover/main.dart';

class MyContainer extends StatelessWidget {
  final Widget child;
  const MyContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return is26OrNewer 
      ? LiquidGlassContainer(
        config: LiquidGlassConfig(
          shape: CNGlassEffectShape.rect,
          cornerRadius: 20
        ),
        child: child, 
      ) : Container(
        decoration: BoxDecoration(
          color: Theme.brightnessOf(context) == Brightness.light ? Colors.grey[300] : Colors.grey[900],
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: child,
      );
  }
}