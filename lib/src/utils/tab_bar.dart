import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:fover/main.dart';

class TabBarDemoPage extends StatefulWidget {
  const TabBarDemoPage({
    super.key,
    required this.body
  });

  final Widget body;

  @override
  State<TabBarDemoPage> createState() => _TabBarDemoPageState();
}

class _TabBarDemoPageState extends State<TabBarDemoPage> {
  @override
  Widget build(BuildContext context) {
    if (is26OrNewer) return SizedBox();

    return Container(
      color: Colors.black.withAlpha(30),
      child: BottomBar(
        layout: const BottomBarLayout.adaptive(
          maxWidth: 400,
          offset: 32,
          borderRadius: BorderRadius.all(Radius.circular(32)),
          clip: Clip.none,
        ),
        scrollBehavior: const BottomBarScrollBehavior(
          hideOnScroll: false,
        ),
        motion: const BottomBarMotion.cupertino(
          preset: BottomBarCupertinoMotion.snappy,
          duration: Duration(milliseconds: 460),
          extraBounce: 0.03,
        ),
        theme: BottomBarThemeData(
          barDecoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withAlpha(100),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
          ),
          iconDecoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          iconWidth: 40,
          iconHeight: 40,
        ),
        body: widget.body,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _DockButton(
                      icon: CupertinoIcons.photo_on_rectangle,
                      selected: currentIndex.value == 0,
                      onTap: () => currentIndex.value = 0,
                    ),
                  ),
                  Expanded(
                    child: _DockButton(
                      icon: CupertinoIcons.rectangle_stack,
                      selected: currentIndex.value == 1,
                      onTap: () => currentIndex.value = 1,
                    ),
                  ),
                  Expanded(
                    child: _DockButton(
                      icon: CupertinoIcons.settings,
                      selected: currentIndex.value == 2,
                      onTap: () => currentIndex.value = 2,
                    ),
                  ),
                  Expanded(
                    child: _DockButton(
                      icon: CupertinoIcons.search,
                      selected: currentIndex.value == 3,
                      onTap: () => currentIndex.value = 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        decoration: BoxDecoration(
          color: selected ? Colors.white.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Icon(icon, size: 24),
      ),
    );
  }
}