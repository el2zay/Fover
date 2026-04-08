import 'dart:developer';
import 'dart:io';
import 'dart:async';

import 'package:clipboard/clipboard.dart';
import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:fover/main.dart';
import 'package:fover/pages/settings.dart';
import 'package:fover/pages/viewer.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/services/download.dart';
import 'package:fover/src/services/fover_picker_delegate.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:fover/src/utils/requests.dart';
import 'package:fover/src/widgets/albums_list.dart';
import 'package:fover/src/widgets/blurred_app_bar.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fover/src/widgets/dialog.dart';
import 'package:fover/src/widgets/pop_menu.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

final ValueNotifier<int> countSelected = ValueNotifier<int>(0);

enum Album {
  none,
  videos,
  favorites,
  screenshots,
  hidden,
  trash,
  other
}

class LibraryPage extends StatefulWidget {
  final bool onlySelect;
  final Function(List<String> paths, Uint8List? thumbBytes)? onSelectedChanged;
  final String? albumName;
  final Album album; 
  final bool research;
  final String searchText;


  const LibraryPage({
    super.key,
    this.onlySelect = false, 
    this.onSelectedChanged, 
    this.albumName,
    this.album = Album.none,
    this.research = false,
    this.searchText = "",
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _GalleryData {
  final List<Uint8List?> images;
  final List<Uint8List?> thumbs;
  final List<Future<Uint8List?>?> thumbFutures;
  final List<String> mimetypes;
  final List<String> encodedPaths;

  const _GalleryData({
    required this.images, 
    required this.thumbs, 
    required this.thumbFutures,
    required this.mimetypes, 
    required this.encodedPaths
  });
}

class _MediaEntry {
  final Uint8List? bytes;
  final String mimetype;
  final String encodedPath;

  const _MediaEntry({
    required this.bytes, 
    required this.mimetype, 
    required this.encodedPath
  });
}

class _LibraryPageState extends State<LibraryPage> {
  bool showButtons = false;
  _GalleryData? _allData;
  _GalleryData? _filteredData;
  bool selectedMode = false;
  bool _loading = true;
  List<int> selectedImages = [];
  int elements = 0;
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;
  double _pullUpProgress = 0.0;
  static const double _refreshThreshold = 160.0;

  _GalleryData? get _data => _filteredData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.searchText != widget.searchText) {
      _applyFilter();
    }
  }

  Future pickImages() async {
    final provider = DefaultAssetPickerProvider(
      maxAssets: 100,
      requestType: RequestType.common,
    );

    final delegate = FoverPickerDelegate(
      provider: provider, 
      initialPermission: await AssetPicker.permissionCheck(),
    );
    

    // Generated with AI
    if (!mounted) return;
    final List<AssetEntity>? assets = await AssetPicker.pickAssetsWithDelegate<
      AssetEntity,
      AssetPathEntity,
      DefaultAssetPickerProvider,
      FoverPickerDelegate
    >(
      context,
      delegate: delegate,
      useRootNavigator: false,
    );
    //


    if (assets == null || assets.isEmpty) return;

    List<File> files = [];
    final List<String> fileNames = [];
    for (final asset in assets) {
      final file = await asset.originFile;

      if (file != null) {
          files.add(file);
          fileNames.add(_realFileName(file.path, asset.title));
        }
    }

    switch (detectBackend()) {
      case ServerBackend.freebox:
        await uploadLocalFiles(files: files, filenames: fileNames);
      case ServerBackend.copyparty:
        await CopypartyService.uploadLocalFiles(files: files, filenames: fileNames);
      default:
        break;
    }
    await _refresh();

  }

  static String _realFileName(String path, String? title) {
    if (title != null && title.isNotEmpty) return title;

    final match = RegExp(r'_o_(.+)$').firstMatch(path);
    if (match != null) return match.group(1)!;

    return path.split('/').last;
  }

  // Generated with AI
  void _applyFilter() {
    if (_allData == null) return;

  final query = widget.searchText.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _filteredData = _cloneGalleryData(_allData!);
        elements = _filteredData!.images.length;
        showButtons = _filteredData!.images.isNotEmpty;
      });
      return;
    }

    final matches = <int>[];

    for (int i = 0; i < _allData!.encodedPaths.length; i++) {
      final encodedPath = _allData!.encodedPaths[i];
      final photo = PhotoStore.get(encodedPath);

      final name = photo?.name?.toLowerCase() ?? '';
      final camera = photo?.cameraModel?.toLowerCase() ?? '';
      final dt = PhotoStore.getDate(encodedPath);
      final dateStr =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

      if (name.contains(query) ||
          camera.contains(query) ||
          dateStr.contains(query)) {
        matches.add(i);
      }
    }

    setState(() {
      _filteredData = _subsetGalleryData(_allData!, matches);
      elements = _filteredData!.images.length;
      showButtons = _filteredData!.images.isNotEmpty;
      selectedImages.clear();
    });
  }

  _GalleryData _cloneGalleryData(_GalleryData source) {
    return _GalleryData(
      images: List<Uint8List?>.from(source.images),
      thumbs: List<Uint8List?>.from(source.thumbs),
      thumbFutures: List<Future<Uint8List?>?>.from(source.thumbFutures),
      mimetypes: List<String>.from(source.mimetypes),
      encodedPaths: List<String>.from(source.encodedPaths),
    );
  }

  _GalleryData _subsetGalleryData(_GalleryData source, List<int> indexes) {
    return _GalleryData(
      images: indexes.map((i) => source.images[i]).toList(),
      thumbs: indexes.map((i) => source.thumbs[i]).toList(),
      thumbFutures: indexes.map((i) => source.thumbFutures[i]).toList(),
      mimetypes: indexes.map((i) => source.mimetypes[i]).toList(),
      encodedPaths: indexes.map((i) => source.encodedPaths[i]).toList(),
    );
  }

  Future<void> _load() async {
    final images = await _loadImagesWithoutSearch();

    List<Uint8List?> thumbs;
    List<Future<Uint8List?>?> thumbFutures;

    if (detectBackend() == ServerBackend.copyparty) {
      thumbs = List.filled(images.length, null, growable: true);
      thumbFutures = images
          .map((e) => CopypartyService.getThumbnail(e.encodedPath))
          .toList();
    } else {
      thumbs = await _compressImages(images.map((e) => e.bytes).toList());
      thumbFutures = List.filled(images.length, null, growable: true);
    }

    if (!mounted) return;

    _allData = _GalleryData(
      images: images.map((e) => e.bytes).toList(),
      thumbs: thumbs,
      thumbFutures: thumbFutures,
      mimetypes: images.map((e) => e.mimetype).toList(),
      encodedPaths: images.map((e) => e.encodedPath).toList(),
    );

    _filteredData = _cloneGalleryData(_allData!);

    setState(() {
      _loading = false;
      elements = _filteredData!.images.length;
      showButtons = _filteredData!.images.isNotEmpty;
    });

    _applyFilter();

    FlutterNativeSplash.remove();

    if (_data!.images.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }
  
  void _removeLocally(List<int> indexes) {
    setState(() {
      final sorted = indexes.toList()..sort((a, b) => b.compareTo(a));
      for (final i in sorted) {
        _data!.images.removeAt(i);
        _data!.thumbs.removeAt(i);
        _data!.thumbFutures.removeAt(i);
        _data!.mimetypes.removeAt(i);
        _data!.encodedPaths.removeAt(i);
      }
      selectedImages.clear();
    });
      elements = _data!.images.length;
  }
  //


  Future<List<_MediaEntry>> _loadImagesWithoutSearch() async {
    List<Map<String, dynamic>> entries;
    final currentQuery = searchQuery.value;

    if (connectedToInternet) {
      entries = (await fetchPhotosDir()).cast<Map<String, dynamic>>();
    } else {
      entries = PhotoStore.getAll()
        .where((p) => p.localPath != null && File(p.localPath!).existsSync())
        .map((p) => {
          'path': p.path,
          'mimetype': p.mimetype ?? 'image/jpeg',
        })
        .toList();
    }

    final results = await Future.wait(
      entries.map((entry) async {

        final photo = PhotoStore.get(entry['path'] as String);
        final isVideo = entry['mimetype'].startsWith('video/');

        if (photo?.localPath != null && File(photo!.localPath!).existsSync()) {
          if (isVideo) {
            return await VideoThumbnail.thumbnailData(
              video: photo.localPath!,
              imageFormat: ImageFormat.WEBP,
              maxWidth: 300,
              quality: 10,
            );
          }
          return await File(photo.localPath!).readAsBytes() as Uint8List?;
        }

        if (connectedToInternet == false) return null;
        try {
          return await fetchImageBytes(entry['path'], entry['mimetype']);
        } catch (e) {
          log("Error fetching image bytes for ${entry['path']} : $e");
          return null;
        }
      }),
    );

    final filtered = results.asMap().entries.where((e) {
      final stored = PhotoStore.get(entries[e.key]['path'] as String);
      if (stored?.isOldVersion == true) return false;
      if (widget.albumName != null) {
        return stored?.albums?.contains(widget.albumName) == true;
      }
      if (widget.album == Album.favorites) return stored?.favorite == true;
      if (widget.album == Album.screenshots) return stored?.isScreenshot == true && (stored?.deletedAt == null);
      return widget.album == Album.trash 
        ? stored?.deletedAt != null
        : stored?.deletedAt == null;
      }).map((e) => _MediaEntry(
        bytes: e.value,
        mimetype: entries[e.key]['mimetype'] as String,
        encodedPath: entries[e.key]['path'] as String,
    )).toList();


    filtered.sort((a, b) {
      final dateA = PhotoStore.getDate(a.encodedPath);
      final dateB = PhotoStore.getDate(b.encodedPath);
      return dateA.compareTo(dateB);
    });

    return filtered;
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
    final images = await _loadImagesWithoutSearch();

    List<Uint8List?> thumbs;
    List<Future<Uint8List?>?> thumbFutures;

    if (detectBackend() == ServerBackend.copyparty) {
      thumbs = List.filled(images.length, null, growable: true);
      thumbFutures = images
          .map((e) => CopypartyService.getThumbnail(e.encodedPath))
          .toList();
    } else {
      thumbs = await _compressImages(images.map((e) => e.bytes).toList());
      thumbFutures = List.filled(images.length, null, growable: true);
    }

    if (!mounted) return;

    _allData = _GalleryData(
      images: images.map((e) => e.bytes).toList(),
      thumbs: thumbs,
      thumbFutures: thumbFutures,
      mimetypes: images.map((e) => e.mimetype).toList(),
      encodedPaths: images.map((e) => e.encodedPath).toList(),
    );

    _applyFilter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: !widget.onlySelect && !widget.research ? BlurredAppBar(
        title: widget.albumName != null ? widget.albumName! : widget.album == Album.trash ? "Trash" : widget.album == Album.favorites ? "Favorites" : widget.album == Album.screenshots ? "Screenshots" : "Library",
        subtitle:  widget.album != Album.trash ? "$elements element${elements > 1 ? "s" : ""}" : null,
        isAlbum:  widget.album != Album.none || widget.albumName != null ,
        onBack: () => Navigator.of(context).pop(),
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
          if (widget.album != Album.trash && widget.album != Album.favorites &&widget.album != Album.screenshots && connectedToInternet)...[
             widget.albumName == null ?
              Button.iconOnly(
                icon: const Icon(CupertinoIcons.settings, color: Colors.white),
                glassIcon: CNSymbol('gear', size: 17),
                tint: Colors.white.withAlpha(10),
                glassConfig: const CNButtonConfig(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                ),
                onPressed: () {
                    showCupertinoSheet(
                      context: context, 
                      builder: (context) {
                      return SettingsPage();
                    }
                  );
                },
              ) : SizedBox(),
          
            SizedBox(width: 10),
            Button.iconOnly(
              icon: Icon(CupertinoIcons.add, color: Colors.white),
              glassIcon: CNSymbol('plus', size: 17),
              onPressed: () async {
                if (widget.albumName == null) {
                  await pickImages();
                } else {
                  // TODO : add to existing album
                  showModalBottomSheet(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
                    backgroundColor: Colors.black,
                    isScrollControlled: true,
                    context: context, 
                    builder: (context) {
                      return Scaffold(
                        appBar: AppBar(
                          leading: 
                          Transform.scale(
                            scale: 0.9,
                            child: Button.iconOnly(
                                icon: Icon(Icons.close, size: 16),
                                glassIcon: CNSymbol('xmark', size: 16),
                                backgroundColor: Colors.transparent,
                                onPressed: () => Navigator.pop(context)
                            ),
                          ),
                          title: Text("Select photos", style: TextStyle(fontWeight: FontWeight.w500)),
                          actionsPadding: EdgeInsets.only(left: 10),
                          actions: [
                            ValueListenableBuilder<int>(
                              valueListenable: countSelected,
                              builder: (context, value, _) {
                                return Button.iconOnly(
                                  enabled: value > 0,
                            
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(CupertinoIcons.check_mark, size: 14),
                                  glassIcon: CNSymbol('checkmark', size: 14),
                                  tint: Colors.blue,
                                  glassConfig: CNButtonConfig(
                                    style: CNButtonStyle.prominentGlass,

                                  ),
                                  backgroundColor: Colors.blue
                            
                                );
                              }
                            ),
                          ]
                        ),
                        body: LibraryPage(
                          onlySelect: true,
                          onSelectedChanged: (paths, thumbBytes) {
                            for (final path in paths) {
                              PhotoStore.addToAlbum(path: path, album: widget.albumName!);
                            }
                            _refresh();
                            countSelected.value = paths.length;
                          },
                        ),
                      );
                    }
                  );
                }
              }
            )
          ],

          const SizedBox(width: 10),

          ConstrainedBox(
            constraints : const BoxConstraints(maxWidth: 95),
            child: Button(
              enabled: _data?.images.isNotEmpty ?? false,
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
      body: Builder(
        builder: (context) {
          if (_loading) {
            return SizedBox();
          }
          if (_data == null) {
            return const Center(child: Text("Error loading images"));
          }

          Future triggerPullRefresh() async {
            if (_isRefreshing) return;
            setState(() {
              _isRefreshing = true;
              _pullUpProgress = 0;
            });
            HapticFeedback.mediumImpact();
            await _refresh();
            if (mounted) {
              setState(() {
                _isRefreshing = false;
              });
            }
          }

          final data = _data!;
          final images = data.images;
          final mimetypes = data.mimetypes;          
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

          return Stack(
            children: [
              Positioned.fill(
                child: NotificationListener<ScrollNotification>(
                    // generated with AI
                    onNotification: (notification) {
                      if (_isRefreshing) return false;
                      if (notification is ScrollUpdateNotification && 
                      notification.metrics.outOfRange && 
                      notification.metrics.pixels > notification.metrics.maxScrollExtent) {
                        final excess = notification.metrics.pixels - notification.metrics.maxScrollExtent;
                        setState(() {
                          _pullUpProgress = ((excess / _refreshThreshold).clamp(0.0, 1.0));
                        });
                        if (excess >= _refreshThreshold) {
                          triggerPullRefresh();
                        }
                      }

                      if (notification is ScrollEndNotification && !_isRefreshing) {
                        setState(() {
                          _pullUpProgress = 0.0;
                        });
                      }
                    return false;
                    //
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: GridView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemCount: data.encodedPaths.length,
                      itemBuilder: (context, index) {
                        final photo = PhotoStore.get(data.encodedPaths[index]);

                        return _MediaTile(
                          index: index,
                          bytes: data.thumbs[index], 
                          thumbFuture: data.thumbFutures[index], 
                          selected: (selectedMode || widget.onlySelect) && selectedImages.contains(index), 
                          isVideo: data.mimetypes[index].startsWith('video/'), 
                          isFavorite: photo?.favorite == true, 
                          trashMode: widget.album == Album.trash, 
                          daysLeft: photo?.deletedAt != null
                            ? (30 - DateTime.now().difference(photo!.deletedAt!).inDays).clamp(0, 30)
                            : null,
                          onTap: () async {
                            if (selectedMode || widget.onlySelect) {
                              setState(() {
                                if (selectedImages.contains(index)) {
                                  selectedImages.remove(index);
                                } else {
                                  selectedImages.add(index);
                                }
                              });

                              final paths = selectedImages.map((i) => data.encodedPaths[i]).toList();
                              final thumbBytes = selectedImages.isNotEmpty 
                                  ? (data.thumbs[selectedImages.first] ?? await data.thumbFutures[selectedImages.first])
                                  : null;
                                widget.onSelectedChanged?.call(paths, thumbBytes);

                              widget.onSelectedChanged?.call(paths, thumbBytes);
                              countSelected.value = selectedImages.length;
                              countSelected.value = selectedImages.length;
                            } else {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  opaque: true,
                                  transitionDuration: const Duration(milliseconds: 300),
                                  reverseTransitionDuration: const Duration(milliseconds: 300),
                                  pageBuilder: (_, __, ___) => ViewerPage(
                                    images: data.images.toList(),
                                    mimetype: mimetypes,
                                    index: index,
                                    encodedPaths: data.encodedPaths,
                                    trashMode: widget.album == Album.trash,
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

                          menuProvider: (request) {
                            return widget.album != Album.trash ? Menu(
                              children: [
                                MenuAction(
                                  title: DownloadService.isDownloaded(data.encodedPaths[index])
                                    ? 'Remove download'
                                    : 'Download',
                                  image: MenuImage.icon(DownloadService.isDownloaded(data.encodedPaths[index])
                                    ? CupertinoIcons.arrow_down_circle_fill
                                    : CupertinoIcons.arrow_down_circle),
                                  callback: () async {
                                    final photo = PhotoStore.get(data.encodedPaths[index]);
                                    if (!DownloadService.isDownloaded(data.encodedPaths[index])) {
                                      final path = await DownloadService.download(
                                        encodedPath: data.encodedPaths[index],
                                        filename: photo?.name ?? data.encodedPaths[index],
                                      );
                                      log('Downloaded to: $path');
                                    } else {
                                      log("ici");
                                      DownloadService.remove(data.encodedPaths[index]);
                                    }
                                  }
                                ),
                                if (mimetypes[index].startsWith("image/"))
                                  MenuAction(
                                    title: "Copy",
                                    image: MenuImage.icon(CupertinoIcons.doc_on_doc),
                                    callback: () => FlutterClipboard.copyImage(data.thumbs[index] ?? Uint8List(0))
                                  ),
                                if (PhotoStore.get(data.encodedPaths[index])?.editedFrom != null)
                                  MenuAction(
                                    title: "Revert to original",
                                    image: MenuImage.icon(CupertinoIcons.arrow_counterclockwise_circle),
                                    callback: () async {
                                      await PhotoStore.revertEdit(data.encodedPaths[index]);
                                      setState(() {
                                        data.images.removeAt(index);
                                        data.thumbs.removeAt(index);
                                        data.thumbFutures.removeAt(index);
                                        data.mimetypes.removeAt(index);
                                        data.encodedPaths.removeAt(index);
                                        elements = data.images.length;
                                      });
                                      _refresh();
                                    },
                                  ),
                                MenuAction(
                                  title: "Duplicate",
                                  image: MenuImage.icon(CupertinoIcons.plus_square_on_square),
                                  callback: () => PhotoStore.duplicate(path: data.encodedPaths[index])
                                ),
                                MenuAction(
                                  title: "Share",
                                  image: MenuImage.icon(CupertinoIcons.share),
                                  callback: () {}
                                ),
                                MenuAction(
                                  title: "Hide",
                                  image: MenuImage.icon(CupertinoIcons.eye_slash),
                                  callback: () => PhotoStore.update(path: data.encodedPaths[index], hidden: true)
                                ),
                                widget.albumName == null 
                                  ? MenuAction(
                                    title: "Add to album",
                                    image: MenuImage.icon(CupertinoIcons.plus_rectangle_on_rectangle),
                                    callback: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
                                        builder: (context) {
                                          return AddToAlbumSheet(
                                            photoPath: [data.encodedPaths[index]],
                                          );
                                        }
                                      );
                                    }
                                  ) 
                                  : MenuAction(
                                    title: "Remove from album",
                                    image: MenuImage.icon(CupertinoIcons.xmark),
                                    callback: () {
                                      PhotoStore.removeFromAlbum(path: data.encodedPaths[index], album: widget.albumName!);
                                      setState(() {
                                        _data!.images.removeAt(index);
                                        _data!.thumbs.removeAt(index);
                                        _data!.thumbFutures.removeAt(index);
                                        _data!.mimetypes.removeAt(index);
                                        _data!.encodedPaths.removeAt(index);
                                        elements = _data!.images.length;
                                      });
                                    }
                                  ),
                                MenuAction(
                                  title: "Delete",
                                  image: MenuImage.icon(CupertinoIcons.trash),
                                  attributes: MenuActionAttributes(destructive: true),
                                  callback: () {
                                    showGeneralDialog(
                                      barrierDismissible: false,
                                      context: context,
                                      pageBuilder: (context, animation, secondaryAnimation) {
                                        return MyDialog(
                                          content: "This photo will be deleted from all your devices. It will be kept in \"Deleted recently\" for 30 days.",
                                          principalButton: TextButton(
                                            child: Text("Delete", style: TextStyle(fontSize: 16, color: CupertinoColors.destructiveRed)),
                                            onPressed: () {
                                              PhotoStore.softDelete(data.encodedPaths[index]);
                                              setState(() {
                                                _data!.images.removeAt(index);
                                                _data!.thumbs.removeAt(index);
                                                _data!.thumbFutures.removeAt(index);
                                                _data!.mimetypes.removeAt(index);
                                                _data!.encodedPaths.removeAt(index);
                                                elements = _data!.images.length;
                                              });
                                              Navigator.pop(context);
                                            }
                                          ),
                                        );
                                      }
                                    );
                                  }
                                ),
                              ]
                            ) : Menu(
                              children: [
                                MenuAction(
                                  title: "Restore",
                                  image: MenuImage.icon(CupertinoIcons.arrow_up_bin),
                                  callback: () {
                                    PhotoStore.restore(data.encodedPaths[index]);
                                    setState(() {
                                      _data!.images.removeAt(index);
                                      _data!.thumbs.removeAt(index);
                                      _data!.thumbFutures.removeAt(index);
                                      _data!.mimetypes.removeAt(index);
                                      _data!.encodedPaths.removeAt(index);
                                    });
                                  }
                                ),
                                MenuAction(
                                  title: "Delete permanently",
                                  image: MenuImage.icon(CupertinoIcons.trash),
                                  attributes: MenuActionAttributes(destructive: true),
                                  callback: () {
                                    showGeneralDialog(
                                      barrierDismissible: false,
                                      context: context,
                                      pageBuilder: (context, animation, secondaryAnimation) {
                                        return MyDialog(
                                          content: "This action cannot be undone. The image will also be deleted from your server.",
                                          principalButton: TextButton(
                                            child: Text("Delete", style: TextStyle(fontSize: 16, color: CupertinoColors.destructiveRed)),
                                            onPressed: () async {
                                              final navigator = Navigator.of(context);
                                              await PhotoStore.hardDelete(data.encodedPaths[index]);
                                              if (!mounted) return;
                                              navigator.pop();
                                              setState(() {
                                                _data!.images.removeAt(index);
                                                _data!.thumbs.removeAt(index);
                                                _data!.thumbFutures.removeAt(index);
                                                _data!.mimetypes.removeAt(index);
                                                _data!.encodedPaths.removeAt(index);
                                                elements = _data!.images.length;
                                              });
                                            }
                                          ),
                                        );
                                      }
                                    );
                                  }
                                ),
                              ]
                            );
                          },
                        );
                      },
                    ),
                  ),
              ),
              ),
              if (!widget.research && _pullUpProgress > 0 || _isRefreshing)
                Positioned(
                  bottom: bottomNavKey.currentContext != null ? MediaQuery.of(context).size.height - (bottomNavKey.currentContext!.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dy + 10 : 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _pullUpProgress > 0.2 ? 1.0 : 0.0,
                      child: Column(
                        spacing: 5,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _isRefreshing
                                ? const CupertinoActivityIndicator(
                                    key: ValueKey('spinning'),
                                    color: Colors.white,
                                    radius: 10,
                                  )
                                : CupertinoActivityIndicator.partiallyRevealed(
                                    key: const ValueKey('progress'),
                                    progress: _pullUpProgress,
                                    color: Colors.white,
                                    radius: 10,
                                  ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _isRefreshing ? 'Refreshing...' : _pullUpProgress >= 1.0 ? 'Release to refresh' : 'Pull up to refresh',
                              key: ValueKey(_isRefreshing ? 'refreshing' : _pullUpProgress >= 1.0 ? 'release' : 'pull'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              if (selectedImages.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsetsGeometry.symmetric(horizontal: 15, vertical: 5),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            widget.album == Album.trash
                              ? Button.iconOnly(
                                onPressed: () async {
                                  final selectedPaths = selectedImages.map((i) => data.encodedPaths[i]).toList();
                                  for (final path in selectedPaths) {
                                    await PhotoStore.restore(path);
                                  }
                                  _removeLocally(selectedImages);
                                },
                                glassIcon: CNSymbol('arrow.up.bin', size: 20),
                                icon: Icon(CupertinoIcons.arrow_up_bin, size: 20),
                                tint: Theme.of(context).scaffoldBackgroundColor,
                              ) : PopMenu(
                                scale: 0.85,
                                showCopy: false,
                                isViewer: false,
                                isDownloaded: selectedImages.map((i) => data.encodedPaths[i]).every((p) => DownloadService.isDownloaded(p)),
                                isFavorite: false,
                                onSelected: (action) async {
                                  final selectedPaths = selectedImages.map((i) => data.encodedPaths[i]).toList();
                                  switch (action) {
                                    case PopMenuAction.download:
                                      for (final path in selectedPaths) {
                                        final photo = PhotoStore.get(path);
                                        if (DownloadService.isDownloaded(path)) {
                                          DownloadService.remove(path);
                                        } else {
                                          DownloadService.download(encodedPath: path, filename: photo!.name);
                                        }
                                      }
                                    break;
                                    case PopMenuAction.copy:
                                      break;
                                    case PopMenuAction.revert:
                                      break;
                                    case PopMenuAction.share:
                                      break;
                                    case PopMenuAction.favorite:
                                      for (final i in selectedImages) {
                                        await PhotoStore.update(path: data.encodedPaths[i], hidden: true);
                                      }
                                      _removeLocally(selectedImages);
                                      break;
                                    case PopMenuAction.duplicate:
                                      for (final i in selectedImages) {
                                        await PhotoStore.duplicate(path: data.encodedPaths[i]);
                                      }
                                      _refresh();
                                      break;
                                    case PopMenuAction.hide:
                                      for (final i in selectedImages) {
                                        await PhotoStore.update(path: data.encodedPaths[i], hidden: true);
                                      }
                                      _removeLocally(selectedImages);
                                      break;
                                    case PopMenuAction.addToAlbum:
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
                                        builder: (context) {
                                          return AddToAlbumSheet(
                                            photoPath: selectedImages.map((i) => data.encodedPaths[i]).toList(),
                                          );
                                        }
                                      );
                                      break;
                                    case PopMenuAction.adjustDate:
                                      break;
                                    case PopMenuAction.adjustLocation:
                                      break;
                                  }
                                },
                              ),
                            Button.iconOnly(
                              onPressed: () {
                                showGeneralDialog(
                                  barrierDismissible: false,
                                  context: context,
                                  pageBuilder: (context, animation, secondaryAnimation) {
                                    final selectedPaths = selectedImages.map((i) => data.encodedPaths[i]).toList();
                                    final sortedIndices = selectedImages.toList()..sort((a, b) => b.compareTo(a));
                                    return MyDialog(
                                      content: widget.album == Album.trash 
                                        ? "This action cannot be undone. The image will also be deleted from your server."
                                        : "This photo will be deleted from all your devices. It will be kept in \"Deleted recently\" for 30 days.",
                                      principalButton: TextButton(
                                        child: Text("Delete", style: TextStyle(fontSize: 16, color: CupertinoColors.destructiveRed)),
                                        onPressed: () {
                                          for (final path in selectedPaths) {
                                            if (widget.album == Album.trash) {
                                              PhotoStore.hardDelete(path);
                                            } else {
                                              PhotoStore.softDelete(path);
                                            }
                                          }
                                          setState(() {
                                            for (final i in sortedIndices) {
                                              _data!.images.removeAt(i);
                                              _data!.thumbs.removeAt(i);
                                              _data!.mimetypes.removeAt(i);
                                              _data!.encodedPaths.removeAt(i);
                                            }
                                            selectedImages.clear();
                                            elements = _data!.images.length;
                                          });
                                          Navigator.pop(context);
                                        },
                                      ),
                                    );
                                  }
                                );
                              },
                              glassIcon: CNSymbol('trash', size: 20),
                              icon: Icon(CupertinoIcons.trash, size: 20),
                              tint: Theme.of(context).scaffoldBackgroundColor,
                            ),
                          ],
                        ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final Uint8List? bytes;
  final Future<Uint8List?>? thumbFuture;
  final bool selected;
  final bool isVideo;
  final bool isFavorite;
  final bool trashMode;
  final int? daysLeft;
  final VoidCallback onTap;
  final MenuProvider menuProvider;

  const _MediaTile({
    required this.bytes,
    required this.thumbFuture,
    required this.selected,
    required this.isVideo,
    required this.isFavorite,
    required this.trashMode,
    required this.daysLeft,
    required this.onTap,
    required this.menuProvider,
    required this.index,
  });

  final int index;

  @override
  Widget build(BuildContext context) {
    final opacity = selected
      ? const AlwaysStoppedAnimation(0.8)
      : const AlwaysStoppedAnimation(1.0);
    return SizedBox(
      width: MediaQuery.of(context).size.width / 3 - 2,
      height: MediaQuery.of(context).size.width / 3 - 2,
      child: GestureDetector(
        onTap: onTap,
        child: ContextMenuWidget(
          mobileMenuWidgetBuilder: DefaultMobileMenuWidgetBuilder(brightness: Brightness.dark),
          menuProvider: menuProvider,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbFuture != null)
                FutureBuilder<Uint8List?>(
                  future: thumbFuture,
                  builder: (context, snapshot) {
                    if (snapshot.data == null) {
                      return Container(color: Colors.grey[900]);
                    }
                    return Hero(
                      tag: "image_$index",
                      child: Image.memory(snapshot.data!, fit: BoxFit.cover, opacity: opacity),
                    );
                  },
                )
              else if (bytes != null)
                Hero(
                  tag: "image_$index",
                  child: Image.memory(
                    bytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    opacity: opacity,
                  ),
                )
              else
                Container(color: Colors.grey[900]),

              if (selected)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: CupertinoColors.systemBlue,
                      size: 22,
                    ),
                  ),
                ),

              if (trashMode) ...[
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0.0, 0.3],
                      colors: [Colors.black.withAlpha(190), Colors.transparent],
                    ),
                  ),
                ),
                if (daysLeft != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      "$daysLeft days",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
              ],

              if (isFavorite)
                const Positioned(
                  bottom: 5, left: 5,
                  child: Icon(CupertinoIcons.heart_fill, size: 18),
                ),
              if (isVideo)
                const Positioned(
                  bottom: 5, right: 5,
                  child: Icon(CupertinoIcons.play_circle_fill, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

}


class AddToAlbumSheet extends StatefulWidget {
  final List<String?> photoPath;
  const AddToAlbumSheet({super.key, required this.photoPath});

  @override
  State<AddToAlbumSheet> createState() => _AddToAlbumSheetState();
}

class _AddToAlbumSheetState extends State<AddToAlbumSheet> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: Transform.scale(
          scale: 0.8,
          child: Button.iconOnly(
            icon: Icon(Icons.close),
            glassIcon: CNSymbol('xmark', size: 16),
            backgroundColor: Colors.transparent,
            onPressed: () => Navigator.pop(context)
          ),
        ),
        title: Text("Add to album", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: EdgeInsetsGeometry.all(10),
        child: AlbumsList(
          onTap: (album) {
            for (final path in widget.photoPath) {
              PhotoStore.addToAlbum(
                path: path ?? "",
                album: album.name,
              );
            }
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}