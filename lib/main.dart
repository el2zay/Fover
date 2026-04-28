import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:fover/pages/albums.dart';
import 'package:fover/pages/onboarding/first.dart';
import 'package:fover/pages/library.dart';
import 'package:fover/pages/search.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/services/freebox_service.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:fover/src/utils/requests.dart';
import 'package:freebox/freebox.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pull_down_button/pull_down_button.dart'; 

FreeboxClient? client;
bool is26OrNewer =  PlatformVersion.supportsLiquidGlass;
final box = Hive.box('settings');
final ValueNotifier<bool> showTabBar = ValueNotifier(true);
bool isLoggedIn = box.get("appToken") != null || box.get("copypartyUrl") != null;
final ValueNotifier<String> searchQuery = ValueNotifier('');
String? model;
late bool connectedToInternet;
final ValueNotifier<double> tabBarHeight = ValueNotifier(kBottomNavigationBarHeight);

Future<void> initApp() async {
  await PhotoStore.init();

  if (box.get("appToken") != null || box.get("copypartyUrl") != null) {
    connectedToInternet = await CopypartyService.isUp() && await hasInternet();

    if (box.get("appToken") != null) {
      client = FreeboxClient(
        appToken: box.get("appToken"),
        appId: 'fbx.fover',
        apiDomain: box.get("apiDomain"),
        httpsPort: box.get("httpsPort"),
      );
      await client?.authentificate();
    }

    if (box.get("copypartyUrl") != null) {
      CopypartyService.init();
    }

    if (connectedToInternet) {
      await PhotoStore.purgeExpired();
      await syncHive();
      await PhotoStore.existsOnServer();
      if (box.get("appToken") != null) {
        model = await FreeboxService.getFreeboxModel();
      }
      await fetchPhotosDir();
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en', null);
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('searchHistory');

  ExtendedImageGesturePageView;
  clearMemoryImageCache();
  PaintingBinding.instance.imageCache.maximumSize = 50;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 << 20;
  connectedToInternet = await CopypartyService.isUp() && await hasInternet();
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
  final GlobalKey<LibraryPageState> libraryKey = GlobalKey<LibraryPageState>();

  bool get isLoggedIn => box.get("appToken") != null || box.get("copypartyUrl") != null;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [CNTabBarRouteObserver()],
      home: Padding(
        padding: Platform.isAndroid ? EdgeInsets.only(top: 15, left: 5, right: 5) : EdgeInsets.zero,
        // ignore: sort_child_properties_last
        child: Scaffold(
          extendBody: true,
          body: !isLoggedIn
            ? const FirstPage()
            : IndexedStack(
              index: _currentIndex,
              children:  [
                LibraryPage(key: libraryKey, onlySelect: false),
                SafeArea(child: AlbumsPage()),
                SearchPage()
              ],
            ),

          bottomNavigationBar: ValueListenableBuilder(
            valueListenable: showTabBar,
            builder: (context, tabBarVisible, _) {
              final loggedIn = isLoggedIn;
              Widget child;
              if (!loggedIn || !tabBarVisible) {
                child = const SizedBox.shrink(key: ValueKey('empty'));
              } else {
                child = is26OrNewer
                  ? CNTabBar(
                      key: const ValueKey('tabbar'),
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
                      ],
                      currentIndex: _currentIndex,
                      onTap: (i) {
                        if (i == 0 && _currentIndex == 0) {
                          libraryKey.currentState?.scrollToBottom();
                        }
                        setState(() => _currentIndex = i);
                      },
                      searchItem: CNTabBarSearchItem(
                        icon: CNSymbol(
                          'magnifyingglass',
                          color: _currentIndex == 2 ? Colors.blue : null,
                        ),
                        onSearchChanged: (query) {
                          searchQuery.value = query;
                        },
                        onSearchSubmit: (query) {
                          searchQuery.value = query;
                        },
                        onSearchActiveChanged: (isActive) {
                          if (isActive) {
                            setState(() {
                              _currentIndex = 2;
                            });
                          }
                        },
                      ),
                    )
                  : BottomNavigationBar(
                      key: const ValueKey('tabbar'),
                      currentIndex: _currentIndex,
                      onTap: (value) {
                        setState(() {
                          _currentIndex = value;
                        });
                      },
                      items: const [
                        BottomNavigationBarItem(
                            icon: Icon(CupertinoIcons.photo), label: "Library"),
                        BottomNavigationBarItem(
                            icon: Icon(CupertinoIcons.collections), label: "Albums"),
                        BottomNavigationBarItem(
                            icon: Icon(CupertinoIcons.search), label: "Search"),
                      ],
                    );
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: child,
                );
              },
          )
        ),
      ),
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.white,
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
            surfaceTintColor: Colors.white,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
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
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor:  Colors.blue,
          unselectedItemColor: Colors.grey[600]
        ),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(color: Colors.black),
          prefixIconColor: Colors.black87,
          suffixIconColor: Colors.black87,
          fillColor: Colors.black.withAlpha(10),
        ),
        extensions: [
          PullDownButtonTheme(
            itemTheme: PullDownMenuItemTheme(
              destructiveColor: CupertinoColors.destructiveRed,
            ),
            dividerTheme: PullDownMenuDividerTheme(
              dividerColor: Colors.white.withAlpha(30), 
              largeDividerColor: Colors.white.withAlpha(15),
            ),
          ),
        ]
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.white,
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
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: const Color.fromARGB(255, 52, 161, 250),
        ),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(color: Colors.white70),
          prefixIconColor: Colors.white70,
          suffixIconColor: Colors.white54,
          fillColor: Colors.white12,
        ),
        extensions: [
          PullDownButtonTheme(
            itemTheme: PullDownMenuItemTheme(
              destructiveColor: CupertinoColors.destructiveRed,
            ),
            dividerTheme: PullDownMenuDividerTheme(
              dividerColor: Colors.white.withAlpha(30), 
              largeDividerColor: Colors.white.withAlpha(15),
            ),
          ),
        ]
      ),
    );
  }
}
