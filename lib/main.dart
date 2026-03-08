import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:fover/pages/albums.dart';
import 'package:fover/pages/first.dart';
import 'package:fover/pages/library.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:freebox/freebox.dart';
import 'package:fover/src/utils/requests.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_kit/media_kit.dart'; 

FreeboxClient? client;
bool is26OrNewer =  PlatformVersion.supportsLiquidGlass;
final box = Hive.box('settings');
final ValueNotifier<bool> showTabBar = ValueNotifier(false);
late String? model;
late bool connectedToInternet;

Future<void> initApp() async {
  await PhotoStore.init();

  if (box.get("appToken") != null) {
    client = FreeboxClient(
      appToken: box.get("appToken"),
      appId: 'fbx.fover',
      apiDomain: box.get("apiDomain"),
      httpsPort: box.get("httpsPort"),
    );

    await client?.authentificate();
    showTabBar.value = true;

    if (connectedToInternet) {
      await PhotoStore.purgeExpired(client!);
      await PhotoStore.existsOnServer();
      model = await getFreeboxModel();
      fetchPhotosDir();
    }
    
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await initializeDateFormatting('en', null);
  await Hive.initFlutter();
  Hive.openBox('settings');

  connectedToInternet = await hasInternet();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await initApp();
  
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
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Padding(
        padding: Platform.isAndroid ? EdgeInsets.only(top: 15, left: 5, right: 5) : EdgeInsets.zero,
        child: Scaffold(
          extendBody: true,
          body: box.get("appToken") == null
            ? const FirstPage()
            : IndexedStack(
            index: _currentIndex,
            children: const [
              LibraryPage(onlySelect: false),
              AlbumsPage(),
              Placeholder(),
            ],
          ),
          bottomNavigationBar: (true) ?
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
                    BottomNavigationBarItem(icon: Icon(CupertinoIcons.search), label: "Search"),
                  ]
                ) 
              ) 
            ) : CNTabBar(
              tint: Colors.blue,
              iconSize: 18,
              items: [
                CNTabBarItem(
                  label: 'Library',
                  icon: CNSymbol('photo.fill.on.rectangle.fill'),
                ),
                CNTabBarItem(
                  label: 'Albums',
                  icon: CNSymbol('rectangle.stack.fill'),
                ),
                CNTabBarItem(
                  label: 'Search',
                  icon: CNSymbol('magnifyingglass'),
                ),
              ],
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              // searchItem: CNTabBarSearchItem(
              //   placeholder: 'Search',
              //   automaticallyActivatesSearch: false,
              //   onSearchChanged: (query) {
              //   },
              //   onSearchSubmit: (query) {
              //   },
              //   onSearchActiveChanged: (isActive) {
              //   },
              //   style: const CNTabBarSearchStyle(
              //     iconSize: 20,
              //     animationDuration: Duration(milliseconds: 400),
              //   ),
              // ),
            )
        ),
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
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            overlayColor: WidgetStatePropertyAll(Colors.transparent)
          )
        )
      ),
    );
  }
}
