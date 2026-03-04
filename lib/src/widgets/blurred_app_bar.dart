import 'dart:ui';

import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/src/widgets/button.dart';

class BlurredAppBar extends StatelessWidget implements PreferredSizeWidget {
 const BlurredAppBar({super.key, required this.title, this.subtitle, required this.actions, this.showLeading = false});

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showLeading;

  @override
  AppBar build(BuildContext context) {
    return AppBar(
      clipBehavior: Clip.none,
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
      leading: 
      showLeading 
      ? Transform.scale(
        scale: 0.8,
        child: Button.iconOnly(
          onPressed: () => Navigator.pop(context),
          icon: Icon(CupertinoIcons.back),
          glassIcon: CNSymbol('chevron.left', size: 20),
        ) 
      ) : null,

      titleSpacing: 10,

      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null)
          Text(
              subtitle!, 
              style: TextStyle(
              color: Colors.white.withAlpha(230),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      backgroundColor: Colors.transparent,
      actions: actions,
    );  
  }
  
  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ?  kToolbarHeight + 10 : kToolbarHeight - 10);
}
