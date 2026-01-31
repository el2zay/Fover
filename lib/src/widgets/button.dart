import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/material.dart';
import 'package:fover/main.dart';

class Button extends StatelessWidget {
  const Button({
    super.key,
    this.label,
    this.icon,
    this.glassIcon,
    this.tint,
    this.backgroundColor,
    this.glassConfig = const CNButtonConfig(),
    this.padding,
    required this.onPressed,
  });

  final String? label;
  final Icon? icon;
  final CNSymbol? glassIcon;
  final Color? tint;
  final Color? backgroundColor;
  final CNButtonConfig? glassConfig;
  final EdgeInsetsGeometry? padding;
  final VoidCallback onPressed;

  // TODO :
  static Widget iconOnly({
    required VoidCallback onPressed,
    Icon? icon,
    CNSymbol? glassIcon,
    Color? tint,
    Color? backgroundColor,
    CNButtonConfig? glassConfig,
    EdgeInsetsGeometry? padding,
  }) {
    return is26OrNewer
        ? CNButton.icon(
            icon: glassIcon,
            tint: tint,
            config: glassConfig ?? const CNButtonConfig(),
            onPressed: onPressed,
          )
        : IconButton(
            icon: icon!,
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              alignment: Alignment.centerRight,
              padding: padding ?? const EdgeInsets.all(12),
              iconSize: 25,
              shape: const CircleBorder(),
              backgroundColor: backgroundColor ?? Colors.white12,
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return is26OrNewer
        ? CNButton(
            label: label,
            icon: glassIcon,
            tint: tint,
            config: glassConfig!,
            onPressed: onPressed,
          )
        : ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              backgroundColor: Colors.white12
            ),
            child: icon ?? Text(label ?? ''),
          );
  }
}
