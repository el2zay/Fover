import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MyDialog extends StatelessWidget {
  final String content;
  final TextButton? principalButton;
  final bool? needCancel;
  const MyDialog({super.key, required this.content, required this.principalButton, this.needCancel = true});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: LiquidGlassContainer(
          config: LiquidGlassConfig(
            shape: CNGlassEffectShape.rect,
            cornerRadius: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsetsGeometry.all(20),
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    content,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color.fromARGB(235, 255, 255, 255)),
                    textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Divider(thickness: 0.5, height: 1, color: Colors.white24),
                if (needCancel != false)
                Row(
                  mainAxisAlignment: principalButton != null ? MainAxisAlignment.spaceAround : MainAxisAlignment.center,
                  children: [
                    TextButton(
                      child: Text("Cancel", style: TextStyle(fontSize: 16, color: CupertinoColors.activeBlue)),
                      onPressed: () {
                        Navigator.pop(context);
                      }
                    ),
                    principalButton ?? SizedBox(width: 0)
                  ],
                )
              ]
            )
          )
        ),
    );
  }
}