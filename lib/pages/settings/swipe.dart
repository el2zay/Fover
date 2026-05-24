import 'dart:math';
import 'dart:typed_data';

import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:fover/main.dart';
import 'package:fover/pages/library.dart';
import 'package:fover/src/models/photo_entry.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/common_utils.dart' show formatSize;
import 'package:fover/src/utils/requests.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:fover/src/widgets/dialog.dart';

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
        // TODO lorsque l'on clique sur le trailing, afficher un avertissement.
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
            enabled: selectedPhotos.isNotEmpty,
            icon: Icon(CupertinoIcons.check_mark, size: 14),
            glassIcon: CNSymbol('checkmark', size: 14),
            glassConfig: CNButtonConfig(
              style: CNButtonStyle.prominentGlass,
            ),
            tint: Colors.blue,
            backgroundColor: Colors.blue,
            onPressed: () => Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (_) => ReviewPage(photos: selectedPhotos))
            ),
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
              setState(() {
                selectedPhotos.add(_photos[previousIndex]);
              });
            }
            if (currentIndex != null) _preloadAhead(currentIndex, count: 3);
            return true;
          },
          onUndo: (currentIndex, previousIndex, _) {
            if (currentIndex != null) {
              setState(() {
                selectedPhotos.remove(_photos[currentIndex]);
              });
            }

            return true;
          },
          onEnd: () {
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (_) => ReviewPage(photos: selectedPhotos))
            );
          },

          cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
            final photo = _photos[index];
            final notifier = _imageCache[photo.path];

            if (notifier == null) return Container(color: Colors.grey[900]);

            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(0),
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
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _swipeController.swipe(CardSwiperDirection.left),
                  child: Container(
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
                ),
                SizedBox(width: 20),
                GestureDetector(
                  onTap: () => _swipeController.swipe(CardSwiperDirection.right),
                  child: Container(
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
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              right: 50,
              child: IconButton(
                icon: Icon(Icons.history, size: 25),
                onPressed: () {
                  _swipeController.undo();
                },
              )
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
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }
}


class ReviewPage extends StatefulWidget {
  final List<PhotoEntry> photos;
  const ReviewPage({super.key, required this.photos});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool isDone = false;
  int totalSize = 0;
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return !isDone ? Scaffold(
      appBar: AppBar(
        title: Text("Review", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [
          Button.iconOnly(
            icon: Icon(CupertinoIcons.check_mark, size: 14),
            glassIcon: CNSymbol('checkmark', size: 14),
            glassConfig: CNButtonConfig(
              style: CNButtonStyle.prominentGlass,
            ),
            tint: Colors.blue,
            backgroundColor: Colors.blue,
            onPressed: () => showGeneralDialog(
              barrierDismissible: false,
              context: context,
              pageBuilder: (context, animation, secondaryAnimation) {
                return MyDialog(
                  content: "These images will be permanently deleted from your server. This action cannot be undone.",
                  principalButton: TextButton(
                    child: Text("Delete", style: TextStyle(fontSize: 16, color: CupertinoColors.destructiveRed)),
                    onPressed: () async {
                      for (final photo in widget.photos) {
                        totalSize += photo.size;
                      }

                      box.put('totalCleanedItems', (box.get('totalCleanedItems', defaultValue: 0) ?? 0) + widget.photos.length);
                      box.put('totalCleanedSize', (box.get('totalCleanedSize', defaultValue: 0) ?? 0) + totalSize);

                      setState(() => isDone = true);
                      Navigator.pop(context);
                      for (final photo in widget.photos) {
                        await PhotoStore.hardDelete(photo.path);
                      }
                    }
                  ),
                );
              }
            )
          ),
        ],
      ),
      body: LibraryPage(
        photos: widget.photos,
        album: Album.custom,
      )
    ) : Scaffold(
        backgroundColor: Colors.indigo[600],
        appBar: AppBar(
          backgroundColor: Colors.indigo[900],
          automaticallyImplyLeading: false,
          toolbarHeight: height * 0.15,
          title: Text("You did a great job!", 
          style: TextStyle(fontSize: width * 0.1, fontWeight: FontWeight.w600)
          )
        ),
      body: done()
    );
  }

  Widget done() {
    final height = MediaQuery.of(context).size.height;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(0.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                color: Colors.indigo[800],
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                    SizedBox(height: height * 0.025),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium?.color),
                        children: [
                          TextSpan(text: "${widget.photos.length} photos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                          TextSpan(text: " deleted", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                        ]
                      )
                    ),
                    SizedBox(height: height * 0.03),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium?.color),
                        children: [
                          TextSpan(text: formatSize(totalSize), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                          TextSpan(text: " deleted", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                        ]
                      )
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("In total", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                    SizedBox(height: height * 0.025),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium?.color),
                        children: [
                          TextSpan(text: "${box.get('totalCleanedItems')} photos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                          TextSpan(text: " deleted", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                        ]
                      )
                    ),
                    SizedBox(height: height * 0.03),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium?.color),
                        children: [
                          TextSpan(text: formatSize(box.get('totalCleanedSize') ?? 0), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                          TextSpan(text: " deleted", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                        ]
                      )
                    ),
                  ],
                ),
              ),
            ]
          ),
        ),
        Spacer(),
        SafeArea(
          child: ElevatedButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Color.fromARGB(255, 15, 146, 129)),
              foregroundColor: WidgetStateProperty.all(Colors.white),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)
                )
              ),
              padding: WidgetStateProperty.all(
                EdgeInsets.symmetric(horizontal: 80, vertical: 20)
              )
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (_) => LibraryPage())
              );
            },
            child: Text("Back to the library", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

}