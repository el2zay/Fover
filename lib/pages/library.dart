import 'dart:developer';

import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fover/main.dart';
import 'package:fover/pages/viewer.dart';
import 'package:fover/src/utils/requests.dart';
import 'package:fover/src/widgets/blurred_app_bar.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:fover/src/widgets/context_menu.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final Future<List<Uint8List>> _imagesFuture;
  bool selectedMode = false;
  List<int> selectedImages = [];

  @override
  void initState() {
    super.initState();
    _imagesFuture = _loadImages();
  }

  Future<List<Uint8List>> _loadImages() async {
    return await Future.wait(
      List.generate(
        await fetchPhotosDir(),
        (_) async {
          final bytes = await fetchImageBytes();
          return bytes!;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: BlurredAppBar(
        title: "Library",
        actions: [
          CupertinoTheme(
            data: const CupertinoThemeData(
              brightness: Brightness.dark,
            ),
            child: Button.iconOnly(
              icon: const Icon(CupertinoIcons.settings, color: Colors.white),
              glassIcon: CNSymbol('settings'),
              tint: Colors.white.withAlpha(10),
              glassConfig: const CNButtonConfig(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 5),
          CupertinoTheme(
            data: const CupertinoThemeData(
              brightness: Brightness.dark,
            ),
            child: Button(
              label: selectedMode ? "Cancel" : "Select",
              tint: Colors.white.withAlpha(10),
              glassConfig: const CNButtonConfig(
                style: CNButtonStyle.prominentGlass,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              onPressed: () {
                setState(() {
                  selectedMode = !selectedMode;
                  selectedImages.clear();
                  showTabBar.value = false;
                });
              },
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Uint8List>>(
        future: _imagesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            // TODO remplacer par une animation de chargement
            return const Center(child: CircularProgressIndicator());
          } 

          final images = snapshot.data!;
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
          log("Images $images");
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final bytes = images[index];

                return Builder(
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
                        if (selectedMode) {
                          setState(() {
                            if (selectedImages.contains(index)) {
                              selectedImages.remove(index);
                            } else {
                              selectedImages.add(index);
                            }
                          });
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewerPage(
                                image: Image.memory(bytes),
                              ),
                            ),
                          );
                        }
                      },
                      child: Stack(
                        children: [
                          Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity, opacity: selectedMode && selectedImages.contains(index) ? const AlwaysStoppedAnimation(0.8) : const AlwaysStoppedAnimation(1.0),),
                          if (selectedMode && selectedImages.contains(index))
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
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
