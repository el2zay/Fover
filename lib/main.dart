import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:freebox_photos/pages/albums.dart';
import 'package:freebox_photos/pages/first.dart';
import 'package:freebox_photos/pages/library.dart';
import 'package:freebox/freebox.dart';
import 'package:freebox_photos/src/utils/requests.dart';
import 'package:get_storage/get_storage.dart';

FreeboxClient? client;

  void main() async {
    await GetStorage.init();

    if (GetStorage().read("appToken") != null) {
      client = FreeboxClient(
        appToken: GetStorage().read("appToken"),
        appId: 'fbx.freebox_photos',
        apiDomain: GetStorage().read("apiDomain"),
        httpsPort: GetStorage().read("httpsPort"),
      );

      await client?.authentificate();
    }
    fetchPhotosDir();
    runApp(Phoenix(child:const MainApp()));
  }

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (GetStorage().read("appToken") != null) { 
      CNTabBarNative.enable(
        isDark: true,
        selectedIndex: _currentIndex,
        tabs: [
          CNTab(title: 'Photothèque', sfSymbol: CNSymbol('photo.fill.on.rectangle.fill')),
          CNTab(title: 'Albums', sfSymbol: CNSymbol('rectangle.stack.fill')),
          CNTab(title: 'Caméra', sfSymbol: CNSymbol('camera.fill')),
          CNTab(title: 'Recherche', sfSymbol: CNSymbol('magnifyingglass'), isSearchTab: true),
        ],
        onTabSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      );
    } else {
      CNTabBarNative.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: GetStorage().read("appToken") == null
          ? const FirstPage()
          : IndexedStack(
          index: _currentIndex,
          children: const [
            LibraryPage(),
            AlbumsPage(),
            Placeholder(),
            Placeholder(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    CNTabBarNative.disable();
    super.dispose();
  }
}
