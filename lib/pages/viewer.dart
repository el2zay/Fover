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
import 'package:fover/src/utils/editor.dart';
import 'package:fover/src/utils/requests.dart';
import 'package:fover/src/widgets/adjust_date.dart';
import 'package:fover/src/widgets/adjust_location.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:fover/src/widgets/container.dart';
import 'package:fover/src/widgets/dialog.dart';
import 'package:fover/src/widgets/photo_map.dart';
import 'package:fover/src/widgets/pop_menu.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

bool focused = false;

class ViewerPage extends StatefulWidget {
  const ViewerPage({
    super.key,
    required this.mimetype,
    required this.encodedPaths,
    required this.index,
    this.trashMode = false,
    required this.onRefresh,
  });

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
  VideoPlayerController? _videoController;
  late final ExtendedPageController _pageController;
  bool showInfo = false;
  final _sheetController = DraggableScrollableController();
  late double _imageFocusScale = PhotoStore.isLandscape(widget.encodedPaths[currentIndex]) ? 1 : 0.73;
  bool _isDisposed = false;  
  bool showFullText = false;

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
    _isDisposed = true;
    _videoController?.dispose();
    _animation?.removeListener(animationListener);
    _animationController.dispose();
    _pageController.dispose();
    focused = false;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadVideo(int index) async {
    final oldController = _videoController;
    if (mounted) setState(() => _videoController = null);

    await oldController?.dispose();

    if (_isDisposed) return;

    final encodedPath = widget.encodedPaths[index];
    final photo = PhotoStore.get(encodedPath);

    final VideoPlayerController controller;

    if (photo?.localPath != null) {
      controller = VideoPlayerController.file(File(photo!.localPath!));
    } else if (detectBackend() == ServerBackend.copyparty) {
      controller = VideoPlayerController.networkUrl(
        Uri.parse("${CopypartyService.baseUrl}/photos/$encodedPath"),
        httpHeaders: {'Authorization': 'Basic ${CopypartyService.credentials}'},
      );
    } else {
      controller = VideoPlayerController.networkUrl(
        Uri.parse("https://${box.get('apiDomain')}:${box.get('httpsPort')}/api/v15/dl/$encodedPath"),
        httpHeaders: {"X-Fbx-App-Auth": client!.sessionToken!},
      );
    }

    try {
      await controller.initialize();
    } catch (_) {
      controller.dispose();
      return;
    }

    if (_isDisposed || !mounted) {
      controller.dispose();
      return;
    }

    setState(() => _videoController = controller);
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  itemCount: widget.encodedPaths.length,
                  scrollDirection: Axis.horizontal,
                  onPageChanged: (index) {
                    setState(() {
                      currentIndex = index;
                      _videoOffset = Offset.zero;
                      _videoScale = 1.0;
                      _imageFocusScale = PhotoStore.isLandscape(widget.encodedPaths[index]) ? 1.0 : 0.73;
                    });
                    _videoController?.pause();
                    _videoController?.seekTo(Duration.zero);
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
                                        _videoController != null && _videoController!.value.isInitialized
                                          ? Center(
                                            child: AspectRatio(
                                              aspectRatio: _videoController!.value.aspectRatio,
                                              child: VideoPlayer(_videoController!)
                                            ),
                                          )
                                          : const Center(
                                            child: CircularProgressIndicator(color: Colors.white38)
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

              if (widget.mimetype[currentIndex].startsWith('video'))
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 84,
                  child: _videoController != null && _videoController!.value.isInitialized
                      ? CupertinoVideoControls(controller: _videoController!)
                      : const SizedBox(),
                ),
               Positioned(
                bottom: 0, left: 0, right: 0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: focused ? const SizedBox.shrink() : _buildBottomToolbar(),
                ),
              ),

            if (showInfo)
              _buildInfoSheet(context),
          ]
        )
      ),
    );
  }

  Widget _buildImage(int index) {
    final photo = PhotoStore.get(widget.encodedPaths[index]);

    if (photo?.localPath != null && File(photo!.localPath!).existsSync()) {
      return ExtendedImage.file(
        key: ValueKey(photo.localPath),
        File(photo.localPath!),
        fit: BoxFit.contain,
        mode: ExtendedImageMode.gesture,
        enableSlideOutPage: true,
        onDoubleTap: _handleDoubleTap,
      );
    }

    if (detectBackend() == ServerBackend.copyparty) {
      final url = "${CopypartyService.baseUrl}/photos/${widget.encodedPaths[index]}";

      return ExtendedImage.network(
        key: ValueKey(url),
        url,
        fit: BoxFit.contain,
        mode: ExtendedImageMode.gesture,
        enableSlideOutPage: true,
        onDoubleTap: _handleDoubleTap,
        headers: {'Authorization': 'Basic ${CopypartyService.credentials}'},
        loadStateChanged: (state) {
          switch (state.extendedImageLoadState) {
            case LoadState.loading:
              return const Center(
                child: CircularProgressIndicator(color: Colors.white38),
              );
            case LoadState.failed:
              return const Center(
                child: Text("Error loading image"),
              );
            case LoadState.completed:
              return null;
          }
        },
      );
    }

    final url = "https://${box.get('apiDomain')}:${box.get('httpsPort')}/api/v15/dl/${widget.encodedPaths[index]}";

    return ExtendedImage.network(
      key: ValueKey(url),
      url,
      fit: BoxFit.contain,
      mode: ExtendedImageMode.gesture,
      enableSlideOutPage: true,
      onDoubleTap: _handleDoubleTap,
      headers: {"X-Fbx-App-Auth": client!.sessionToken!},
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return const Center(
              child: CircularProgressIndicator(color: Colors.white38),
            );
          case LoadState.failed:
            return const Center(
              child: Text("Error loading image"),
            );
          case LoadState.completed:
            return null;
        }
      },
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    return  AppBar(
      key: const ValueKey('toolbar'),
      centerTitle: true,
      
      backgroundColor: Colors.transparent,
      leading: Row(
        children: [
          SizedBox(width: 10),
          Flexible(
            child: Button.iconOnly(
              glassConfig: const CNButtonConfig(),
              padding: const EdgeInsets.all(8),
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              glassIcon: CNSymbol('chevron.left', size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MyContainer(
            child:Padding(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('d MMMM yyyy', 'en').format(PhotoStore.getDate(widget.encodedPaths[currentIndex])),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    DateFormat("HH:mm").format(PhotoStore.getDate(widget.encodedPaths[currentIndex])),
                    style: TextStyle(
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
          data: CupertinoThemeData(brightness: Theme.brightnessOf(context)),
          child: Transform.scale(
            scale: 1.2,
            child: PopMenu(
              showCopy: widget.mimetype[currentIndex].startsWith('image/'),
              isViewer: true,
              isDownloaded: DownloadService.isDownloaded(widget.encodedPaths[currentIndex]),
              isFavorite: PhotoStore.get(widget.encodedPaths[currentIndex])?.favorite == true,
              canRevert: PhotoStore.get(widget.encodedPaths[currentIndex])?.editedFrom != null,
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
                    final bytes = await fetchFullBytes(widget.encodedPaths[currentIndex]);
                    if (bytes == null) return;
                    await FlutterClipboard.copyImage(bytes);
                    break;
                  case PopMenuAction.revert:
                    final originalPath = PhotoStore.get(widget.encodedPaths[currentIndex])?.editedFrom;
                    if (originalPath == null) break;

                    await PhotoStore.revertEdit(widget.encodedPaths[currentIndex]);

                    setState(() {
                      widget.encodedPaths[currentIndex] = originalPath;
                    });
                    
                    widget.onRefresh?.call();
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
                      focused = true;
                    });
                    showCupertinoSheet(
                      // Impossible a drag
                      enableDrag: false,
                      // barrierColor: Colors.transparent,
                      // isScrollControlled: true,
                      // constraints: BoxConstraints(
                      //   minHeight: 0,
                      //   maxHeight: MediaQuery.of(context).size.height * 0.93,
                      // ),
                      context: context,
                      builder: (context) {
                        return AdjustDate(
                          encodedPath: widget.encodedPaths[currentIndex],
                          photo: PhotoStore.get(widget.encodedPaths[currentIndex])!,
                          initialDate: PhotoStore.getOriginalDate(widget.encodedPaths[currentIndex]),
                        );
                      },
                    ).then((_) {
                      setState(() {
                        focused = false;
                      });
                    });
                    break;
                  case PopMenuAction.adjustLocation:
                    setState(() {
                      focused = true;
                    });

                    showCupertinoSheet(
                      context: context, 
                      builder: (context) {
                        return AdjustLocation(
                          photo: PhotoStore.get(widget.encodedPaths[currentIndex])!
                        );
                      }
                  );
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
                    final bytes = await fetchFullBytes(widget.encodedPaths[currentIndex]);
                    if (!mounted || bytes == null) return;

                    await SharePlus.instance.share(
                      ShareParams(
                        previewThumbnail: XFile.fromData(bytes),
                        files: [
                          XFile.fromData(
                            bytes,
                            mimeType: widget.mimetype[currentIndex],
                            name: PhotoStore.get(widget.encodedPaths[currentIndex])?.name ?? "media"
                          )
                        ]
                      )
                    );
                  }
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
                              final totalRemaining = widget.encodedPaths.length - 1;

                              if (totalRemaining == 0) {
                                Navigator.pop(context);
                                return;
                              }

                              setState(() {
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
                    final totalRemaining = widget.encodedPaths.length - 1;

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
                              final totalRemaining = widget.encodedPaths.length - 1;

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
                focused = true;
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
            onPressed: () async {
              setState(()=> focused = true);
              final isVideo = widget.mimetype[currentIndex].startsWith('video');
              String? localVideoPath;

              if (isVideo) {
                final dir = await getTemporaryDirectory();
                final tmpFile = 
                  File('${dir.path}/edit_tmp_${DateTime.now().millisecondsSinceEpoch}.mp4');

                final bytes = await fetchFullBytes(widget.encodedPaths[currentIndex]);
                if (!mounted || bytes == null) return;
                await tmpFile.writeAsBytes(bytes);
                localVideoPath = tmpFile.path;
              }

              final bytes = isVideo ? null : await fetchFullBytes(widget.encodedPaths[currentIndex]);
              if (!mounted) return;
              setState(() => focused = false);
              if (!isVideo && bytes == null) return;

              final newPath = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PopScope(
                    canPop: false,
                    child: PhotoEditorPage(
                      bytes: bytes ?? Uint8List(0), 
                      encodedPath: widget.encodedPaths[currentIndex], 
                      localVideoPath: localVideoPath, 
                      isVideo: isVideo
                    )
                  )
                )
              );

              if (localVideoPath != null) {
                try {
                  File(localVideoPath).deleteSync();
                } catch (_) {

                }

                if (!mounted || newPath == null) return;
                widget.onRefresh?.call();
                if (!mounted) return;
                setState(() {
                  widget.encodedPaths[currentIndex] = newPath;
                });
              
              }
            },
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

  String cleanName(String filename) {
  final pattern = RegExp(r'-\d+\.\d+-[a-zA-Z0-9]+\.[a-zA-Z0-9]+$');
  return filename.replaceFirst(pattern, '');
  }

  DraggableScrollableSheet _buildInfoSheet(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final photo = PhotoStore.get(widget.encodedPaths[currentIndex])!;
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
            setState(() {
              showInfo = false;
              focused = false;
            });
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
                      color: primary.withAlpha(80),
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
                  hintStyle: TextStyle(color: primary.withAlpha(100), fontSize: 16, fontWeight: FontWeight.w500),
                  border: InputBorder.none,
                ),
                onSubmitted: (value) async {
                  await PhotoStore.update(path: widget.encodedPaths[currentIndex], description: value);
                },
                style: TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.w500),
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
                        focused = true;
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
                            initialDate: PhotoStore.getOriginalDate(widget.encodedPaths[currentIndex]),
                          );
                        },
                      ).then((_) {
                        setState(() {
                          focused = false;
                        });
                      });
                    },
                    child: Text("Adjust", style: TextStyle(fontSize: 16, color: CupertinoColors.activeBlue))
                  )
                ],
              ),
              Text(cleanName(photo.name), style: TextStyle(color: Colors.grey)),
              Container(
                margin: EdgeInsets.symmetric(vertical: 20),
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: primary.withAlpha(20),
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
                      style: TextStyle(fontSize: 13, color: primary.withAlpha(150))
                    ),
                    SizedBox(height: 10),
                    Divider(color: primary.withAlpha(80), height: 0),
                    Row(
                      children: [
                        infoBox(photo.iso != null ? "ISO ${photo.iso}" : "—"),
                        infoBox( photo.focalLength != null ? "${photo.focalLength} mm" : "—"),
                        infoBox(photo.exposureValue != null ? "${photo.exposureValue} ev" : "—"),
                        infoBox(photo.focus != null ? "ƒ${photo.focus}" : "—"),
                      ],
                    ),
                  ],
                ),
              ),
              // Text("A retirer : Coordonnées GPS de l'image si disponible : "),
              // Text("${photo.latitude}, ${photo.longitude}")
              photo.detectedText != null && photo.detectedText!.isNotEmpty 
              ? Container(
                  margin: EdgeInsets.symmetric(vertical: 15),
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(15)
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Detected Text", style: TextStyle(fontSize: 14, color: primary.withAlpha(130))),
                      SizedBox(height: 5),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            scrollPhysics: NeverScrollableScrollPhysics(),
                            selectionColor: Colors.blue.withAlpha(70),
                            photo.detectedText!,
                            maxLines: !showFullText ? 3 : null,
                            style: TextStyle(height: 1.5, color: primary.withAlpha(200)),
                          ),
                          if (!showFullText && photo.detectedText!.split('\n').length > 3)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  showFullText = true;
                                });
                              },
                              child: Text(
                                'Show more...',
                                style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500), 
                              ),
                            )
                        ],
                      ),
                    ],
                  ),
                ) 
                : SizedBox(),
              SizedBox(height: 10),
              if (photo.longitude != null && Platform.isIOS)
                ClipRRect(
                  borderRadius: BorderRadiusGeometry.all(Radius.circular(20)),
                  child: SizedBox(
                    height: 220,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        showModalBottomSheet(
                          isDismissible: false,
                          enableDrag: false,
                          isScrollControlled: true,
                          context: context, 
                          builder: (context) {
                            return PhotoMap(photo: photo, fullscreen: true);
                          }
                        );
                      },
                      child: AbsorbPointer(child:PhotoMap(photo: photo)),
                    ),
                  ),
                ),
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
          child: Text(
            value, 
            style: TextStyle(
              fontSize: 12, 
              color: Theme.of(context).primaryColor.withAlpha(200),
              fontWeight: FontWeight.w600
            )
          ),
        ),
      ),
    );
  }
}


class CupertinoVideoControls extends StatelessWidget {
  final VideoPlayerController controller;
  const CupertinoVideoControls({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 200),
      child: !focused
        ? SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 10),
              child: Transform.scale(
                scaleY: 1.15,
                child: MyContainer(
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final playing = value.isPlaying;
                      final position = value.position;
                      final duration = value.duration;
                      final double maxMs = duration.inMilliseconds.toDouble().clamp(0, double.infinity);
                      final posMs = position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();

                      return Row(
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.only(left: 15),
                            onPressed: () => playing ? controller.pause() : controller.play(),
                            child: Icon(
                              playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.7,
                            child: Transform.scale(
                              scaleY: 1.3,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  thumbShape: SliderComponentShape.noThumb,
                                  overlayShape: SliderComponentShape.noOverlay,
                                  padding: EdgeInsets.only(left: 15, right: 10),
                                ),
                                child: Slider(
                                  min: 0,
                                  max: maxMs == 0 ? 1 : maxMs,
                                  value: maxMs == 0 ? 0 : posMs,
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.grey.withAlpha(100),
                                  thumbColor: Colors.transparent,
                                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                                  onChanged: (v) {
                                    if (duration == Duration.zero) return;
                                    controller.seekTo(Duration(milliseconds: v.toInt()));
                                  },
                                ),
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(position),
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          )
        : SizedBox(),
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