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
    this.glassConfig = const CNButtonConfig(),
    required this.onPressed,
  });

  final String? label;
  final Icon? icon;
  final CNSymbol? glassIcon;
  final Color? tint;
  final CNButtonConfig? glassConfig;
  final VoidCallback onPressed;

  // TODO :
  static Widget iconOnly({
    required VoidCallback onPressed,
    Icon? icon,
    CNSymbol? glassIcon,
    Color? tint,
    CNButtonConfig? glassConfig,
  }) {
    return is26OrNewer
        ? CNButton.icon(
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
              backgroundColor: Colors.white12,
            ),
            child: icon
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
