import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/src/widgets/blurred_app_bar.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  FocusNode searchFocus = FocusNode();
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BlurredAppBar(
        title: "Search",
        actions: [],
      ),
      body: Padding(
        padding: EdgeInsetsGeometry.symmetric(horizontal: 10, vertical: 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              focusNode: searchFocus,
              autofocus: true,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 0),
                prefixIcon: Icon(CupertinoIcons.search, color: Colors.white70, size: 18),
                hintText: "Search in Fover",
                hintStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.white12,
                filled: true
              ),
            ),
            SizedBox(height: 30),
            Text("Explore", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            SizedBox(
              height: 180,
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
            Text("Recent Searches", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}