import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';


class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, required this.image});

  final Image image;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  bool focused = false;

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
                  elevation: 0,
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  leading: Row(
                    children: [
                      const SizedBox(width: 10),
                      Transform.scale(
                          scale: 1.2,
                          child: CNButton.icon(
                            config: const CNButtonConfig(),
                            icon: CNSymbol('chevron.left', size: 18),
                            onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
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
                child: widget.image,
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
                              CNButton.icon(
                                icon: CNSymbol(
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
                              CNGlassButtonGroup(
                                axis: Axis.horizontal,
                                spacing: 8.0,
                                spacingForGlass: 40.0,
                                buttons: [
                                  CNButtonData.icon(
                                    icon: const CNSymbol('heart', size: 22),
                                    onPressed: () {},
                                    config: const CNButtonDataConfig(
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
                              ),
                              CNButton.icon(
                                icon: CNSymbol('trash', size: 18),
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
                      height: 95,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
