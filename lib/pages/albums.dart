import 'dart:developer';
import 'dart:typed_data';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/main.dart';
import 'package:fover/pages/library.dart';
import 'package:fover/src/models/album_entry.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/widgets/albums_list.dart';
import 'package:fover/src/widgets/blurred_app_bar.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:local_auth/local_auth.dart';

final LocalAuthentication auth = LocalAuthentication();

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}


class _AlbumsPageState extends State<AlbumsPage> {
  List<Map<String, dynamic>> albums = [];
  bool isUnfolded = true;

  static const List<Map<String, dynamic>> _defaultAlbums = [
    {
      'key': 'videos',
      'title': "Videos",
      'count': '',
    },
    {
      'key': 'screenshots',
      'title': "Screenshots",
      'count': '',
    },
    {
      'key': 'favorites',
      'title': "Favorites",
      'count': '',
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

  VoidCallback _onTapFor(String key, BuildContext context) {
    switch (key) {
      case 'videos':
        return () => log("Videos tapped");
      case 'screenshots':
        return () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => LibraryPage(album: Album.screenshots)
            )
          ).then((_) {
            Future.delayed(const Duration(milliseconds: 350), () {
              if (context.mounted) setState(() {});
            });
          });
        };
      case 'favorites':
        return () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => LibraryPage(album: Album.favorites)
            )
          ).then((_) {
            Future.delayed(const Duration(milliseconds: 350), () {
              if (context.mounted) setState(() {});
            });
          });
        };

      case 'hidden':
        return () async {
          try {
            bool isAuthenticated = await auth.authenticate(
              localizedReason: 'Please authenticate to access hidden photos',
              biometricOnly: false,
            );
            if (isAuthenticated) {
              log("Authenticated successfully.");
            } else {
              auth.stopAuthentication();
            }
          } catch (e) {
            log("Authentication failed");
          }
      };

      case 'recently_deleted':
        return () async {
          try {
            bool isAuthenticated = await auth.authenticate(
              localizedReason: 'Please authenticate to access hidden photos',
              biometricOnly: false,
            );
            if (isAuthenticated) {
              log("Authenticated successfully.");
            } else {
              auth.stopAuthentication();
            }
          } catch (e) {
            log("Authentication failed");
        }
      };
      default:
        return () => log("Tapped on $key");
    }
  }

  List<Map<String, dynamic>> _buildAlbums(List<Map<String, dynamic>> albums, BuildContext context) {
    return albums.map((album) {
      return {
        'key': album['key'],
        'icon': _iconFor(album['key']),
        'title': album['title'],
        'count': album['count'],
        'onTap': _onTapFor(album['key'], context),
      };
    }).toList();
  }

  // Generated with AI

  List<Map<String, dynamic>> loadAlbums(BuildContext context) {
    final saved = (box.get("albumOrder") as List?)
            ?.cast<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        _defaultAlbums;
    return _buildAlbums(saved, context);
  }

  // 

  @override
  void initState() {
    super.initState();
    albums = loadAlbums(context);
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = Theme.brightnessOf(context) == Brightness.dark ? Colors.white70 : Colors.black87;

    return Scaffold(
      appBar: BlurredAppBar(
        title: ("Albums"),
        actions: [
          Button.iconOnly(
            icon: Icon(CupertinoIcons.add), 
            glassIcon: CNSymbol('plus', size: 20),
            onPressed: () {
              log("Add Album Tapped");
              showCupertinoSheet(
                context: context, builder: (context) {
                  return NewAlbumSheet();
                }
              ).then((_) {});
            },
          ),
          SizedBox(width: 10),
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
                          child: Icon(CupertinoIcons.chevron_right, size: 24, color: textColor),
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
                    ? AlbumsList(
                        crossAxisCount: 2,
                        spacing: 10,
                        borderRadius: 20,
                        onTap: (album) {
                          Navigator.push(
                            context, 
                            CupertinoPageRoute(
                              builder: (_) => LibraryPage(albumName: album.name)
                            )
                          );
                        },
                        isAlbumsPage: true,
                      ) 
                    : SizedBox.shrink(key: const ValueKey('empty')),
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
                          tint: Theme.of(context).primaryColor,
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ReorganisePage(
                                load: loadAlbums(context),
                                iconFor: _iconFor,
                              )),
                          );
                          setState(() {
                            albums = loadAlbums(context);
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
                            if (albums[index]['count'] == -1)
                              const Icon(CupertinoIcons.lock_fill, size: 16, color: Colors.grey)
                            else if (albums[index]['count'] is String)
                              ValueListenableBuilder(
                                valueListenable: PhotoStore.listenable,
                                builder: (context, box, _) => Text(
                                  albums[index]['key'] == 'favorites' 
                                    ? PhotoStore.favoritesCount.toString()
                                    : albums[index]['key'] == 'videos' 
                                      ?  PhotoStore.videosCount.toString()
                                      : PhotoStore.screenshotsCount.toString(),
                                  style: TextStyle(fontSize: 16, color: textColor),
                                ),
                              )
                            else
                              Text(
                                albums[index]['count'].toString(),
                                style: TextStyle(fontSize: 16, color: textColor),
                              ),
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
  final AlbumEntry? oldAlbum;
  const NewAlbumSheet({super.key, this.oldAlbum});

  @override
  State<NewAlbumSheet> createState() => _NewAlbumSheetState();
}

class _NewAlbumSheetState extends State<NewAlbumSheet> {
  bool enableCreate = false;
  final ValueNotifier<List<String>> selectedPaths = ValueNotifier([]);
  final ValueNotifier<int> countSelected = ValueNotifier(0);
  final ValueNotifier<Uint8List?> coverThumb = ValueNotifier(null);
  late TextEditingController albumNameController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    albumNameController = TextEditingController();
    albumNameController.text = widget.oldAlbum?.name ?? ""; 
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_focusNode);
    });   
  }


  @override
  void dispose() {
    albumNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color primary = Theme.of(context).primaryColor;
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
        title: Text(widget.oldAlbum != null ? "Edit album" : "New Album", style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          Button(
            label: widget.oldAlbum != null ? "Edit" : "Create",
            enabled: (enableCreate && countSelected.value > 0) || widget.oldAlbum != null,
            glassConfig: CNButtonConfig(
              style: CNButtonStyle.prominentGlass,
            ),
            textColor: Colors.blue,
            tint: Colors.blue.withAlpha(230),
            backgroundColor: Colors.transparent,
            onPressed: () {
              if (widget.oldAlbum != null) {
                PhotoStore.renameAlbum(
                  oldName: widget.oldAlbum!.name,
                  newName: albumNameController.text,
                );
              } else {
                PhotoStore.createAlbum(
                  name: albumNameController.text,
                  coverBytes: coverThumb.value
                );
              }

              for (final path in selectedPaths.value) {
                PhotoStore.addToAlbum(path: path, album: albumNameController.text);
              }

              Navigator.pop(context);
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
              child: ValueListenableBuilder<Uint8List?>(
              valueListenable: coverThumb,
              builder: (context, bytes, _) {
                return Container(
                  decoration: BoxDecoration(
                    color: primary.withAlpha(24),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  width: size.width * 0.5,
                  height: size.height * 0.2,
                  clipBehavior: Clip.antiAlias,
                  child: widget.oldAlbum?.coverBytes != null && countSelected.value == 0 
                    ? Image.memory(widget.oldAlbum!.coverBytes!, fit: BoxFit.cover)
                    : bytes != null 
                      ? Image.memory(bytes, fit: BoxFit.cover)
                      : Icon(CupertinoIcons.photo_fill, size: 40, color: primary.withAlpha(100)),
                  );
                }
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 120),
              child: Button(
                label: "Add photos",
                tint: primary,
                onPressed: () {
                  showModalBottomSheet(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
                    backgroundColor: Colors.black,
                    isScrollControlled: true,
                    context: context, 
                    builder: (context) {
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
                          title: Text("Select photos", style: TextStyle(fontWeight: FontWeight.w500)),
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
                          onSelectedChanged: (paths, thumbBytes) {
                            selectedPaths.value = paths;
                            coverThumb.value = thumbBytes;
                            countSelected.value = paths.length;
                          },
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
                controller: albumNameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  filled: true,
                  hint: Text("Album name", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primary.withAlpha(100))),
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
  final List<Map<String, dynamic>> load;
  final Function iconFor;
  const ReorganisePage({super.key, required this.load, required this.iconFor});

  @override
  State<ReorganisePage> createState() => _ReorganiseState();
}

class _ReorganiseState extends State<ReorganisePage> {
    late List<Map<String, dynamic>> albums;

  @override
  void initState() {
    super.initState();
    albums = widget.load;
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
              leading: Icon(widget.iconFor(album['key']), size: 26, color: Colors.blue[600]),
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