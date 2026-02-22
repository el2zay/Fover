import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fover/main.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:share_plus/share_plus.dart';


class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, required this.images, required this.index, required this.length});

  final List<Uint8List> images;
  final int index;
  final int length;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> with SingleTickerProviderStateMixin {
  bool focused = false;
  late int currentIndex;
  late AnimationController _animationController;
  Animation<double>? _animation;
  late VoidCallback animationListener;
  final List<double> doubleTapScales = <double>[1.0, 3.0];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: focused
              ? AppBar(
                  key: const ValueKey('hidden'),
                  leading: const SizedBox(),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                )
              : AppBar(
                  key: const ValueKey('toolbar'),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  leading: Row(
                    children: [
                      Button.iconOnly(
                        glassConfig: const CNButtonConfig(),
                        padding: const EdgeInsets.all(8),
                        icon: Icon(Icons.arrow_back_ios, size: 18),
                        glassIcon: CNSymbol('chevron.left', size: 18),
                        onPressed: () {
                          Navigator.pop(context);
                        },
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 6,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
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
                      data: const CupertinoThemeData(
                        brightness: Brightness.dark,
                      ),
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
                              label: "Duplicate",
                              icon: CNSymbol(
                                'plus.square.on.square',
                                size: 20,
                              ),
                            ),
                            CNPopupMenuItem(
                              label: "Hide",
                              icon: CNSymbol('eye.slash', size: 20),
                            ),
                            CNPopupMenuDivider(),
                            CNPopupMenuItem(
                              label: "Add to Album",
                              icon: CNSymbol(
                                'plus.rectangle.on.rectangle',
                                size: 20,
                              ),
                            ),
                          ],
                          onSelected: (item) {},
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            focused = !focused;

            if (focused) {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
            } else {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            }
          });

        },
        child: Column(
          children: [
            Expanded(
              flex: 1,
              child: Center(
                child: ExtendedImageGesturePageView.builder(
                  itemBuilder: (BuildContext context, int index) {
                    Widget image = ExtendedImage.memory(
                      onDoubleTap: (ExtendedImageGestureState state) {
                        var pointerDownPosition = state.pointerDownPosition;
                        double begin = state.gestureDetails?.totalScale ?? 1.0;
                        double end;

                        //remove old
                        _animation?.removeListener(animationListener);

                        //stop pre
                        _animationController.stop();

                        //reset to use
                        _animationController.reset();

                        if (begin == doubleTapScales[0]) {
                          end = doubleTapScales[1];
                        } else {
                          end = doubleTapScales[0];
                        }

                        animationListener = () {
                          state.handleDoubleTap(
                              scale: _animation?.value ?? 1.0,
                              doubleTapPosition: pointerDownPosition);
                        };
                        _animation = _animationController
                            .drive(Tween<double>(begin: begin, end: end));

                        _animation?.addListener(animationListener);

                        _animationController.forward();
                      },
                      widget.images[index],
                      fit: BoxFit.contain,
                      mode: ExtendedImageMode.gesture,
                    );
                      return image;
                    },
                    itemCount: widget.length,
                    onPageChanged: (int index) {
                      setState(() {
                      currentIndex = index;
                      });
                    },
                    controller: ExtendedPageController(
                      initialPage: currentIndex,
                    ),
                  scrollDirection: Axis.horizontal,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: !focused
                  ? Column(
                      key: const ValueKey('toolbar'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 35.0,
                            vertical: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Button.iconOnly(
                                icon: Icon(CupertinoIcons.share),
                                glassIcon: CNSymbol(
                                  'square.and.arrow.up',
                                  size: 18,
                                ),
                                onPressed: () async {
                                //   final params = ShareParams(
                                //     files: [],
                                // );
                                  // await SharePlus.instance.share(params);
                                },
                              ),
                              is26OrNewer ?
                                CNGlassButtonGroup(
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
                                ) : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Row(
                                    children: [
                                      Button.iconOnly(
                                        icon: Icon(CupertinoIcons.heart),
                                        glassIcon: CNSymbol('heart', size: 18),
                                        backgroundColor: Colors.transparent,
                                        onPressed: () {},
                                      ),
                                      Button.iconOnly(
                                        icon: Icon(CupertinoIcons.info_circle),
                                        glassIcon: CNSymbol('info.circle', size: 18),
                                        backgroundColor: Colors.transparent,
                                        onPressed: () {},
                                      ),
                                      Button.iconOnly(
                                        icon: Icon(CupertinoIcons.slider_horizontal_3),
                                        glassIcon: CNSymbol('slider.horizontal.3', size: 18),
                                        backgroundColor: Colors.transparent,
                                        onPressed: () {},
                                      ),
                                    ],
                                  ),
                                ),
                              Button.iconOnly(
                                icon: Icon(CupertinoIcons.trash),
                                glassIcon: CNSymbol('trash', size: 18),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    )
                  : const SizedBox(
                      key: ValueKey('hidden'),
                      // TODO vérfier que c'est responsive
                      height: 64,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
