import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:fover/pages/albums.dart';
import 'package:fover/pages/first.dart';
import 'package:fover/pages/library.dart';
import 'package:freebox/freebox.dart';
import 'package:fover/src/utils/requests.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:developer';

FreeboxClient? client;

  void main() async {
    await GetStorage.init();
    log(GetStorage().read("appToken").toString());
    if (GetStorage().read("appToken") != null) {
      client = FreeboxClient(
        appToken: GetStorage().read("appToken"),
        appId: 'fbx.fover',
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
          CNTab(title: 'Library', sfSymbol: CNSymbol('photo.fill.on.rectangle.fill')),
          CNTab(title: 'Albums', sfSymbol: CNSymbol('rectangle.stack.fill')),
          CNTab(title: 'Camera', sfSymbol: CNSymbol('camera.fill')),
          CNTab(title: 'Search', sfSymbol: CNSymbol('magnifyingglass'), isSearchTab: true),
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
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
