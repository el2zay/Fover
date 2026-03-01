import 'dart:developer';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/main.dart';
import 'package:fover/pages/library.dart';
import 'package:fover/src/widgets/blurred_app_bar.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:local_auth/local_auth.dart';

final LocalAuthentication auth = LocalAuthentication();

final List<Map<String, dynamic>> _albums = [
  {
    'title': "Memes",
    'preview': "assets/illustrations/rickroll.png"
  },
  {
    'title': "Memories",
    'preview': "assets/illustrations/pandas.jpg"
  },
  {
    'title': "PS App",
    'preview': "assets/illustrations/mirage.jpg"
  },
  {
    'title': "Landscapes",
    'preview': "assets/illustrations/lebanon.jpg"
  }
];

final List<Map<String, dynamic>> _defaultAlbums = [
  {
    'key': 'videos',
    'title': "Videos",
    'count': 0,
  },
  {
    'key': 'screenshots',
    'title': "Screenshots",
    'count': 0,
  },
  {
    'key': 'favorites',
    'title': "Favorites",
    'count': 0,
  },
  {
    'key': 'hidden',
    'title': "Hidden",
    'count': -1,
  },
  {
    'key': 'recently_deleted',
    'title': "Recently Deleted",
    'count': -1,
  },
];

IconData _iconFor(String key) {
  switch (key) {
    case 'videos':
      return CupertinoIcons.video_camera;
    case 'screenshots':
      return CupertinoIcons.camera_viewfinder;
    case 'favorites':
      return CupertinoIcons.heart;
    case 'hidden':
      return CupertinoIcons.eye_slash;
    case 'recently_deleted':
      return CupertinoIcons.trash;
    default:
      return CupertinoIcons.folder;
  }
}

VoidCallback _onTapFor(String key) {
  switch (key) {
    case 'videos':
      return () => log("Videos tapped");
    case 'screenshots':
      return () => log("Screenshots tapped");
    case 'favorites':
      return () => log("Favorites tapped");
    case 'hidden':
      return () async {
        bool isAuthenticated = await auth.authenticate(
          localizedReason: 'Please authenticate to access hidden photos',
          biometricOnly: true,
        );
        if (isAuthenticated) {
          log("Authenticated successfully.");
        }
    };
    case 'recently_deleted':
      return () => log("Recently Deleted tapped");
    default:
      return () {};
  }
}

List<Map<String, dynamic>> _buildAlbums(List<Map<String, dynamic>> albums) {
  return albums.map((album) {
    return {
      'key': album['key'],
      'icon': _iconFor(album['key']),
      'title': album['title'],
      'count': album['count'],
      'onTap': _onTapFor(album['key']),
    };
  }).toList();
}

// Generated with AI

List<Map<String, dynamic>> _loadAlbums() {
  final saved = (box.get("albumOrder") as List?)
          ?.cast<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      _defaultAlbums;
  return _buildAlbums(saved);
}

final List<Map<String, dynamic>> otherAlbums = _buildAlbums(
  (box.get("albumOrder") as List?)
          ?.cast<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList() ?? _defaultAlbums,
);
// 

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}


class _AlbumsPageState extends State<AlbumsPage> {
  List<Map<String, dynamic>> albums = [];
  bool isUnfolded = true;

  @override
  void initState() {
    super.initState();
    albums = _loadAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BlurredAppBar(
        title: ("Albums"),
        actions: [
          IconButton(
            icon: Icon(CupertinoIcons.add), 
            onPressed: () {
              log("Add Album Tapped");
              showModalBottomSheet(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
                backgroundColor: Colors.black,
                isScrollControlled: true,
                context: context, builder: (context) {
                return NewAlbumSheet();
            });
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height - kToolbarHeight + 30,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "My Albums",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          )
                        ),
                        IconButton(onPressed: () {
                          setState(() {
                            isUnfolded = !isUnfolded;
                          });
                        }, 
                        icon: AnimatedRotation(
                          turns: isUnfolded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(CupertinoIcons.chevron_right, size: 24, color: Colors.white70),
                        ),
                      ),
                      ],
                    ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return SizeTransition(
                      sizeFactor: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: isUnfolded
                    ? GridView(
                      key: const ValueKey('grid'),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1,
                      mainAxisExtent: 160,
                    ),
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: List.generate(4, (index) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(20),
                          image: DecorationImage(
                            image: AssetImage(
                              _albums[index]['preview'],
                            ),    
                            fit: BoxFit.cover,
                          )
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Spacer(),
                              Text(
                                _albums[index]['title'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    })
                  ) : SizedBox.shrink(key: const ValueKey('empty')),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 0, left: 16, right: 16),
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
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ReorganisePage()),
                          );
                          setState(() {
                            albums = _loadAlbums();
                          });
                        }, 
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: albums.length,
                      itemBuilder: (context, index) => ListTile(
                        leading: Icon(albums[index]['icon'], size: 26, color: Colors.blue[600]),
                        title: Text(albums[index]['title'], style: TextStyle(fontSize: 18, color: Colors.blue[600])),
                        trailing: Row(
                          spacing: 8,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          albums[index]['count'] >= 0 ? Text(
                              albums[index]['count'].toString(),
                              style: TextStyle(fontSize: 16, color: Colors.white70),
                            ) : const Icon(CupertinoIcons.lock_fill, size: 16, color: Colors.grey),
                            Icon(CupertinoIcons.chevron_forward, size: 20, color: Colors.white38),
                          ],
                        ),
                        onTap: albums[index]['onTap'],
                      ),
                    ),
                ),
              ],
            ),
          ),
      ),
    );
  }
}

class NewAlbumSheet extends StatefulWidget {
  const NewAlbumSheet({super.key});

  @override
  State<NewAlbumSheet> createState() => _NewAlbumSheetState();
}

class _NewAlbumSheetState extends State<NewAlbumSheet> {
  bool enableCreate = false;
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        leading: Transform.scale(
          scale: 0.8,
          child: Button.iconOnly(
            icon: Icon(Icons.close),
            glassIcon: CNSymbol('xmark', size: 16),
            backgroundColor: Colors.transparent,
            onPressed: () => Navigator.pop(context)
          ),
        ),
        title: Text("New Album", style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          Button(
            label: "Create",
            enabled: enableCreate,
            glassConfig: CNButtonConfig(
              style: CNButtonStyle.prominentGlass,
            ),
            textColor: Colors.blue,
            tint: Colors.blue.withAlpha(230),
            backgroundColor: Colors.transparent,
            onPressed: () {
              log("Create");
            },
          ),
          SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: size.height * 0.01),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                width: size.width * 0.5,
                height: size.height * 0.2,
                child: Icon(CupertinoIcons.photo_fill, size: 30, color: Colors.white24),
              )
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 120),
              child: Button(
                label: "Add photos",
                onPressed: () {
                  showModalBottomSheet(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
                    backgroundColor: Colors.black,
                    isScrollControlled: true,
                    context: context, builder: (context) {
                      return Scaffold(
                        appBar: AppBar(
                          leading: 
                          Transform.scale(
                            scale: 0.9,
                            child: Button.iconOnly(
                                icon: Icon(Icons.close, size: 16),
                                glassIcon: CNSymbol('xmark', size: 16),
                                backgroundColor: Colors.transparent,
                                onPressed: () => Navigator.pop(context)
                            ),
                          ),
                          title: Text("Select photos", style: TextStyle(fontWeight: FontWeight.w500),),
                          actionsPadding: EdgeInsets.only(left: 10),
                          actions: [
                            ValueListenableBuilder<int>(
                              valueListenable: countSelected,
                              builder: (context, value, _) {
                                return Button.iconOnly(
                                  enabled: value > 0,
                            
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(CupertinoIcons.check_mark, size: 14),
                                  glassIcon: CNSymbol('checkmark', size: 14),
                                  tint: Colors.blue,
                                  glassConfig: CNButtonConfig(
                                    style: CNButtonStyle.prominentGlass,

                                  ),
                                  backgroundColor: Colors.blue
                            
                                );
                              }
                            ),
                          ]
                        ),
                        body: LibraryPage(
                          onlySelect: true,
                        ),
                      );
                    }
                  );
                }, 
              )
            ),
            SizedBox(height: 25),
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
              child: TextField(
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  fillColor: Colors.white10,
                  filled: true,
                  hint: Text("Album name", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white38)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() => enableCreate = value.isNotEmpty);
                },
              )
            )
          ],
        ),
      )
    );
  }
}

class ReorganisePage extends StatefulWidget {
  const ReorganisePage({super.key});

  @override
  State<ReorganisePage> createState() => _ReorganiseState();
}

class _ReorganiseState extends State<ReorganisePage> {
    late List<Map<String, dynamic>> albums;

  @override
  void initState() {
    super.initState();
    albums = _loadAlbums();
  }
  
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
              final item = albums.removeAt(oldIndex);
              albums.insert(newIndex, item);
            });

           final toSave = albums.map((a) => {
              'key': a['key'],
              'title': a['title'],
              'count': a['count'],
            }).toList();

            box.put("albumOrder", toSave);
          },
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return ListTile(
              key: ValueKey(album['key']),
              leading: Icon(_iconFor(album['key']), size: 26, color: Colors.blue[600]),
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