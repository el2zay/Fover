import 'dart:ui';
import 'package:flutter/material.dart';

class BlurredAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool isAlbum;
  final VoidCallback? onBack;
  final ScrollController? scrollController;

  const BlurredAppBar({
    super.key, 
    required this.title, 
    this.subtitle, 
    required this.actions, 
    this.isAlbum = false,
    this.onBack,
    this.scrollController
  });

  @override
  State<BlurredAppBar> createState() => _BlurredAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(
    subtitle != null ? kToolbarHeight + 10 : kToolbarHeight - 10
  );
}

class _BlurredAppBarState extends State<BlurredAppBar> {
  bool isAtTop = false;

  @override
  void didUpdateWidget(covariant BlurredAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(onScroll);
      widget.scrollController?.addListener(onScroll);
    }
  }

  void onScroll() {
    final atTop = widget.scrollController!.offset < 10;
    if (atTop != isAtTop) setState(() => isAtTop = atTop);
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = (isAtTop && !isDark) ? Colors.black : Colors.white;

    return OrientationBuilder(builder: (context, orientation) {
      return AppBar(
        clipBehavior: Clip.none,
        elevation: 0,
        centerTitle: false,
        flexibleSpace: orientation == Orientation.landscape ? ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark ? [
                    Colors.black.withAlpha(150),
                    Colors.black.withAlpha(150),
                    Colors.black.withAlpha(25),
                  ] : [
                    Colors.white.withAlpha(25),
                    Colors.white.withAlpha(25),
                  ]
                ),
              ),
            ),
          ),
        ) : SizedBox(),
        titleSpacing: 10,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (orientation == Orientation.landscape) SizedBox(height: 10),
              AnimatedDefaultTextStyle(
                duration: Duration(milliseconds: 200),
                style: TextStyle(
                  color: widget.scrollController != null ? textColor : Theme.of(context).primaryColor,
                  fontSize: 36,
                  fontWeight: FontWeight.bold
                ),
                child: Text(
                  widget.title, 
                  style: TextStyle(
                    color: widget.isAlbum ? Colors.black : null,
                    fontSize: widget.isAlbum ? 20 : 36,
                    fontWeight: FontWeight.bold
                  )
                ),
              ),
            if (widget.subtitle != null)
              AnimatedDefaultTextStyle(
                duration: Duration(milliseconds: 200),
                style: TextStyle(
                  color: widget.isAlbum 
                    ? Theme.of(context).primaryColor
                    : textColor.withAlpha(200),
                  fontSize: 18,
                  fontWeight: FontWeight.bold
                ),
                child: Text(widget.subtitle!), 
              )
          ],
        ),
        backgroundColor: Colors.transparent,
        actions: widget.actions,
      );  
    });
  }
}
