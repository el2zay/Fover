
import 'dart:ui';

import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  @override
  void initState() {
    super.initState();
    _imagesFuture = _loadImages();
  }

  Future<List<Uint8List>> _loadImages() async {
    return await Future.wait(
      List.generate(await fetchPhotosDir(), (_) async {
        final bytes = await fetchImageBytes();
        return bytes!;
      })
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
              icon: Icon(CupertinoIcons.settings, color: Colors.white),
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
              label: "Select",
              tint: Colors.white.withAlpha(10),
              glassConfig: const CNButtonConfig(
                style: CNButtonStyle.prominentGlass,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              onPressed: () {},
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
                        final double screenWidth = MediaQuery.of(context).size.width;
                        final RenderBox box = itemContext.findRenderObject() as RenderBox;
                        final Offset position = box.localToGlobal(Offset.zero);

                        final double targetX = position.dx + (box.size.width / 2) - 115;
                        final double clampedX = targetX.clamp(15, screenWidth - 230 - 10);

                        HapticFeedback.mediumImpact();

                        showGeneralDialog(
                          context: context,
                          // barrierColor: Colors.black26,
                          barrierDismissible: true,
                          barrierLabel: '',
                          pageBuilder: (context, animation, secondaryAnimation) {
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewerPage(
                              image: Image.memory(bytes),
                            ),
                          ),
                        );
                      },
                      child: Image.memory(bytes, fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
                );
              },
            ),
          );
          //}
        }
      // )
    // );
  // }
}



