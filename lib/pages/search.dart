import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fover/pages/library.dart';
import 'package:fover/src/widgets/photo_map.dart';
import 'package:hive_ce/hive.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  FocusNode searchFocus = FocusNode();
  TextEditingController searchController = TextEditingController();
  bool _hasSearched = false;
  final historyBox = Hive.box('searchHistory');
  final _displayController = TextEditingController();

  static const List<Map<String, dynamic>> _exploreItems = [
    {
      'key': 'videos',
      'title': 'Videos',
      'icon' : CupertinoIcons.video_camera
    },
    {
      'key' : 'thisMonth',
      'title': 'This month',
      'icon': CupertinoIcons.calendar
    },
    {
      'key': 'favorites',
      'title': 'Favorites',
      'icon': CupertinoIcons.heart,
    },
    {
      'key': 'detectedText',
      'title': 'Detected text',
      'icon': CupertinoIcons.textformat
    },
    {
      'key': 'screenshots',
      'title': 'Screenshots',
      'icon': CupertinoIcons.camera_viewfinder
    },
    {
      'key': 'map',
      'title': 'Map',
      'icon': CupertinoIcons.map
    },
  ];

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(searchFocus);
    });
  }

  @override
  void dispose() {
    searchFocus.dispose();
    searchController.dispose();
    _displayController.dispose();
    _query = '';
    super.dispose();
}

  String _query = '';

  void _onSearch(String query) {
    final cleaned = query.trim();

    setState(() {
      _query = cleaned;
      _hasSearched = cleaned.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: EdgeInsets.only(
                  top: _hasSearched ? 62 : 120
                ),
                child: _hasSearched
                  ? LibraryPage(searchText: _query)
                  : Padding(
                    padding: EdgeInsetsGeometry.all(12),
                    child: _buildSuggestions(),
                  ),
              ),
            ),
            Positioned(
              top: _hasSearched ?  -40 : 0,
              bottom: 0,
              left: 10,
              right: 10,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(
                  0,
                  _hasSearched ? -18 : 0,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      opacity: _hasSearched ? 0 : 1,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        offset: _hasSearched ? const Offset(0, -0.35) : Offset.zero,
                        child: const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Search',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      margin: EdgeInsets.only(top: _hasSearched ? 0 : 4),
                      child: searchField()
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView(
      children: [
        SizedBox(height: 15),
        Text("Explore", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        SizedBox(
          height: ((_exploreItems.length / 2).ceil() * 44) + 
                  ((_exploreItems.length / 2).ceil() - 1) * 8 + 50,
          child: GridView.builder(
            padding: EdgeInsets.only(top: 10),
            itemCount: _exploreItems.length,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 13/3,
              mainAxisExtent: 44
            ),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  _displayController.clear();
                  searchController.clear();
                  if (_exploreItems[index]['key'] == "map") {
                    showModalBottomSheet(
                      isDismissible: false,
                      enableDrag: false,
                      isScrollControlled: true,
                      context: context, 
                      builder: (context) {
                        return PhotoMap(photo: null, fullscreen: true);
                      }
                    );
                  } else {
                    searchController.text = "has:${_exploreItems[index]['key']}";
                    print(searchController.text);
                    _onSearch("has:${_exploreItems[index]['key']}");
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.brightnessOf(context) == Brightness.light ? Colors.grey.withAlpha(20) : Colors.white10,
                    borderRadius: BorderRadius.all(Radius.circular(15))
                  ),
                  child: Row(
                    spacing: 8,
                    children: [
                      SizedBox(width: 3),
                      Icon(_exploreItems[index]['icon'], color: Theme.of(context).primaryColor.withAlpha(200), size: 24),
                      Text(_exploreItems[index]['title'], style: TextStyle(fontSize: 17))
                    ],
                  )
                ),
              );
            },
          ),
        ),
        if (historyBox.isNotEmpty)...[
          Text("Recent Searches", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          SizedBox(height: 5),
          ...historyBox.values.toList().reversed.map((item) => ListTile(
            title: Text(item, style: TextStyle(color:  Theme.of(context).primaryColor.withAlpha(200), fontSize: 20, fontWeight: FontWeight.w500)),
            dense: true,
            onTap: () {
              _displayController.clear();
              searchController.text = item;
              _onSearch(item);
            }
          ))
        ]
      ]
    );
  }

  Widget searchField() {
    final text = searchController.text;

    final activeItem = _exploreItems.firstWhere(
      (item) => text.startsWith('has:${item['key']}'),
      orElse: () => {},
    );

    final hasToken = activeItem.isNotEmpty;
    final token = hasToken ? 'has:${activeItem['key']}' : '';

    return Focus(
      onKeyEvent: (node, event) {
        if (hasToken &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _displayController.text.isEmpty) {
          searchController.clear();
          _displayController.clear();
          _onSearch('');
          setState(() {});
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: hasToken ? _displayController : searchController,
        focusNode: searchFocus,
        autofocus: true,
        autocorrect: false,
        onChanged: (query) {
          if (hasToken) {
            final full = '$token $query'.trimRight();
            searchController.value = searchController.value.copyWith(text: full);
            _onSearch(full);
          } else {
            _onSearch(query);
          }
          setState(() {});
        },
        onSubmitted: (value) {
          if (value.startsWith("has:")) return;
          final cleaned = value.trim();
          if (cleaned.isNotEmpty) {
            final existing = historyBox.values.toList();
            final dupIndex = existing.indexWhere((e) => e.toLowerCase() == cleaned.toLowerCase());
            if (dupIndex != -1) historyBox.deleteAt(dupIndex);

            while (historyBox.length >= 8) {
              historyBox.deleteAt(0);
            }

            historyBox.add(cleaned);
          }
        },
        decoration: InputDecoration(
          hintText: !hasToken ?  "Search in Fover" : null,
          prefixIcon: Icon(
            CupertinoIcons.search,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            size: 18,
          ),
          prefix: hasToken
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      activeItem['title'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).primaryColor.withAlpha(200),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                ],
              )
            : null,
          suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
              icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 18),
              onPressed: () {
                searchController.clear();
                _onSearch('');
              },
            ) : null,

            // Border en cercle tout autour 
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: true,
          fillColor: Colors.white.withAlpha(20)
        ),
      ),
    );
  }
}