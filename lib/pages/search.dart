import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/pages/library.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  FocusNode searchFocus = FocusNode();
  TextEditingController searchController = TextEditingController();

  bool _hasSearched = false;

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
      'icon': CupertinoIcons.text_cursor
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
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.only(
                    top: _hasSearched ? 62 : 1202
                  ),
                  child: _hasSearched
                      ? LibraryPage(searchText: _query)
                      : _buildSuggestions(),
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
                        child: searchField(),
                      ),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 15),
        Text("Explore", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        SizedBox(
          height: 190,
          child: GridView.builder(
            padding: EdgeInsets.only(top:10),
            itemCount: _exploreItems.length,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 13/3
            ),
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.all(Radius.circular(15))
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    SizedBox(width: 3),
                    Icon(_exploreItems[index]['icon'], color: Colors.white.withAlpha(200), size: 24),
                    Text(_exploreItems[index]['title'], style: TextStyle(fontSize: 17))
                  ],
                )
              );
            },
          ),
        ),
        Text("Recent Searches", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600))
      ]
    );
  }

  TextField searchField() {
    return TextField(
      controller: searchController,
      focusNode: searchFocus,
      autofocus: true,
      onChanged: (query) {
        setState(() {});
        _onSearch(query);
      },
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 0),
        prefixIcon: Icon(CupertinoIcons.search, color: Colors.white70, size: 18),
        hintText: "Search in Fover",
        hintStyle: TextStyle(color: Colors.white70),
        suffixIcon: searchController.text.isNotEmpty
          ? IconButton(
            icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white54, size: 18),
            onPressed: () {
              searchController.clear();
              _onSearch('');
            },
          ) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        fillColor: Colors.white12,
        filled: true
      ),
    );
  }
}