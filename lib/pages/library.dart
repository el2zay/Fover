import 'dart:developer';

import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fover/main.dart';
import 'package:fover/pages/settings.dart';
import 'package:fover/pages/viewer.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/requests.dart';
import 'package:fover/src/widgets/blurred_app_bar.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:fover/src/widgets/context_menu.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fover/src/widgets/dialog.dart';

final ValueNotifier<int> countSelected = ValueNotifier<int>(0);

class LibraryPage extends StatefulWidget {
  final bool onlySelect;
  final bool trashMode;

  const LibraryPage({super.key, this.onlySelect = false, this.trashMode = false});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _GalleryData {
  final List<Uint8List?> images;
  final List<Uint8List?> thumbs;
  final List<String> mimetypes;
  final List<String> encodedPaths;

  const _GalleryData({required this.images, required this.thumbs, required this.mimetypes, required this.encodedPaths});
}

class _MediaEntry {
  final Uint8List? bytes;
  final String mimetype;
  final String encodedPath;

  const _MediaEntry({required this.bytes, required this.mimetype, required this.encodedPath});
}

class _LibraryPageState extends State<LibraryPage> {
  bool showButtons = false;
  _GalleryData? _data;  bool selectedMode = false;
  bool _loading = true;
  List<int> selectedImages = [];
  int elements = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Generated with AI
  Future<void> _load() async {
    final images = await _loadImages();
    final thumbs = await _compressImages(images.map((e) => e.bytes).toList());

    setState(() {
      _data = _GalleryData(
        images: images.map((e) => e.bytes).toList(),
        thumbs: thumbs,
        mimetypes: images.map((e) => e.mimetype).toList(),
        encodedPaths: images.map((e) => e.encodedPath).toList(),
      );
      _loading = false;
    });
  }


  void _removeLocally(List<int> indexes) {
    setState(() {
      final sorted = indexes.toList()..sort((a, b) => b.compareTo(a));
      for (final i in sorted) {
        _data!.images.removeAt(i);
        _data!.thumbs.removeAt(i);
        _data!.mimetypes.removeAt(i);
        _data!.encodedPaths.removeAt(i);
      }
      selectedImages.clear();
    });
  }
  //


  Future<List<_MediaEntry>> _loadImages() async {
    final entries = await fetchPhotosDir();

    final results = await Future.wait(
      entries.map((entry) => fetchImageBytes(entry['path'], entry['mimetype'])),
    );

    // return results.asMap().entries
    //   .where((e) => e.value != null)
    //   .where((e) {
    //     final stored = PhotoStore.get(entries[e.key]['path'] as String);
    //     return widget.trashMode 
    //       ? stored?.deletedAt != null
    //       : stored?.deletedAt == null;
    //   }).map((e) => _MediaEntry(
    //     bytes: e.value as Uint8List,
    //     mimetype: entries[e.key]['mimetype'] as String,
    //     encodedPath: entries[e.key]['path'] as String,
    // )).toList();

  return results.asMap().entries
    .where((e) {
      final stored = PhotoStore.get(entries[e.key]['path'] as String);
      return widget.trashMode 
        ? stored?.deletedAt != null
        : stored?.deletedAt == null;
    }).map((e) => _MediaEntry(
      bytes: e.value, // ← peut être null
      mimetype: entries[e.key]['mimetype'] as String,
      encodedPath: entries[e.key]['path'] as String,
    )).toList();
  }


  Future<List<Uint8List?>> _compressImages(List<Uint8List?> list) async {
    final results = await Future.wait(list.map((origBytes) async {
      if (origBytes == null) return null;

      final origSize = origBytes.lengthInBytes / 1024;

      final compressed = await FlutterImageCompress.compressWithList(
        origBytes,
        minWidth: 300,
        minHeight: 300,
        quality: 10,
        format: CompressFormat.webp,
      );

      final compSize = compressed.lengthInBytes / 1024;
      log("Taille compressée ${compSize.toStringAsFixed(1)} KB - Réduit de ${((1 - compSize/origSize)*10).toStringAsFixed(1)}%");
      return compressed;
    }));

    return results;
  }


  Future<void> _refresh() async {
    final images = await _loadImages();
    final thumbs = await _compressImages(images.map((e) => e.bytes).toList());
    setState(() {
      _data = _GalleryData(
        images: images.map((e) => e.bytes).toList(),
        // thumbs: _data!.thumbs,
        thumbs: thumbs,
        mimetypes: images.map((e) => e.mimetype).toList(),
        encodedPaths: images.map((e) => e.encodedPath).toList(),
      );
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: !widget.onlySelect ? BlurredAppBar(
        title: widget.trashMode ? "Trash" :  "Library",
        subtitle: !widget.trashMode ? "$elements element${elements > 1 ? "s" : ""}" : null,
        actions: showButtons || !widget.onlySelect ? [
          // !widget.trashMode ?
          //   Button.iconOnly(
          //     icon: const Icon(CupertinoIcons.refresh, color: Colors.white),
          //     glassIcon: CNSymbol('arrow.clockwise', size: 17),
          //     tint: Colors.white.withAlpha(10),
          //     glassConfig: const CNButtonConfig(
          //       padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          //     ),
          //     onPressed: () {
          //        _refresh();
          //     },
          //   ) : SizedBox(),

          SizedBox(width: 10),
          !widget.trashMode ?
            Button.iconOnly(
              icon: const Icon(CupertinoIcons.settings, color: Colors.white),
              glassIcon: CNSymbol('gear', size: 17),
              tint: Colors.white.withAlpha(10),
              glassConfig: const CNButtonConfig(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              onPressed: () {
                  showModalBottomSheet(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
                    backgroundColor: Colors.black,
                    isScrollControlled: true,
                    // showDragHandle: true,
                    context: context, builder: (context) {
                    return SettingsPage();
                  }
                );
              },
            ) : SizedBox(),

          const SizedBox(width: 10),

          ConstrainedBox(
            constraints : const BoxConstraints(maxWidth: 95),
            child: Button(
              label: selectedMode ? "Cancel" : "Select",
              tint: Colors.white.withAlpha(10),
              glassConfig: const CNButtonConfig(
                style: CNButtonStyle.prominentGlass,
              ),
              onPressed: () {
                setState(() {
                  selectedMode = !selectedMode;
                  selectedImages.clear();
                  showTabBar.value = false;
                });
              },
            )
          )
        ] : null,
      ) : null,
      backgroundColor: Colors.black,
      body: Builder(
          builder: (context) {
            if (_loading) {
              return SizedBox();
            }
            if (_data == null) {
              return const Center(child: Text("Error loading images"));
            }

            final data = _data!;
            final images = data.images;
            final mimetypes = data.mimetypes;
            final thumbs = data.thumbs;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              elements = images.length;
              showButtons = images.isNotEmpty;
            });
          });
          
          if (images.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.photo, size: 64),
                  SizedBox(height: 5),
                  const Text("No medias found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: thumbs.length,
                    itemBuilder: (context, index) {
                      final bytes = thumbs[index];
                  
                      return bytes == null ? Container(color: Colors.grey[900]) :
                       Builder(
                        builder: (itemContext) => SizedBox(
                          width: MediaQuery.of(context).size.width / 3 - 2,
                          height: MediaQuery.of(context).size.width / 3 - 2,
                          child: GestureDetector(
                            onLongPress: () {
                              final screenWidth = MediaQuery.of(context).size.width;
                              final box =
                                  itemContext.findRenderObject() as RenderBox;
                              final position = box.localToGlobal(Offset.zero);
                  
                              final targetX =
                                  position.dx + (box.size.width / 2) - 115;
                              final clampedX =
                                  targetX.clamp(15.0, screenWidth - 230 - 10);
                  
                              HapticFeedback.mediumImpact();
                  
                              showGeneralDialog(
                                context: context,
                                // barrierColor: Colors.black26,
                                barrierDismissible: true,
                                barrierLabel: '',
                                pageBuilder:
                                    (context, animation, secondaryAnimation) {
                                  return Stack(
                                    children: [
                                      Positioned(
                                        left: clampedX,
                                        top: position.dy + box.size.height + 10,
                                        width: 230,
                                        child: const Material(
                                          color: Colors.transparent,
                                          elevation: 0,
                                          child: ContextMenu(),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            onTap: () {
                              if (selectedMode || widget.onlySelect) {
                                setState(() {
                                  if (selectedImages.contains(index)) {
                                    selectedImages.remove(index);
                                  } else {
                                    selectedImages.add(index);
                                  }
                                });
                                countSelected.value =  selectedImages.length;
                              } else {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    opaque: false,
                                    transitionDuration: const Duration(milliseconds: 300),
                                    reverseTransitionDuration: const Duration(milliseconds: 300),
                                    pageBuilder: (_, __, ___) => ViewerPage(
                                      images: data.images.whereType<Uint8List>().toList(), 
                                      mimetype: mimetypes,
                                      index: index, 
                                      encodedPaths: data.encodedPaths,
                                      trashMode: widget.trashMode,
                                      onRefresh: _refresh,
                                    ),
                                    transitionsBuilder: (_, animation, ___, child) {
                                      return Stack(
                                        children: [
                                          FadeTransition(
                                            opacity: animation,
                                            child: const ColoredBox(
                                              color: Colors.black,
                                              child: SizedBox.expand(),
                                            ),
                                          ),
                                          child
                                        ],
                                      );
                                    }
                                  )
                                ).then((_) => _refresh());
                              }
                            },
                            child: Stack(
                              children: [
                                Hero(
                                  tag: "image_$index",
                                  flightShuttleBuilder: (_, animation, direction, fromContext, toContext) {
                                    return Image.memory(
                                      bytes,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                  child: Image.memory(
                                    bytes, 
                                    fit: BoxFit.cover, 
                                    width: double.infinity, 
                                    height: double.infinity, 
                                    opacity: (selectedMode || widget.onlySelect) && selectedImages.contains(index) ? const AlwaysStoppedAnimation(0.8) : const AlwaysStoppedAnimation(1.0),
                                  ),
                                ),
                                if ((selectedMode || widget.onlySelect) && selectedImages.contains(index))
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Container(
                                      margin: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child:  Icon(
                                        CupertinoIcons.checkmark_circle_fill,
                                        color: CupertinoColors.systemBlue,
                                        size: 22,
                                      ),
                                    ),
                                ),
                  
                                if (widget.trashMode)...[
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        stops: const [0.0, 0.3],
                                        colors: [
                                          Colors.black.withAlpha(190),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Builder(
                                      builder: (context) {
                                        final entry = PhotoStore.get(data.encodedPaths[index]);
                                        if (entry?.deletedAt == null) return const SizedBox();
                                        final days = (30 - DateTime.now().difference(entry!.deletedAt!).inDays).clamp(0, 30);
                                        return Text(
                                          "$days days",
                                          style: TextStyle(fontWeight: FontWeight.w500),
                                        );
                                      },
                                    ),
                                  ),

                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (widget.trashMode && selectedImages.isNotEmpty)
                SafeArea(
                  child: Padding(
                    padding: EdgeInsetsGeometry.symmetric(horizontal: 15),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Button.iconOnly(
                            onPressed: () async {
                              for (final i in selectedImages) {
                                await PhotoStore.restore(data.encodedPaths[i]);
                              }
                              _removeLocally(selectedImages);
                            },
                            glassIcon: CNSymbol('arrow.up.bin', size: 20),
                            icon: Icon(CupertinoIcons.arrow_up_bin, size: 20),
                            tint: Theme.of(context).scaffoldBackgroundColor,
                            glassConfig: CNButtonConfig(
                              style: CNButtonStyle.prominentGlass
                          )),

                          Button.iconOnly(
                            onPressed: () async {
                              showGeneralDialog(
                                barrierDismissible: false,
                                context: context,
                                pageBuilder: (context, animation, secondaryAnimation) {
                                  return MyDialog(
                                    content: "This action cannot be undone. The image will also be deleted from your server.",
                                    principalButton: TextButton(
                                      child: Text("Delete", style: TextStyle(fontSize: 16, color: CupertinoColors.destructiveRed)),
                                      onPressed: () async {
                                        for (final i in selectedImages) {
                                          await PhotoStore.hardDelete(data.encodedPaths[i]);
                                        }
                                        Navigator.pop(context);
                                        _removeLocally(selectedImages);
                                      }
                                    ),
                                  );
                                }
                              );
                            },
                            glassIcon: CNSymbol('trash', size: 20),
                            icon: Icon(CupertinoIcons.trash, size: 20),
                            tint: Theme.of(context).scaffoldBackgroundColor,
                            glassConfig: CNButtonConfig(
                              style: CNButtonStyle.prominentGlass
                          )),
                        ],
                      ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
