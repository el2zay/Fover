// ignore_for_file: use_build_context_synchronously

import 'dart:developer';
import 'dart:io';

import 'package:clipboard/clipboard.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fover/main.dart';
import 'package:fover/pages/library.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/services/download.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:fover/src/widgets/adjust_date.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:fover/src/widgets/dialog.dart';
import 'package:fover/src/widgets/pop_menu.dart';
import 'package:intl/intl.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit/media_kit.dart';

bool focused = false;

class ViewerPage extends StatefulWidget {
  const ViewerPage({
    super.key,
    required this.images,
    required this.mimetype,
    required this.encodedPaths,
    required this.index,
    this.trashMode = false,
    required this.onRefresh,
  });

  final List<Uint8List?> images;
  final List<String> mimetype;
  final List<String> encodedPaths;
  final int index;
  final bool trashMode;
  final VoidCallback? onRefresh;

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
  Offset _videoOffset = Offset.zero;
  double _videoScale = 1.0;
  late final player = Player();
  late final controller = VideoController(player);
  late final ExtendedPageController _pageController;
  bool showInfo = false;
  final _sheetController = DraggableScrollableController();
  bool hideAppbar = false;
  late double _imageFocusScale = PhotoStore.isLandscape(widget.encodedPaths[currentIndex]) ? 1 : 0.73;


  @override
  void initState() {
    super.initState();
    currentIndex = widget.index;
    _pageController = ExtendedPageController(initialPage: currentIndex);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    animationListener = () {};

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.mimetype[currentIndex].startsWith('video/')) {
        _loadVideo(currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _animation?.removeListener(animationListener);
    _animationController.dispose();
    _pageController.dispose();
    player.dispose();
    focused = false;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _loadVideo(int index) {
    final encodedPath = widget.encodedPaths[index];
    final photo = PhotoStore.get(encodedPath);

    final Media source;

    if (photo?.localPath != null) {
      source = Media(photo!.localPath!);
    } else if (detectBackend() == ServerBackend.copyparty) {
      final url = "${CopypartyService.baseUrl}/photos/$encodedPath";
      source = Media(
        url,
        httpHeaders: {
           'Authorization': 'Basic ${CopypartyService.credentials}',
        }
      );
    } else {
      source = Media(
        "https://${box.get('apiDomain')}:${box.get('httpsPort')}/api/v15/dl/$encodedPath",
        httpHeaders: {
          "X-Fbx-App-Auth": client!.sessionToken!,
        },
      );
    }
    player.open(source, play: false);
  }

  void _toggleFocus() {
    setState(() {
      focused = !focused;
      if (!PhotoStore.isLandscape(widget.encodedPaths[currentIndex])) {
        _imageFocusScale = focused ? 1 : 0.73;
      }
      SystemChrome.setEnabledSystemUIMode(
        focused ? SystemUiMode.immersive : SystemUiMode.edgeToEdge,
      );
    });
  }

  void _handleDoubleTap(ExtendedImageGestureState state) {
    _toggleFocus();
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
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 0),
            child: focused ? const SizedBox.shrink() : _buildAppBar(),
          )
        ),
        body: Stack(
          children: [ 
            Center(
              child: AnimatedScale(
                scale: _imageFocusScale,
                curve: Curves.easeInOut,
                duration: const Duration(milliseconds: 200),
                child: ExtendedImageGesturePageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  scrollDirection: Axis.horizontal,
                  onPageChanged: (index) {
                    setState(() {
                      currentIndex = index;
                      _videoOffset = Offset.zero;
                      _videoScale = 1.0;
                      _imageFocusScale = PhotoStore.isLandscape(widget.encodedPaths[index]) ? 1.0 : 0.73;
                    });
                    player.stop();
                    if (widget.mimetype[index].startsWith("video/")) {
                      _loadVideo(index);
                    }
                  },
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: _toggleFocus,
                      child: widget.mimetype[index].startsWith("video/")
                        ? index == currentIndex
                          ? GestureDetector(
                                onTap: _toggleFocus,
                                onVerticalDragUpdate: (details) {
                                  setState(() {
                                    _videoOffset += Offset(0, details.delta.dy);
                                    final progress = (_videoOffset.dy.abs() / 300).clamp(0.0, 1.0);
                                    _videoScale = 1.0 - (progress * 0.3);
                                  });
                                },
                                onVerticalDragEnd: (details) {
                                  final velocity = details.primaryVelocity ?? 0;
                                  if (_videoOffset.dy.abs() > 100 || velocity.abs() > 500) {
                                    Navigator.pop(context);
                                  } else {
                                    setState(() {
                                      _videoOffset = Offset.zero;
                                      _videoScale = 1.0;
                                    });
                                  }
                                },
                                child: Transform.scale(
                                  scale: _videoScale,
                                  child: Transform.translate(
                                    offset: _videoOffset,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Video(
                                          controller: controller,
                                          controls: (state) => const SizedBox.shrink(),
                                        ),
                                        Positioned(
                                          left: 0, right: 0, bottom: 0,
                                          child: CupertinoVideoControls(controller: controller),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox()
                          : _buildImage(index)
                        );
                      },
                    ),
                  ),
                ),
               Positioned(
                bottom: 0, left: 0, right: 0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: focused ? const SizedBox.shrink() : _buildBottomToolbar(),
                ),
              ),

            if (showInfo)
              _buildInfoSheet(context, widget.images[currentIndex]),
          ]
        )
      ),
    );
  }

  Widget _buildImage(int index) {
    final photo = PhotoStore.get(widget.encodedPaths[index]);

    if (photo?.localPath != null && File(photo!.localPath!).existsSync()) {
      return ExtendedImage.file(
        File(photo.localPath!),
        fit: BoxFit.fitWidth,
        mode: ExtendedImageMode.gesture,
        enableSlideOutPage: true,
        onDoubleTap: _handleDoubleTap,
      );
    }

    if (detectBackend() == ServerBackend.copyparty) {
      final url = "${CopypartyService.baseUrl}/photos/${widget.encodedPaths[index]}";
      return LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final width = constraints.maxWidth;

          double displayedWidth = width;
          if ((photo?.width ?? 0) > 0 && (photo?.height ?? 0) > 0) {
            final ratio = photo!.width! / photo.height!;
            displayedWidth = (ratio * height).clamp(0.0, width);
          }

          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: SizedBox(
                width: displayedWidth,
                height: height,
                child: ExtendedImage.network(
                  url,
                  fit: BoxFit.fitWidth,
                  mode: ExtendedImageMode.gesture,
                  enableSlideOutPage: true,
                  onDoubleTap: _handleDoubleTap,
                  headers: {'Authorization': 'Basic ${CopypartyService.credentials}'},
                  loadStateChanged: (state) {
                    if (state.extendedImageLoadState == LoadState.loading) {
                      return Container(color: Colors.transparent);
                    }
                    return null;
                  },
                )
              )
            )
          );
        }
      );
    }

    return widget.images[index] != null
      ? ExtendedImage.memory(
          widget.images[index]!,
          fit: BoxFit.fitWidth,
          mode: ExtendedImageMode.gesture,
          enableSlideOutPage: true,
          onDoubleTap: _handleDoubleTap,
        )
      : Container(color: Colors.grey[900]);
  }

  PreferredSizeWidget? _buildAppBar() {
    return  AppBar(
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
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('d MMMM yyyy', 'en').format(PhotoStore.getDate(widget.encodedPaths[currentIndex])),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    DateFormat("HH:mm").format(PhotoStore.getDate(widget.encodedPaths[currentIndex])),
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
            child: PopMenu(
              showCopy: widget.mimetype[currentIndex].startsWith('image/'),
              isViewer: true,
              isDownloaded: DownloadService.isDownloaded(widget.encodedPaths[currentIndex]),
              isFavorite: PhotoStore.get(widget.encodedPaths[currentIndex])?.favorite == true,
              onSelected: (action) async {
                switch (action) {
                  case PopMenuAction.download:
                    final photo = PhotoStore.get(widget.encodedPaths[currentIndex]);
                      if (!DownloadService.isDownloaded(widget.encodedPaths[currentIndex])) {
                        final path = await DownloadService.download(
                          encodedPath: widget.encodedPaths[currentIndex],
                          filename: photo?.name ?? widget.encodedPaths[currentIndex],
                        );
                        if (!mounted) return;
                        setState(() {});
                        
                        log('Downloaded to: $path');
                      } else {
                        log("ici");
                        DownloadService.remove(widget.encodedPaths[currentIndex]);
                      }
                    break;
                  case PopMenuAction.copy:
                    final bytes = widget.images[currentIndex];
                    if (bytes == null) return;
                    await FlutterClipboard.copyImage(bytes);
                    break;
                  case PopMenuAction.share:
                    break;
                  case PopMenuAction.favorite:
                    final isFavorite = PhotoStore.get(widget.encodedPaths[currentIndex])?.favorite == true;
                    await PhotoStore.update(path: widget.encodedPaths[currentIndex], favorite: !isFavorite);
                    setState(() {});
                    break;
                  case PopMenuAction.duplicate:
                    await PhotoStore.duplicate(path: widget.encodedPaths[currentIndex]);
                    widget.onRefresh?.call();
                    break;
                  case PopMenuAction.hide:
                    await PhotoStore.update(path: widget.encodedPaths[currentIndex], hidden: true);
                    widget.onRefresh?.call();
                    break;
                  case PopMenuAction.addToAlbum:
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
                      builder: (context) {
                        return AddToAlbumSheet(
                          photoPath: [widget.encodedPaths[currentIndex]],
                        );
                      }
                    );
                    break;
                  case PopMenuAction.adjustDate:
                    setState(() {
                      hideAppbar = true;
                    });
                    showModalBottomSheet(
                      barrierColor: Colors.transparent,
                      isScrollControlled: true,
                      constraints: BoxConstraints(
                        minHeight: 0,
                        maxHeight: MediaQuery.of(context).size.height * 0.92,
                      ),
                      context: context,
                      
                      builder: (context) {
                        return AdjustDate(
                          encodedPath: widget.encodedPaths[currentIndex],
                          photo: PhotoStore.get(widget.encodedPaths[currentIndex])!,
                          initialDate: PhotoStore.getDate(widget.encodedPaths[currentIndex]),
                        );
                      },
                    ).then((_) {
                      setState(() {
                        hideAppbar = false;
                      });
                    });
                    break;
                  case PopMenuAction.adjustLocation:
                    break;
                }
              },
            )
          ),
        ),
      ],
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
              if (!widget.trashMode)...[
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
                  onPressed: () {
                    showGeneralDialog(
                      barrierDismissible: false,
                      context: context,
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return MyDialog(
                          content: "This photo will be deleted from all your devices. It will be kept in \"Deleted recently\" for 30 days.",
                          principalButton: TextButton(
                            child: Text("Delete", style: TextStyle(fontSize: 16, color: CupertinoColors.destructiveRed)),
                            onPressed: () async {
                              await PhotoStore.softDelete(widget.encodedPaths[currentIndex]);
                              Navigator.pop(context);
                              final totalRemaining = widget.images.length - 1;

                              if (totalRemaining == 0) {
                                Navigator.pop(context);
                                return;
                              }

                              setState(() {
                                widget.images.removeAt(currentIndex);
                                widget.encodedPaths.removeAt(currentIndex);
                                widget.mimetype.removeAt(currentIndex);
                              });

                              if (currentIndex >= totalRemaining) {
                                _pageController.animateToPage(
                                  totalRemaining - 1, 
                                  duration: const Duration(milliseconds: 300), 
                                  curve: Curves.easeInOut
                                );
                                setState(() => currentIndex = totalRemaining - 1);
                              }
                              
                            }
                          ),
                        );
                      }
                    );
                  },
                ),
              ] else ...[
                Button(
                  label: "Recover",
                  onPressed: () async {
                    await PhotoStore.restore(widget.encodedPaths[currentIndex]);
                    final totalRemaining = widget.images.length - 1;

                    if (totalRemaining == 0) {
                      Navigator.pop(context);
                      return;
                    }

                    if (currentIndex >= totalRemaining) {
                      _pageController.animateToPage(
                        totalRemaining - 1, 
                        duration: const Duration(milliseconds: 300), 
                        curve: Curves.easeInOut
                      );
                      setState(() => currentIndex = totalRemaining - 1);
                    }
                  }
                ),
                Button(
                  label: "Delete",
                  onPressed: () {
                    showGeneralDialog(
                      barrierDismissible: false,
                      context: context,
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return MyDialog(
                          content: "This action cannot be undone. The image will also be deleted from your server.",
                          principalButton: TextButton(
                            child: Text("Delete", style: TextStyle(fontSize: 16, color: CupertinoColors.destructiveRed)),
                            onPressed: () async {
                              await PhotoStore.hardDelete(widget.encodedPaths[currentIndex]);
                              Navigator.pop(context);
                              final totalRemaining = widget.images.length - 1;

                              if (totalRemaining == 0) {
                                Navigator.pop(context);
                                return;
                              }

                              if (currentIndex >= totalRemaining) {
                                _pageController.animateToPage(
                                  totalRemaining - 1, 
                                  duration: const Duration(milliseconds: 300), 
                                  curve: Curves.easeInOut
                                );
                                setState(() => currentIndex = totalRemaining - 1);
                              }
                            }
                          ),
                        );
                      }
                    );
                  }
                )
              ],
            ]
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMediaControls() {
    bool isFavorite = PhotoStore.get(widget.encodedPaths[currentIndex])?.favorite == true;
    if (is26OrNewer) {
      return CNGlassButtonGroup(
        axis: Axis.horizontal,
        spacing: 8.0,
        spacingForGlass: 40.0,
        buttons: [
          CNButtonData.icon(
            icon: CNSymbol(isFavorite ? 'heart.fill' :  'heart', size: 22),
            onPressed: () async {
              await PhotoStore.update(path: widget.encodedPaths[currentIndex], favorite: !isFavorite);
              setState(() {
                isFavorite = !isFavorite;
              });
            },
            config: CNButtonDataConfig(
              style: CNButtonStyle.prominentGlass,
              glassEffectUnionId: 'media-controls',
              glassEffectId: 'heart-button',
              glassEffectInteractive: true,
            ),
          ),
          CNButtonData.icon(
            icon: CNSymbol('info.circle', size: 22),
            onPressed: () {
              setState(() {
                showInfo = !showInfo;
              });
            },
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
            icon: Icon(isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart),
            glassIcon: CNSymbol(isFavorite ? 'heart.fill' : 'heart', size: 18),
            backgroundColor: Colors.transparent,
            onPressed: () async {
              await PhotoStore.update(path: widget.encodedPaths[currentIndex], favorite: !isFavorite);
              setState(() {
                isFavorite = !isFavorite;
              });
            },
          ),
          Button.iconOnly(
            icon: const Icon(CupertinoIcons.info_circle),
            glassIcon: CNSymbol('info.circle', size: 18),
            backgroundColor: Colors.transparent,
            onPressed: () {
              setState(() {
                showInfo = !showInfo;
              });
            },
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

  DraggableScrollableSheet _buildInfoSheet(context, image) {
    final photo = PhotoStore.get(widget.encodedPaths[currentIndex])! ;
    final descriptionController = TextEditingController(text: photo.description);
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0,
      maxChildSize: 0.9,
      shouldCloseOnMinExtent: true,
      controller: _sheetController,
      builder: (context, scrollController) {
        _sheetController.addListener(() {
          if (_sheetController.size == 0) {
            setState(() => showInfo = false);
          }
        });
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              TextField(
                keyboardType: TextInputType.text,
                controller: descriptionController,
                decoration: InputDecoration(
                  hintText: "Add a description",
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w500),
                  border: InputBorder.none,
                ),
                onSubmitted: (value) async {
                  await PhotoStore.update(path: widget.encodedPaths[currentIndex], description: value);
                },
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('d MMMM yyyy — HH:mm', 'en').format(PhotoStore.getDate(widget.encodedPaths[currentIndex]).toLocal()),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        hideAppbar = true;
                      });
                      showModalBottomSheet(
                        barrierColor: Colors.transparent,
                        isScrollControlled: true,
                        constraints: BoxConstraints(
                          minHeight: 0,
                          maxHeight: MediaQuery.of(context).size.height * 0.92,
                        ),
                        context: context,
                        
                        builder: (context) {
                          return AdjustDate(
                            encodedPath: widget.encodedPaths[currentIndex],
                            photo: photo,
                            initialDate: PhotoStore.getDate(widget.encodedPaths[currentIndex]),
                          );
                        },
                      ).then((_) {
                        setState(() {
                          hideAppbar = false;
                        });
                      });
                    },
                    child: Text("Adjust", style: TextStyle(fontSize: 16, color: Colors.blue))
                  )
                ],
              ),
              Text(photo.name, style: TextStyle(color: Colors.grey)),
              Container(
                margin: EdgeInsets.symmetric(vertical: 20),
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(10)
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(photo.cameraModel ?? "Unknown", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    Text(
                      // Si c'est une vidéo
                      widget.mimetype[currentIndex].startsWith('video/')
                        ? formatSize(photo.size)
                        : "${getMP(photo)} MP • ${photo.width} x ${photo.height} • ${formatSize(photo.size)}",
                      style: TextStyle(fontSize: 13, color: Colors.white70)
                    ),
                    SizedBox(height: 10),
                    Divider(color: Colors.white24, height: 0),
                    Row(
                      children: [
                        infoBox(photo.iso != null ? "ISO ${photo.iso}" : "—"),
                        infoBox( photo.focalLength != null ? "${photo.focalLength} mm" : "—"),
                        infoBox(photo.exposureValue != null ? "${photo.exposureValue} ev" : "—"),
                        infoBox(photo.focus != null ? "ƒ${photo.focus}" : "—"),
                      ],
                    )
                  ],
                ),
              )
            ]
          )
        );
      }
    );
  }
  
  Widget infoBox(String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
        ),
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
