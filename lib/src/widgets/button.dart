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
    this.textColor,
    this.glassConfig = const CNButtonConfig(),
    this.padding,
    this.enabled = true,
    required this.onPressed,
  });

  final String? label;
  final Icon? icon;
  final CNSymbol? glassIcon;
  final Color? tint;
  final Color? backgroundColor;
  final Color? textColor;
  final CNButtonConfig? glassConfig;
  final EdgeInsetsGeometry? padding;
  final bool enabled;
  final VoidCallback onPressed;

  static Widget iconOnly({
    required VoidCallback onPressed,
    Icon? icon,
    CNSymbol? glassIcon,
    Color? tint,
    Color? backgroundColor,
    CNButtonConfig? glassConfig,
    EdgeInsetsGeometry? padding,
    bool enabled = true,
  }) {
    return is26OrNewer
        ? CNButton.icon(
            icon: glassIcon,
            tint: tint,
            config: glassConfig ?? const CNButtonConfig(),
            enabled: enabled,
            onPressed: enabled ? onPressed : null,
          )
        : IconButton(
            icon: icon!,
            onPressed: enabled ? onPressed : null,
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
            onPressed: enabled ? onPressed : null ,
            enabled: enabled,
          )
        : ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              disabledBackgroundColor: backgroundColor ?? Colors.white12,
              backgroundColor: backgroundColor ?? Colors.white12,
              textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)
            ),
            child: icon ?? Text(label ?? '', style: TextStyle(color: enabled ? Colors.black : Colors.grey[700])),
          );
  }
}
