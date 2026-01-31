import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fover/src/widgets/blurred_app_bar.dart';
import 'package:fover/src/widgets/button.dart';

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

final List<Map<String, dynamic>> otherAlbums = [
  {
    'key': 'videos',
    'icon': CupertinoIcons.video_camera,
    'title': "Videos",
    'onTap': () {},
    'count': 0,
  },
  {
    'key': 'screenshots',
    'icon': CupertinoIcons.camera_viewfinder, 
    'title': "Screenshots",
    'onTap': () {},
    'count': 0,
  },
  {
    'key': 'favorites',
    'icon': CupertinoIcons.heart,
    'title': "Favorites",
    'onTap': () {},
    'count': 0,
  },
  {
    'key': 'hidden',
    'icon': CupertinoIcons.eye_slash,
    'title': "Hidden",
    'onTap': () {},
    'count': -1,
  },
  {
    'key': 'recently_deleted',
    'icon': CupertinoIcons.trash,
    'title': "Recently Deleted",
    'onTap': () {},
    'count': -1,
  },
];  

class _AlbumsPageState extends State<AlbumsPage> {
  bool isReordering = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BlurredAppBar(
        title: ("Albums"),
        actions: [],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  
                  Text(
                    "Utilities",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    )
                  ),
                  Button(
                    label: "Reorder",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ReorganisePage()),
                    );
                  }, 
                  )
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: otherAlbums.length,
                itemBuilder: (context, index) =>
              
              ListTile(
                  leading: Icon(otherAlbums[index]['icon'], size: 26, color: Colors.blue[600]),
                  title: Text(otherAlbums[index]['title'], style: TextStyle(fontSize: 18, color: Colors.blue[600])),
                  trailing: Row(
                    spacing: 8,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    otherAlbums[index]['count'] >= 0 ? Text(
                        otherAlbums[index]['count'].toString(),
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ) : const Icon(CupertinoIcons.lock_fill, size: 16, color: Colors.grey),
                      Icon(CupertinoIcons.chevron_forward, size: 20, color: Colors.white38),
                    ],
                  ),
                  onTap: otherAlbums[index]['onTap'],
                ),
              ),
          ),
        ],
      ),
    );
  }
}

class ReorganisePage extends StatefulWidget {
  const ReorganisePage({super.key});

  @override
  State<ReorganisePage> createState() => _ReorganiseState();
}

class _ReorganiseState extends State<ReorganisePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Reorganise Albums", style: TextStyle(fontWeight: FontWeight.w700)), actions: []),
      body: Padding(
        padding: const EdgeInsets.all(16), 
        child: ReorderableListView.builder(
          physics: NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = otherAlbums.removeAt(oldIndex);
              otherAlbums.insert(newIndex, item);
            });
          },
          itemCount: otherAlbums.length,
          itemBuilder: (context, index) {
            final album = otherAlbums[index];
            return ListTile(
              key: ValueKey(album['key']),
              leading: Icon(album['icon'], size: 26, color: Colors.blue[600]),
              title: Text(album['title'], style: TextStyle(fontSize: 18, color: Colors.blue[600])),
              trailing: ReorderableDragStartListener(
                index: index,
                child: Icon(CupertinoIcons.bars, color: Colors.grey),
              ),
              onTap: album['onTap'],
            );
          },
        ),
      )
    );
  }
}