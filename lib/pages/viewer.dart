import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fover/main.dart';
import 'package:fover/src/widgets/button.dart';

class ViewerPage extends StatefulWidget {
  const ViewerPage({
    super.key,
    required this.images,
    required this.index,
    required this.length,
  });

  final List<Uint8List> images;
  final int index;
  final int length;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage>
    with SingleTickerProviderStateMixin {
  bool focused = false;
  bool _showSwiper = true;
  late int currentIndex;
  late AnimationController _animationController;
  Animation<double>? _animation;
  late VoidCallback animationListener;
  final List<double> doubleTapScales = <double>[1.0, 3.0];
  final GlobalKey<ExtendedImageSlidePageState> _slideKey =
      GlobalKey<ExtendedImageSlidePageState>();

  @override
  void initState() {
    super.initState();
    currentIndex = widget.index;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    animationListener = () {};
  }

  @override
  void dispose() {
    _animation?.removeListener(animationListener);
    _animationController.dispose();
    super.dispose();
  }

  void _toggleFocus() {
    setState(() {
      focused = !focused;
      SystemChrome.setEnabledSystemUIMode(
        focused ? SystemUiMode.immersive : SystemUiMode.edgeToEdge,
      );
    });
  }

  void _handleDoubleTap(ExtendedImageGestureState state) {
    final pointerDownPosition = state.pointerDownPosition;
    final double begin = state.gestureDetails?.totalScale ?? 1.0;
    final double end =
        begin == doubleTapScales[0] ? doubleTapScales[1] : doubleTapScales[0];

    _animation?.removeListener(animationListener);
    _animationController
      ..stop()
      ..reset();

    animationListener = () {
      state.handleDoubleTap(
        scale: _animation?.value ?? 1.0,
        doubleTapPosition: pointerDownPosition,
      );
    };

    _animation = _animationController.drive(
      Tween<double>(begin: begin, end: end),
    );
    _animation?.addListener(animationListener);
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return ExtendedImageSlidePage(
      key: _slideKey,
      slideAxis: SlideAxis.both,
      slideType: SlideType.onlyImage,
      onSlidingPage: (state) {
        final showSwiper = !state.isSliding;
        if (showSwiper != _showSwiper) {
          setState(() => _showSwiper = showSwiper);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: focused ? _buildHiddenAppBar() : _buildAppBar(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: ExtendedImageGesturePageView.builder(
                  itemCount: widget.length,
                  scrollDirection: Axis.horizontal,
                  controller: ExtendedPageController(initialPage: currentIndex),
                  onPageChanged: (index) {
                    setState(() => currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: _toggleFocus,
                      child: ExtendedImage.memory(
                        widget.images[index],
                        fit: BoxFit.contain,
                        mode: ExtendedImageMode.gesture,
                        enableSlideOutPage: true,
                        onDoubleTap: _handleDoubleTap,
                        heroBuilderForSlidingPage: (Widget result) {
                          return Hero(
                            tag: 'image_$index',
                            child: result,
                            flightShuttleBuilder:
                                (_, __, ___, ____, _____) => result,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: focused ? _buildHiddenToolbar() : _buildBottomToolbar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHiddenAppBar() {
    return AppBar(
      key: const ValueKey('hidden'),
      leading: const SizedBox(),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      key: const ValueKey('toolbar'),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      leading: Row(
        children: [
          Button.iconOnly(
            glassConfig: const CNButtonConfig(),
            padding: const EdgeInsets.all(8),
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            glassIcon: CNSymbol('chevron.left', size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LiquidGlassContainer(
            config: LiquidGlassConfig(
              effect: CNGlassEffect.regular,
              shape: CNGlassEffectShape.rect,
              cornerRadius: 20,
              interactive: true,
              tint: Colors.white.withAlpha(4),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "8 August 2012",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "18:32",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.only(right: 15),
      actions: [
        CupertinoTheme(
          data: const CupertinoThemeData(brightness: Brightness.dark),
          child: Transform.scale(
            scale: 1.2,
            child: CNPopupMenuButton.icon(
              size: 40,
              buttonIcon: CNSymbol('ellipsis', size: 15),
              items: [
                CNPopupMenuItem(
                  label: 'Copy',
                  icon: CNSymbol('doc.on.doc', size: 20),
                ),
                CNPopupMenuItem(
                  label: 'Duplicate',
                  icon: CNSymbol('plus.square.on.square', size: 20),
                ),
                CNPopupMenuItem(
                  label: 'Hide',
                  icon: CNSymbol('eye.slash', size: 20),
                ),
                CNPopupMenuDivider(),
                CNPopupMenuItem(
                  label: 'Add to Album',
                  icon: CNSymbol('plus.rectangle.on.rectangle', size: 20),
                ),
              ],
              onSelected: (item) {},
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHiddenToolbar() {
    return const SizedBox(
      key: ValueKey('hidden'),
      height: 64, // TODO: vérifier que c'est responsive
    );
  }

  Widget _buildBottomToolbar() {
    return Column(
      key: const ValueKey('toolbar'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 35.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Button.iconOnly(
                icon: const Icon(CupertinoIcons.share),
                glassIcon: CNSymbol('square.and.arrow.up', size: 18),
                onPressed: () async {
                  // final params = ShareParams(files: []);
                  // await SharePlus.instance.share(params);
                },
              ),
              _buildMediaControls(),
              Button.iconOnly(
                icon: const Icon(CupertinoIcons.trash),
                glassIcon: CNSymbol('trash', size: 18),
                onPressed: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMediaControls() {
    if (is26OrNewer) {
      return CNGlassButtonGroup(
        axis: Axis.horizontal,
        spacing: 8.0,
        spacingForGlass: 40.0,
        buttons: [
          CNButtonData.icon(
            icon: const CNSymbol('heart', size: 22),
            onPressed: () {},
            config: CNButtonDataConfig(
              style: CNButtonStyle.prominentGlass,
              glassEffectUnionId: 'media-controls',
              glassEffectId: 'heart-button',
              glassEffectInteractive: true,
            ),
          ),
          CNButtonData.icon(
            icon: const CNSymbol('info.circle', size: 22),
            onPressed: () {},
            config: const CNButtonDataConfig(
              style: CNButtonStyle.prominentGlass,
              glassEffectUnionId: 'media-controls',
              glassEffectId: '',
              glassEffectInteractive: true,
            ),
          ),
          CNButtonData.icon(
            icon: const CNSymbol('slider.horizontal.3', size: 22),
            onPressed: () {},
            config: const CNButtonDataConfig(
              style: CNButtonStyle.prominentGlass,
              glassEffectUnionId: 'media-controls',
              glassEffectId: 'stop-button',
              glassEffectInteractive: true,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Button.iconOnly(
            icon: const Icon(CupertinoIcons.heart),
            glassIcon: CNSymbol('heart', size: 18),
            backgroundColor: Colors.transparent,
            onPressed: () {},
          ),
          Button.iconOnly(
            icon: const Icon(CupertinoIcons.info_circle),
            glassIcon: CNSymbol('info.circle', size: 18),
            backgroundColor: Colors.transparent,
            onPressed: () {},
          ),
          Button.iconOnly(
            icon: const Icon(CupertinoIcons.slider_horizontal_3),
            glassIcon: CNSymbol('slider.horizontal.3', size: 18),
            backgroundColor: Colors.transparent,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
