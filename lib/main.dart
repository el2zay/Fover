import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:fover/pages/albums.dart';
import 'package:fover/pages/camera.dart';
import 'package:fover/pages/first.dart';
import 'package:fover/pages/library.dart';
import 'package:freebox/freebox.dart';
import 'package:fover/src/utils/requests.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:developer';

FreeboxClient? client;
bool is26OrNewer = false;
final ValueNotifier<bool> showTabBar = ValueNotifier(true);

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
    if (GetStorage().read("appToken") != null && showTabBar.value) { 
      final versionString = Platform.operatingSystemVersion;
      final match = RegExp(r'Version (\d+)\.').firstMatch(versionString);
      is26OrNewer = (int.tryParse(match?.group(1) ?? '') ?? 0) >= 26;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        extendBody: true,
        // TODO remmettre == null!!!!
        body: GetStorage().read("appToken") != null
          ? const FirstPage()
          : IndexedStack(
          index: _currentIndex,
          children: const [
            LibraryPage(),
            AlbumsPage(),
            CameraPage(),
            Placeholder(),
          ],
        ),
        bottomNavigationBar: (!is26OrNewer) ?
         
         Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.transparent,
                spreadRadius: 2,
                blurRadius: 5,
                offset: Offset(0, 3),
              )
            ]
          ),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: BottomNavigationBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              fixedColor: const Color.fromARGB(255, 52, 161, 250),
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 13,
              unselectedFontSize: 13,
              currentIndex: _currentIndex,
              onTap: (value) {
                setState(() {
                  _currentIndex = value;
                });
              },
              items: [
                BottomNavigationBarItem(icon: Icon(CupertinoIcons.photo), label: "Library"),
                BottomNavigationBarItem(icon: Icon(CupertinoIcons.collections), label: "Albums"),
                BottomNavigationBarItem(icon: Icon(CupertinoIcons.camera), label: "Camera"),
                BottomNavigationBarItem(icon: Icon(CupertinoIcons.search), label: "Search"),
              ]
            ) 
          ) 
        ) : null,
      ),
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(primary: Colors.white),
        scaffoldBackgroundColor: Colors.black,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ElevatedButton.styleFrom(
            surfaceTintColor: Colors.black,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: CupertinoColors.activeBlue,
        )
      ),
    );
  }

  @override
  void dispose() {
    CNTabBarNative.disable();
    super.dispose();
  }
}
