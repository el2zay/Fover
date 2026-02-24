import 'dart:developer';

import 'package:camerawesome/pigeon.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fover/main.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:get_storage/get_storage.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit/media_kit.dart';

bool focused = false;

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

class _ViewerPageState extends State<ViewerPage> with SingleTickerProviderStateMixin {
  bool _showSwiper = true;
  late int currentIndex;
  late AnimationController _animationController;
  Animation<double>? _animation;
  late VoidCallback animationListener;
  final List<double> doubleTapScales = <double>[1.0, 3.0];
  final GlobalKey<ExtendedImageSlidePageState> _slideKey = GlobalKey<ExtendedImageSlidePageState>();

  late final player = Player();
  late final controller = VideoController(player);
  final box = GetStorage();

  @override
  void initState() {
    String encodedPath = "L0ZyZWVib3gvVGVzdC84RTZEMjI5Qi1FNjcyLTRERkUtOTg5QS1BRjRCNUExNDc1NTkubW92";
    super.initState();
    currentIndex = widget.index;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    animationListener = () {};
    player.open(
      Media(
        "https://${box.read('apiDomain')}:${box.read('httpsPort')}/api/v15/dl/$encodedPath",
        httpHeaders: {
          "X-Fbx-App-Auth": client!.sessionToken!,
        },
      ),
      play: false
    );
  }

  @override
  void dispose() {
    _animation?.removeListener(animationListener);
    _animationController.dispose();
    player.dispose();
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Video(
                            controller: controller,
                            controls: (state) => const SizedBox.shrink(),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: CupertinoVideoControls(
                              controller: controller,
                            ),
                          ),
                        ],
                      ),
                      // ExtendedImage.memory(
                      //   widget.images[index],
                      //   fit: BoxFit.contain,
                      //   mode: ExtendedImageMode.gesture,
                      //   enableSlideOutPage: true,
                      //   onDoubleTap: _handleDoubleTap,
                      //   heroBuilderForSlidingPage: (Widget result) {
                      //     return Hero(
                      //       tag: 'image_$index',
                      //       child: result,
                      //       flightShuttleBuilder:
                      //           (_, __, ___, ____, _____) => result,
                      //     );
                      //   },
                      // ),
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

class CupertinoVideoControls extends StatelessWidget {
  final VideoController controller;

  const CupertinoVideoControls({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final player = controller.player;

    return AnimatedSwitcher(
      duration: Duration(milliseconds: 200),
      child: !focused ?
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsetsGeometry.symmetric(horizontal: 10),
            child: Transform.scale(
              scaleY: 1.15,
                child: LiquidGlassContainer(
                config: LiquidGlassConfig(
                  shape: CNGlassEffectShape.capsule,
                  tint: Colors.black.withAlpha(70),
                ),
                child: Row(
                  children: [
                    StreamBuilder<bool>(
                      stream: player.stream.playing,
                      initialData: player.state.playing,
                      builder: (context, snapshot) {
                        final playing = snapshot.data ?? false;
                        return CupertinoButton(
                          padding: EdgeInsets.only(left: 15),
                          onPressed: () => playing ? player.pause() : player.play(),
                          child: Icon(
                            playing
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            color: Colors.white,
                            size: 26,
                          ),
                        );
                      },
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: StreamBuilder<Duration>(
                        stream: player.stream.position,
                        initialData: player.state.position,
                        builder: (context, posSnap) {
                          final position = posSnap.data ?? Duration.zero;
                          return StreamBuilder<Duration>(
                            stream: player.stream.duration,
                            initialData: player.state.duration,
                            builder: (context, durSnap) {
                              final duration = durSnap.data ?? Duration.zero;
                              final double max = duration.inMilliseconds
                                  .toDouble()
                                  .clamp(0, double.infinity);
                              final value = position.inMilliseconds
                                  .clamp(0, duration.inMilliseconds)
                                  .toDouble();

                              return Transform.scale(
                                scaleY: 1.3,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    thumbShape: SliderComponentShape.noThumb,
                                    overlayShape: SliderComponentShape.noOverlay,
                                    padding: EdgeInsets.only(left: 15, right: 10)
                                  ),
                                  child: Slider(
                                    min: 0,
                                    max: max == 0 ? 1 : max,
                                    value: max == 0 ? 0 : value,
                                    activeColor: Colors.white,
                                    inactiveColor: Colors.grey.withAlpha(100),
                                    thumbColor: Colors.transparent,
                                    overlayColor:
                                        WidgetStateProperty.all(Colors.transparent),
                                    onChanged: (v) {
                                      if (duration == Duration.zero) return;
                                      player.seek(Duration(milliseconds: v.toInt()));
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    StreamBuilder<Duration>(
                      stream: player.stream.position,
                      initialData: player.state.position,
                      builder: (context, posSnap) {
                        final dur = posSnap.data ?? Duration.zero;
                        return Text(
                          _formatDuration(dur), 
                          style: TextStyle(
                          color: Colors.white, 
                          fontSize: 13,
                          fontWeight: FontWeight.w600
                        ));
                      }
                    )
                  ],
                ),
              ),
            ),
          ),
        ) 
      : SizedBox()
    );
  }

  String _formatDuration(Duration d) {
    final minutes =
        d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
