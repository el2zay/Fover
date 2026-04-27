import 'dart:developer';
import 'dart:io';
import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:clipboard/clipboard.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fover/main.dart';
import 'package:fover/pages/search.dart';
import 'package:fover/pages/settings.dart';
import 'package:fover/pages/viewer.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/services/download.dart';
import 'package:fover/src/services/fover_picker_delegate.dart';
import 'package:fover/src/services/freebox_service.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:fover/src/utils/lru_cache.dart';
import 'package:fover/src/utils/requests.dart';
import 'package:fover/src/widgets/albums_list.dart';
import 'package:fover/src/widgets/blurred_app_bar.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fover/src/widgets/dialog.dart';
import 'package:fover/src/widgets/pop_menu.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

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
  final String searchText;


  const LibraryPage({
    super.key,
    this.onlySelect = false, 
    this.onSelectedChanged, 
    this.albumName,
    this.album = Album.none,
    this.searchText = "",
  });

  @override
  State<LibraryPage> createState() => LibraryPageState();
}

class _GalleryData {
  final List<String> mimetypes;
  final List<String> encodedPaths;

  _GalleryData({
    required this.mimetypes,
    required this.encodedPaths,
  });
}

class _SearchEntry {
  final String encodedPath;
  final String mimetype;
  final String searchableText;
  final bool isFavorite;
  final bool isScreenshot;
  final bool hasDetectedText;
  final String sortKey;

  const _SearchEntry({
    required this.encodedPath,
    required this.mimetype,
    required this.searchableText,
    required this.isFavorite,
    required this.isScreenshot,
    required this.hasDetectedText,
    required this.sortKey
  });
}

class LibraryPageState extends State<LibraryPage> {
  bool showButtons = false;
  bool _isAtTop = true;
  _GalleryData? _allData;
  _GalleryData? _filteredData;
  static final _thumbCache = LruCache<String, Uint8List>(300);

  bool selectedMode = false;
  bool _loading = true;
  List<int> selectedImages = [];
  int elements = 0;
  bool isDeactivating = false;

  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;
  double _pullUpProgress = 0.0;
  static const double _refreshThreshold = 160.0;
  final ValueNotifier<bool> _isDragging = ValueNotifier(false);
  List<_SearchEntry> _searchIndex = [];
  String get _heroPrefix => widget.searchText.isEmpty ? 'library' : 'search';

 static const formatMap = <String, FileFormat>{
    'image/jpeg': Formats.jpeg,
    'image/png': Formats.png,
    'image/heic': Formats.heic,
    'image/gif': Formats.gif,
    'image/webp': Formats.webp,
    'video/mp4': Formats.mp4,
    'video/quicktime': Formats.mov,
};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      setState(() => _isAtTop = _scrollController.offset < 10);
    });
    showTabBar.value = true;
    _load();
  }

  @override 
  void dispose() {
    _scrollController.dispose();
    selectedMode = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showTabBar.value = true;
      }
    });

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.searchText != widget.searchText) {
      setState(() {
        _applyFilter();
      });
    }
  }

  Future pickImages() async {
    try {
      await AssetPicker.permissionCheck(
        requestOption: const PermissionRequestOption(
          iosAccessLevel: IosAccessLevel.readWrite,
        )
      );

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
        FoverPickerDelegate>(
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
          await FreeboxService.uploadLocalFiles(files: files, filenames: fileNames);
        case ServerBackend.copyparty:
          await CopypartyService.uploadLocalFiles(files: files, filenames: fileNames);
        default:
          break;
      }

      await _refresh();
    } catch (e) {
      final content = e.toString().contains("PermissionState.denied") 
        ? "Fover does not have permission to access your gallery." 
        : e.toString().replaceAll("Exception", "");
      showGeneralDialog(
        barrierDismissible: false,
        // ignore: use_build_context_synchronously
        context: context, 
        pageBuilder: (context, animation, secondaryAnimation) {
          return MyDialog(
            content: content, 
            principalButton: TextButton(
              onPressed: () {
                AppSettings.openAppSettings(type: AppSettingsType.appLocale);
              }, 
              child: Text("Grant access",  style: TextStyle(fontSize: 16, color: CupertinoColors.activeBlue))
            )
          );
        }
      );
    }
  }

  static String _realFileName(String path, String? title) {
    if (title != null && title.isNotEmpty) return title;

    final match = RegExp(r'_o_(.+)$').firstMatch(path);
    if (match != null) return match.group(1)!;

    return path.split('/').last;
  }

  // Generated with AI
  Future<void> _applyFilter() async {
    final query = widget.searchText.trim().toLowerCase();

    final result = await compute(_filterIsolate, {
      'index': _searchIndex,
      'query': query,
    });

    if (!mounted) return;

    setState(() {
      _filteredData = result;
      if (query.isEmpty) {
        _allData = _GalleryData(
          encodedPaths: List<String>.from(result.encodedPaths),
          mimetypes: List<String>.from(result.mimetypes),
        );
      }
      elements = result.encodedPaths.length;
      showButtons = result.encodedPaths.isNotEmpty;
    });
  }

  // _GalleryData _cloneGalleryData(_GalleryData source) {
  //   return _GalleryData(
  //     images: List<Uint8List?>.from(source.images),
  //     thumbs: List<Uint8List?>.from(source.thumbs),
  //     thumbFutures: List<Future<Uint8List?>?>.from(source.thumbFutures),
  //     mimetypes: List<String>.from(source.mimetypes),
  //     encodedPaths: List<String>.from(source.encodedPaths),
  //   );
  // }

  // _GalleryData _subsetGalleryData(_GalleryData source, List<int> indexes) {
  //   return _GalleryData(
  //     images: indexes.map((i) => source.images[i]).toList(),
  //     thumbs: indexes.map((i) => source.thumbs[i]).toList(),
  //     thumbFutures: indexes.map((i) => source.thumbFutures[i]).toList(),
  //     mimetypes: indexes.map((i) => source.mimetypes[i]).toList(),
  //     encodedPaths: indexes.map((i) => source.encodedPaths[i]).toList(),
  //   );
  // }

  Future<void> _load() async {
    await _buildSearchIndex();
    await _applyFilter();

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

  if ((_filteredData?.encodedPaths.isNotEmpty ?? false) && widget.searchText.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }
  
  void _removeLocally(List<int> indexes) {
    if (_filteredData == null || indexes.isEmpty) return;

    final pathsToRemove = indexes
        .where((i) => i >= 0 && i < _filteredData!.encodedPaths.length)
        .map((i) => _filteredData!.encodedPaths[i])
        .toSet();

    void removeFromGallery(_GalleryData gallery) {
      final indexesToRemove = <int>[];

      for (int i = 0; i < gallery.encodedPaths.length; i++) {
        if (pathsToRemove.contains(gallery.encodedPaths[i])) {
          indexesToRemove.add(i);
        }
      }

      indexesToRemove.sort((a, b) => b.compareTo(a));

      for (final i in indexesToRemove) {
        gallery.mimetypes.removeAt(i);
        gallery.encodedPaths.removeAt(i);
      }
    }

    setState(() {
      removeFromGallery(_filteredData!);

      if (_allData != null) {
        removeFromGallery(_allData!);
      }

      selectedImages.clear();
      elements = _filteredData!.encodedPaths.length;
      showButtons = _filteredData!.encodedPaths.isNotEmpty;
    });
  }

  Future<void> _buildSearchIndex() async {
    List<Map<String, dynamic>> entries;

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

    final filteredEntries = entries.where((entry) {
      final stored = PhotoStore.get(entry['path'] as String);
      if (stored?.isOldVersion == true) return false;

      if (widget.albumName != null) {
        return stored?.albums?.contains(widget.albumName) == true;
      }

      if (widget.album != Album.hidden && stored?.hidden == true) {
        return false;
      }

      if (widget.album == Album.videos) {
        return stored?.mimetype?.startsWith("video/") == true && stored?.deletedAt == null;
      }

      if (widget.album == Album.favorites) {
        return stored?.favorite == true;
      }

      if (widget.album == Album.screenshots) {
        return stored?.isScreenshot == true && stored?.deletedAt == null;
      }

      if (widget.album == Album.hidden) {
        return stored?.hidden == true && stored?.deletedAt == null;
      }

      if (widget.searchText.startsWith("has:detectedText")) {
        return stored?.detectedText != null && stored?.detectedText!.isNotEmpty == true && stored?.deletedAt == null;
      }

      return widget.album == Album.trash
        ? stored?.deletedAt != null
        : stored?.deletedAt == null;
    }).toList();

    final enriched = filteredEntries.map((entry) {
      final path = entry['path'] as String;
      final date = PhotoStore.getDate(path);
      return (
        entry: entry, 
        sortKey: '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}'
      );
    }).toList(); 

    enriched.sort((a, b) => a.sortKey.compareTo(b.sortKey));

    _searchIndex = enriched.map((e) {
      final path = e.entry['path'] as String;
      final photo = PhotoStore.get(path);
      return _SearchEntry(
        encodedPath: path,
        mimetype: e.entry['mimetype'] as String,
        searchableText: _buildSearchableText(path),
        isFavorite: photo?.favorite == true,
        isScreenshot: photo?.isScreenshot == true,
        hasDetectedText: photo?.detectedText?.isNotEmpty == true,
        sortKey: e.sortKey
      );
    }).toList();
  }
  //

  String _buildSearchableText(String encodedPath) {
    final photo = PhotoStore.get(encodedPath);

    final date = PhotoStore.getDate(encodedPath);
    final name = (photo?.name ?? '').toLowerCase();
    final camera = (photo?.cameraModel ?? '').toLowerCase();
    final description = (photo?.description ?? '').toLowerCase();
    final detectedText = (photo?.detectedText ?? '').toLowerCase();

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    const monthNames = [
      '',
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];

    final monthName = monthNames[date.month];

    return [
      name,
      camera,
      description,
      detectedText,
      year,
      month,
      day,
      monthName,
      "$year-$month-$day",
      "$day-$month-$year",
      "$year/$month/$day",
      "$day/$month/$year",
      "$monthName $year",
      "$day $monthName $year"
    ].join(' ').toLowerCase();
  }


  // Future<List<Uint8List?>> _compressImages(List<Uint8List?> list) async {
  //   final results = await Future.wait(list.map((origBytes) async {
  //     if (origBytes == null) return null;

  //     final origSize = origBytes.lengthInBytes / 1024;

  //     final compressed = await FlutterImageCompress.compressWithList(
  //       origBytes,
  //       minWidth: 300,
  //       minHeight: 300,
  //       quality: 10,
  //       format: CompressFormat.webp,
  //     );

  //     final compSize = compressed.lengthInBytes / 1024;
  //     log("Taille compressée ${compSize.toStringAsFixed(1)} KB - Réduit de ${((1 - compSize/origSize)*10).toStringAsFixed(1)}%");
  //     return compressed;
  //   }));

  //   return results;
  // }


  Future<void> _refresh() async {
    await _buildSearchIndex();
    await _applyFilter();

    if (!mounted) return;
    setState(() {});
  }

  // fonction qui permet de scroll tout en bas
  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  OverlayEntry? _uploadOverlay;
  final _cardVisible = ValueNotifier<bool>(false);
  bool alreadyPressed = false;

  void _dismissCard() {
    _cardVisible.value = false;
  }


  void _showUploadOverlay(bool alreadyPressed) {
    if (_cardVisible.value) {
      _dismissCard();
      return;
    }
    
    if (_uploadOverlay != null) return;

    _cardVisible.value = false; 
    _uploadOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _dismissCard, 
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + kToolbarHeight + 10,
          left: MediaQuery.of(context).size.width * 0.15,
          child: GestureDetector(
            onTap: () {}, 
            child: ValueListenableBuilder<bool>(
              valueListenable: _cardVisible,
              builder: (context, visible, child) => AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: Duration(milliseconds: visible ? 350 : 180),
                curve: visible ? Curves.easeOutCubic : Curves.easeInCubic,
                onEnd: () {
                  if (!visible) {
                    _uploadOverlay?.remove();
                    _uploadOverlay = null;
                  }
                },
                child: AnimatedScale(
                  scale: visible ? 1.0 : 0.92,
                  duration: Duration(milliseconds: visible ? 350 : 180),
                  curve: visible ? Curves.easeOutCubic : Curves.easeInCubic,
                  alignment: Alignment.topCenter,
                  child: child!,
                ),
              ),
              child: ValueListenableBuilder(
                valueListenable: CopypartyService.uploadProgress,
                builder: (context, progress, _) => Material(
                  color: Colors.transparent,
                  child: CNGlassCard(
                    tint: Colors.white.withAlpha(5),
                    child: Padding(
                      padding: const EdgeInsetsGeometry.symmetric(horizontal: 10, vertical: 0),
                      child: Column(
                        children: [
                          Text("Do you want to cancel the upload?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          SizedBox(height: 10),
                          CupertinoButton.tinted(
                            color: Colors.grey,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            minimumSize: Size(0, 30),
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 0),
                            child: Text("Cancel", style: TextStyle(
                              fontSize: 15, 
                              fontWeight: FontWeight.w500,
                              color: Colors.redAccent
                              )
                            ),
                            onPressed: () {
                              _dismissCard();
                              CopypartyService.cancelUpload();
                            }
                          )
                        ],
                      ),
                    )
                  ),
                ),
              ),
              )
            )
          )
        ]
      )
    );

    Overlay.of(context).insert(_uploadOverlay!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cardVisible.value = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: !widget.onlySelect && !widget.searchText.isNotEmpty ? BlurredAppBar(
        automaticallyImplyLeading: widget.album != Album.none || widget.albumName != null,
        title: widget.albumName != null 
          ? widget.albumName! 
          : widget.album != Album.none ? ""
          : "Library",
          // : widget.album == Album.trash 
          //   ? "Trash" 
          //   : widget.album == Album.favorites 
          //     ? "Favorites" 
          //     : widget.album == Album.screenshots 
          //       ? "Screenshots" 
          //       : widget.album == Album.hidden ? "Hidden"
          //         : "Library",
        subtitle: "$elements element${elements > 1 ? "s" : ""}",
        isAlbum:  widget.album != Album.none || widget.albumName != null ,
        onBack: () => Navigator.of(context).pop(),
        scrollController: _scrollController,
        initiallyAtTop: _isAtTop,
        actions: showButtons || !widget.onlySelect ? [
          if (widget.albumName == null)
            GestureDetector(
              onTap: () {
                _showUploadOverlay(alreadyPressed);
                setState(() => alreadyPressed = !alreadyPressed);
              },
              child: ValueListenableBuilder<double?>(
                valueListenable: CopypartyService.uploadProgress,
                builder: (context, progress, _) {
                  if (progress == null || progress >= 1.0) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_uploadOverlay != null) _dismissCard();
                    });
                    return const SizedBox.shrink();
                  }
                  return CircularProgressIndicator(
                    value: progress,
                    constraints: const BoxConstraints(minHeight: 25, minWidth: 25),
                    backgroundColor: Colors.white.withAlpha(35),
                    valueColor: AlwaysStoppedAnimation(Colors.blue[700]!),
                  );
                },
              ),
            ),
          SizedBox(width: 15),
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
              enabled: _filteredData?.encodedPaths.isNotEmpty ?? false,
              label: selectedMode ? "Cancel" : "Select",
              tint: Theme.of(context).primaryColor,
              onPressed: () {
                showTabBar.value = !showTabBar.value;
                setState(() {
                  selectedMode = !selectedMode;
                  selectedImages.clear();
                });
              },
            )
          )
        ] : null,
      ) : null,
      body: DropRegion(
        formats: Formats.standardFormats,
        onDropOver: (event) {
          final canAccept = event.session.items.any((item) => 
            item.localData != null || formatMap.values.any((format) => item.canProvide(format))
          );

          return canAccept ? DropOperation.copy : DropOperation.none;
        },
        onPerformDrop: (event) async {
          for (final item in event.session.items) {
            if (item.localData != null) {
              final encodedPath = item.localData as String;
              try {
                await PhotoStore.addToAlbum(path: encodedPath, album: widget.albumName!);
              } catch (e) {
                log("L'utilisateur n'est pas dans un album");
              }
            } else {
              final reader = item.dataReader!;

              for (final entry in formatMap.entries) {
                if (!reader.canProvide(entry.value)) continue;

                reader.getFile(entry.value, (file) async {
                  final bytes = await file.readAll();
                  final mimetype = entry.key;
                  final ext = mimetype.split('/').last;
                  final filename =  file.fileName ??'IMG_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.$ext';

                  switch (detectBackend()) {
                    case ServerBackend.freebox:
                      // TODO à implémenter
                      break;
                    case ServerBackend.copyparty:
                      await CopypartyService.uploadBytes(
                        bytes: bytes,
                        filename: filename,
                      );

                      break;
                    default:
                      break;
                  }
                });
              }
            }
            await _refresh();
          }
        },
        child: Builder(
        builder: (context) {
          if (_loading) {
            return Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoActivityIndicator(),
                  SizedBox(height: 10),
                  Text(
                    "Synchronizing your data", 
                    style: TextStyle(
                      fontSize: 16, 
                      color: Theme.of(context).primaryColor.withAlpha(150)
                    )
                  )
                ],
              ),
            );
          }
          if (_filteredData == null) {
            return const Center(child: Text("Error loading images"));
          }

          Future triggerPullRefresh() async {
            if (_isRefreshing) return;
            setState(() {
              _isRefreshing = true;
              _pullUpProgress = 0;
            });
            HapticFeedback.mediumImpact();
            await syncHive();
            await _refresh();
            if (mounted) {
              setState(() {
                _isRefreshing = false;
              });
            }
          }

          final data = _filteredData!;
          final mimetypes = data.mimetypes;
          if (data.encodedPaths.isEmpty) {
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
                  onNotification: (notification) {
                    // Generated with AI
                    if (_isRefreshing) return false;
                    if (notification is ScrollUpdateNotification && 
                    notification.metrics.outOfRange && 
                    notification.metrics.pixels > notification.metrics.maxScrollExtent) {
                      final excess = notification.metrics.pixels - notification.metrics.maxScrollExtent;
                      setState(() {
                        _pullUpProgress = (excess / _refreshThreshold).clamp(0.0, 1.0);
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
                  },
                  //
                  child: GridView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.only(
                      bottom: tabBarHeight.value * 1.6,
                      top:  MediaQuery.of(context).padding.top + 5
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).orientation == Orientation.portrait ? 3 : 5,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: data.encodedPaths.length,
                    itemBuilder: (context, index) {
                      final photo = PhotoStore.get(data.encodedPaths[index]);

                      return DragItemWidget(
                        canAddItemToExistingSession: true,
                        dragItemProvider: (request) async {
                          request.session.dragging.addListener(() {
                            _isDragging.value = request.session.dragging.value;
                          });

                          final encodedPath = data.encodedPaths[index];
                          final mimetype = data.mimetypes[index];
                          final existingData = await request.session.getLocalData();
                          if (existingData != null && existingData.contains(encodedPath)) {
                            return null;
                          }

                          final items = DragItem(
                            localData: encodedPath
                          );

                          final format = formatMap[mimetype] 
                            ?? (mimetype.startsWith('image/') ? Formats.jpeg : null)
                            ??  (mimetype.startsWith('video/') ? Formats.mp4 : null);

                            if (format != null) {
                              items.add(format.lazy(() async => (await fetchFullBytes(encodedPath)) ?? Uint8List(0)));
                            }

                            return items;
                        },
                        allowedOperations: () => [DropOperation.copy],
                        child: DraggableWidget(
                          child: _MediaTile(
                            key: ValueKey(data.encodedPaths[index]),
                            index: index,
                            encodedPath: data.encodedPaths[index],
                            mimetype: data.mimetypes[index],
                            selected: (selectedMode || widget.onlySelect) && selectedImages.contains(index), 
                            isVideo: data.mimetypes[index].startsWith('video/'), 
                            isFavorite: photo?.favorite == true, 
                            trashMode: widget.album == Album.trash, 
                            heroPrefix: _heroPrefix,
                            daysLeft: photo?.deletedAt != null
                              ? (30 - DateTime.now().difference(photo!.deletedAt!).inDays).clamp(0, 30)
                              : null,
                            onTap: () async {
                              if (_isDragging.value) return;

                              if (selectedMode || widget.onlySelect) {
                                setState(() {
                                  if (selectedImages.contains(index)) {
                                    selectedImages.remove(index);
                                  } else {
                                    selectedImages.add(index);
                                  }
                                });

                                final paths = selectedImages.map((i) => data.encodedPaths[i]).toList();
                                Uint8List? thumb;
                                if (selectedImages.isNotEmpty) {
                                  final firstIndex = selectedImages.first;
                                  final firstPath = data.encodedPaths[firstIndex];
                                  final photo = PhotoStore.get(firstPath);
                                  if (photo?.localPath != null && File(photo!.localPath!).existsSync()) {
                                    thumb = await File(photo.localPath!).readAsBytes();
                                  } else {
                                    thumb = await fetchImageBytes(firstPath, data.mimetypes[firstIndex]);
                                  }
                                }

                                widget.onSelectedChanged?.call(paths, thumb);
                                countSelected.value = selectedImages.length;
                              } else {
                                searchFocus.unfocus();
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    opaque: false,
                                    transitionDuration: const Duration(milliseconds: 300),
                                    reverseTransitionDuration: const Duration(milliseconds: 300),
                                    pageBuilder: (_, __, ___) => ViewerPage(
                                      mimetype: mimetypes,
                                      index: index,
                                      encodedPaths: data.encodedPaths,
                                      trashMode: widget.album == Album.trash,
                                      onRefresh: _refresh,
                                      heroPrefix: _heroPrefix,
                                    ),
                                    transitionsBuilder: (_, animation, __, child) {
                                    return FadeTransition(
                                      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                                      child: child,
                                    );
                                    },
                                  ),
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
                                      callback: () async {
                                        final bytes = await fetchFullBytes(data.encodedPaths[index]);
                                        if (bytes != null) await FlutterClipboard.copyImage(bytes);
                                      },
                                    ),
                                    if (PhotoStore.get(data.encodedPaths[index])?.editedFrom != null)
                                      MenuAction(
                                        title: "Revert to original",
                                        image: MenuImage.icon(CupertinoIcons.arrow_counterclockwise_circle),
                                        callback: () async {
                                          await PhotoStore.revertEdit(data.encodedPaths[index]);
                                          await _refresh();
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
                                    callback: () async {
                                      final bytes = await fetchFullBytes(data.encodedPaths[index]);
                                      if (bytes == null) return;

                                      await SharePlus.instance.share(
                                        ShareParams(
                                          files: [
                                            XFile.fromData(
                                              bytes,
                                              mimeType: mimetypes[index],
                                              name: PhotoStore.get(data.encodedPaths[index])?.name ?? 'media',
                                            )
                                          ]
                                        )
                                      );
                                    }
                                  ),
                                  MenuAction(
                                    title: "Hide",
                                    image: MenuImage.icon(CupertinoIcons.eye_slash),
                                    callback: () { 
                                      PhotoStore.update(path: data.encodedPaths[index], hidden: true);
                                      _removeLocally([index]);
                                    }
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
                                        PhotoStore.removeFromAlbum(
                                          path: data.encodedPaths[index],
                                          album: widget.albumName!,
                                        );
                                        _removeLocally([index]);
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
                                                _removeLocally([index]);
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
                                      _removeLocally([index]);
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
                                                _removeLocally([index]);
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
                          ),
                        )
                      );
                    }, 
                  ),
                ),
              ),
              if (!widget.searchText.isNotEmpty && _pullUpProgress > 0 || _isRefreshing)
                Positioned(
                  bottom:  MediaQuery.of(context).padding.bottom + 10,
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
                                    // color: Colors.white,
                                    radius: 10,
                                  )
                                : CupertinoActivityIndicator.partiallyRevealed(
                                    key: const ValueKey('progress'),
                                    progress: _pullUpProgress,
                                    // color: Colors.white,
                                    radius: 10,
                                  ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _isRefreshing ? 'Refreshing...' : _pullUpProgress >= 1.0 ? 'Release to refresh' : 'Pull up to refresh',
                              key: ValueKey(_isRefreshing ? 'refreshing' : _pullUpProgress >= 1.0 ? 'release' : 'pull'),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor.withAlpha(200),
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
              Positioned(
                bottom: 15,
                left: 35,
                right: 35,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsetsGeometry.symmetric(horizontal: 15, vertical: 5),
                    child: AnimatedSwitcher(duration: Duration(milliseconds: 300),
                      child: selectedImages.isNotEmpty && !widget.onlySelect 
                        ? Row(
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
                                  isDownloaded: selectedImages.every((i) => DownloadService.isDownloaded(data.encodedPaths[i])),
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
                                        final xFiles = <XFile>[];

                                        for (final i in selectedImages) {
                                          final encodedPath = data.encodedPaths[i];
                                          final bytes = await fetchFullBytes(encodedPath);
                                          if (bytes == null) continue;

                                          xFiles.add(XFile.fromData(
                                            bytes,
                                            mimeType: data.mimetypes[i],
                                            name: PhotoStore.get(encodedPath)?.name ?? 'media'
                                          ));
                                        }
                                        if (xFiles.isEmpty) break;
                                        await SharePlus.instance.share(
                                          ShareParams(
                                            files: xFiles
                                          )
                                        );
                                        break;
                                      case PopMenuAction.favorite:
                                        for (final i in selectedImages) {
                                          await PhotoStore.update(path: data.encodedPaths[i], favorite: true);
                                        }
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
                                enabled: selectedImages.isNotEmpty,
                                onPressed: () {
                                  showGeneralDialog(
                                    barrierDismissible: false,
                                    context: context,
                                    pageBuilder: (context, animation, secondaryAnimation) {
                                      final selectedPaths = selectedImages.map((i) => data.encodedPaths[i]).toList();
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

                                            _removeLocally(selectedImages);
                                            Navigator.pop(context);
                                            setState(() => selectedMode = false);
                                            showTabBar.value = true;
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
                        ) : null,
                    ),
                  ),
                ) ,
              ),
            ],
          );
        }),
      ),
    );
  }
}


// I wrote most of it myself, but part of the code was optimized using AI
class _MediaTile extends StatefulWidget {
  final String encodedPath;
  final String mimetype;
  final bool selected;
  final bool isVideo;
  final bool isFavorite;
  final bool trashMode;
  final int? daysLeft;
  final VoidCallback onTap;
  final MenuProvider menuProvider;
  final int index;
  final String heroPrefix;

  const _MediaTile({
    super.key,
    required this.encodedPath,
    required this.mimetype,
    required this.selected,
    required this.isVideo,
    required this.isFavorite,
    required this.trashMode,
    required this.daysLeft,
    required this.onTap,
    required this.menuProvider,
    required this.index,
    required this.heroPrefix,
  });

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  Uint8List? _thumb;

@override
  void initState() {
    super.initState();
    final cached = LibraryPageState._thumbCache.get(widget.encodedPath);
    if (cached != null) {
      _thumb = cached;
      return;
    }
    loadThumb().then((bytes) {
      if (bytes != null) {
          LibraryPageState._thumbCache.put(widget.encodedPath, bytes);
      }
      if (mounted) setState(() => _thumb = bytes);
    });
  }

  Future<Uint8List?> loadThumb() async {
    final photo = PhotoStore.get(widget.encodedPath);
    bool isVideo = widget.mimetype.startsWith('video/');

    if (photo?.localPath != null && File(photo!.localPath!).existsSync()) {
      if (isVideo) {
        return await VideoThumbnail.thumbnailData(
          video: photo.localPath!,
          imageFormat: ImageFormat.WEBP,
          maxWidth: 300,
          quality: 10,
        );
      }

      final bytes = await File(photo.localPath!).readAsBytes();
      return await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 300,
        minHeight: 300,
        quality: 10,
        format: CompressFormat.webp,
      );
    }

    if (!connectedToInternet) return null;

    try {
      if (detectBackend() == ServerBackend.copyparty) {
        return await CopypartyService.getThumbnail(widget.encodedPath);
      }

      final bytes = await fetchImageBytes(widget.encodedPath, widget.mimetype);

      if (isVideo) return bytes;

      if (bytes == null) return null;
      return await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 300, 
        minHeight: 300, 
        quality: 10, 
        format: CompressFormat.webp
      );
    } catch (_) {
      return null;
    }
  }


  @override
  Widget build(BuildContext context) {
    final opacity = widget.selected
        ? const AlwaysStoppedAnimation(0.8)
        : const AlwaysStoppedAnimation(1.0);

    return SizedBox(
      width: MediaQuery.of(context).size.width / 3 - 2,
      height: MediaQuery.of(context).size.width / 3 - 2,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ContextMenuWidget(
          menuProvider: widget.selected ? (_) => null : widget.menuProvider,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_thumb == null)
                Container(
                  color: Theme.brightnessOf(context) == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.grey[400],
                )
              else 
                Hero(
                  tag: widget.heroPrefix + widget.encodedPath, 
                  child: Image.memory(
                    _thumb!,
                    fit: BoxFit.cover,
                    opacity: opacity,
                    gaplessPlayback: true,
                  )
                ),
              if (widget.trashMode) ...[
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0.0, 0.3],
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                ),
                if (widget.daysLeft != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      "${widget.daysLeft} days",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
              ],

              if (widget.isFavorite)
                Positioned(
                  bottom: 5,
                  left: 5,
                  child: Icon(CupertinoIcons.heart_fill, size: 18, color: Colors.white),
                ),

              if (widget.isVideo)
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: buildDurationBadge(PhotoStore.get(widget.encodedPath)?.duration)
                ),

              if (widget.selected)
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
            ],
          ),
        ),
      ),
    );
  }

  Widget buildDurationBadge(int? seconds) {
    if (seconds == null) return Icon(CupertinoIcons.play_circle_fill, size: 18);
    final duration = Duration(seconds: seconds);
    final mm = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final label = duration.inHours > 0 ? '${duration.inHours}:$mm:$ss' : '$mm:$ss';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600
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

_GalleryData _filterIsolate(Map<String, dynamic> args) {
  final index = args['index'] as List<_SearchEntry>;
  final query = args['query'] as String;

  List<_SearchEntry> matches;

  if (query.isEmpty) {
    matches = index;
  } else if (query.startsWith("has:")) {
    final token = query.split(' ').first;
    final subQuery = query.substring(token.length).trim();

    matches = index.where((entry) {
      bool matchesToken;
      switch (token) {
        case 'has:detectedText':
          matchesToken = entry.hasDetectedText;
          break;
        case 'has:videos':
          matchesToken = entry.mimetype.startsWith('video/');
          break;
        case 'has:favorites':
          matchesToken = entry.isFavorite;
          break;
        case 'has:screenshots':
          matchesToken = entry.isScreenshot;
          break;
        case "has:thismonth":
            final now = DateTime.now();
            final photoDate = PhotoStore.getDate(entry.encodedPath);
            matchesToken = photoDate.year == now.year;
            break;
        default:
          matchesToken = true;
      }
      if (!matchesToken) return false;
      if (subQuery.isEmpty) return true;
      return subQuery
          .split(' ')
          .where((w) => w.isNotEmpty)
          .every((word) => entry.searchableText.contains(word));
    }).toList();
  } else {
    matches = index
      .where((entry) => entry.searchableText.contains(query))
      .toList();
  }

  return _GalleryData(
    encodedPaths: matches.map((e) => e.encodedPath).toList(),
    mimetypes: matches.map((e) => e.mimetype).toList(),
    );
}