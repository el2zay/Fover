import 'dart:math';
import 'dart:typed_data';

import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:fover/pages/library.dart';
import 'package:fover/src/models/photo_entry.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/requests.dart';
import 'package:fover/src/widgets/button.dart';

enum SwipeFilter { library, favorites, album, month, year }

class SwipePage extends StatefulWidget {
  final SwipeFilter filter;
  final String? albumName;
  final int? month;
  final int? year;

  const SwipePage({
    super.key,
    this.filter = SwipeFilter.library,
    this.albumName,
    this.month,
    this.year,
  });

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage> {
  List<PhotoEntry> _photos = [];
  List<PhotoEntry> selectedPhotos = [];
  final Map<String, ValueNotifier<Uint8List?>> _imageCache = {};

  final CardSwiperController _swipeController = CardSwiperController();

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  @override
  void dispose() {
    for (final n in _imageCache.values) {
      n.dispose();
    }
    _swipeController.dispose();
    super.dispose();
  }

    void _loadPhotos() {
    List<PhotoEntry> photos;

    switch (widget.filter) {
      case SwipeFilter.library:
        photos = PhotoStore.getAll();
        photos.shuffle();
        break;

      case SwipeFilter.favorites:
        photos = PhotoStore.getAll()
            .where((p) => p.favorite == true)
            .toList()
          ..shuffle();
        break;

      case SwipeFilter.album:
        photos = widget.albumName != null
            ? PhotoStore.getAlbum(widget.albumName!)
            : [];
        break;

      case SwipeFilter.month:
        photos = PhotoStore.getAll().where((p) {
          final date = PhotoStore.getDate(p.path);
          return date.month == widget.month && date.year == widget.year;
        }).toList();
        break;

      case SwipeFilter.year:
        photos = PhotoStore.getAll().where((p) {
          final date = PhotoStore.getDate(p.path);
          return date.year == widget.year;
        }).toList();
        break;
    }

    setState(() => _photos = photos);
    _preloadAhead(0, count: 10);
  }

    void _preloadAhead(int currentIndex, {int count = 5}) {
      for (int i = currentIndex; i < (currentIndex + count).clamp(0, _photos.length); i++) {
        final path = _photos[i].path;
        if (!_imageCache.containsKey(path)) {
          final notifier = ValueNotifier<Uint8List?>(null);
          _imageCache[path] = notifier;
          _loadImageFor(_photos[i], notifier);
        }
      }
    }

  Future<void> _loadImageFor(PhotoEntry photo, ValueNotifier<Uint8List?> notifier) async {
    final cached = LibraryPageState.thumbCache.get(photo.path);
    if (cached != null) {
      notifier.value = cached;
    } else {
      final thumb = await fetchImageBytes(photo.path, photo.mimetype ?? 'image/jpeg');
      if (thumb != null) {
        LibraryPageState.thumbCache.put(photo.path, thumb);
        notifier.value = thumb;
      }
    }

    final full = await fetchFullBytes(photo.path);
    if (full != null) notifier.value = full;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CNPopupMenuButton(
          tint: Theme.of(context).primaryColor,
          buttonStyle: CNButtonStyle.glass,
          shrinkWrap: true,
          buttonLabel: "   Library   ",
          items: [
            CNPopupMenuItem(label: "Library"),
            CNPopupMenuItem(label: "Favorites"),
          ], 
          onSelected: (value) {

          }
        ),
        actions: [
          Button.iconOnly(
            onPressed: () => Navigator.pop(context),
            icon: Icon(CupertinoIcons.check_mark, size: 14),
            glassIcon: CNSymbol('checkmark', size: 14),
            tint: Colors.blue,
            glassConfig: CNButtonConfig(
              style: CNButtonStyle.prominentGlass,
            ),
            backgroundColor: Colors.blue
          )
        ],
      ),
      body: _photos.isEmpty 
        ? Center(child: Text("No photos to swipe on"))
        : CardSwiper(
          controller: _swipeController,
          cardsCount: _photos.length,
          numberOfCardsDisplayed: 1,
          isLoop: false,
          allowedSwipeDirection: AllowedSwipeDirection.only(left: true, right: true),
          onSwipe: (previousIndex, currentIndex, direction) {
            if (direction == CardSwiperDirection.left) {
              selectedPhotos.add(_photos[previousIndex]);
            }
            if (currentIndex != null) _preloadAhead(currentIndex, count: 3);
            return true;
          },

          onEnd: () {
            // TODO Mettre le résumé ici et dans le bouton done
          },

          cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
            final photo = _photos[index];
            final notifier = _imageCache[photo.path];

            if (notifier == null) return Container(color: Colors.grey[900]);

            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: PhotoCard(
                    key: ValueKey(photo.path),
                    notifier: notifier
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  child: AnimatedOpacity(
                    opacity: percentThresholdX > 1 && percentThresholdX < 600 ? 1 : 0,
                    duration: Duration(milliseconds: 150),
                    child: Transform.rotate(
                        angle: -pi / 6,
                        child: Text(
                          'KEEP', 
                          style: TextStyle(
                            color: CupertinoColors.activeGreen, 
                            fontSize: 20, 
                            fontWeight: FontWeight.bold
                            )
                          ),
                      )
                    ),
                ),
                Positioned(
                  top: 30,
                  right: 20,
                  child: AnimatedOpacity(
                    opacity: percentThresholdX > -600 && percentThresholdX < 0 ? 1 : 0,
                    duration: Duration(milliseconds: 150),
                    child: Transform.rotate(
                        angle: pi / 6,
                        child: Text(
                          'DELETE', 
                          style: TextStyle(
                            color: CupertinoColors.systemRed, 
                            fontSize: 20, 
                            fontWeight: FontWeight.bold
                            )
                          ),
                      )
                    ),
                ),
              ]
            );
          },
        ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.05),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 215, 6, 51),
                    Color(0xFFFF025E)
                  ],
                  transform: GradientRotation(30)
                )
              ),
              child: Icon(CupertinoIcons.xmark),
            ),
            SizedBox(width: 20),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 18, 176, 0),
                    Color.fromARGB(255, 34, 211, 15),                    
                  ]
                )
              ),
              child: Icon(CupertinoIcons.checkmark),
            ),
          ],
        ),
      )
    );
  }
  
}

class PhotoCard extends StatelessWidget {
  final ValueNotifier<Uint8List?> notifier;
  const PhotoCard({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Uint8List?>(
      valueListenable: notifier,
      builder: (context, bytes, _) {
        if (bytes == null) {
          return Container(
            color: Colors.grey[900],
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        );
      },
    );
  }
} 