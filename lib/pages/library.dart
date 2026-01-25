
import 'dart:typed_data';
import 'dart:ui';

import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/pages/viewer.dart';
import 'package:fover/src/utils/requests.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
          ),
        ),
        elevation: 0,
        title: Text(
          "Photothèque",
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          CupertinoTheme(
            data: const CupertinoThemeData(
              brightness: Brightness.dark,
            ),
            child: CNButton.icon(
              icon: CNSymbol('settings'),
              tint: Colors.white.withAlpha(10),
              config: const CNButtonConfig(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              onPressed: () {},
            ),
          ),
          SizedBox(width: 5),
          CupertinoTheme(
            data: const CupertinoThemeData(
              brightness: Brightness.dark,
            ),
            child: CNButton(
                label: "Sélect.",
                tint: Colors.white.withAlpha(10),
                config: const CNButtonConfig(
                  style: CNButtonStyle.prominentGlass,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                ),
                onPressed: () {},
              ),
          ),
        ],
        centerTitle: false,
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<int>(
        future: fetchPhotosDir(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            // TODO remplacer par une animation de chargement
            return const Center(child: CircularProgressIndicator());
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: 39,
                itemBuilder: (context, index) {
                  return FutureBuilder<Uint8List>(
                    future: fetchImageBytes().then((value) => value!),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Container(
                          color: Colors.grey[800],
                        );
                      }
                        return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewerPage(
                                image: Image.memory(snapshot.data!)
                              )
                            ),
                          );
                        },
                        child: Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  );
                },
              ),
          );
        },
      ),
    );
  }
}
