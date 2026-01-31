import 'dart:ui';

import 'package:flutter/material.dart';

class BlurredAppBar extends StatelessWidget implements PreferredSizeWidget {
 const BlurredAppBar({super.key, required this.title, required this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  AppBar build(BuildContext context) {
    return buildBlurredAppBar(title: title, actions: actions);
  }
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

AppBar buildBlurredAppBar({required String title, List<Widget>? actions}) {
  return AppBar(
    elevation: 0,
    centerTitle: false,
    flexibleSpace: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(150),
                Colors.black.withAlpha(150),
                Colors.black.withAlpha(25),
              ],
            ),
          ),
        ),
      ),
    ),
    title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
    backgroundColor: Colors.transparent,
    actions: actions,
  );
}