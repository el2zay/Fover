import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/src/models/album_entry.dart';
import 'package:hive_ce_flutter/adapters.dart';


class AlbumsList extends StatelessWidget {
  final int crossAxisCount;
  final double spacing;
  final double borderRadius;
  final Function(AlbumEntry album)? onTap;
  final bool isAlbumsPage;

  const AlbumsList({
    super.key,
    this.crossAxisCount = 3,
    this.spacing = 10,
    this.borderRadius = 20,
    this.onTap,
    this.isAlbumsPage = false
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<AlbumEntry>("albums").listenable(), 
      builder: (context, Box<AlbumEntry> box, _) {
        final albums = box.values.toList();
        if (albums.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.collections_solid, color: CupertinoColors.systemGrey, size: isAlbumsPage ? 30 :  45),
                SizedBox(height: isAlbumsPage ? 10 : 30),
                Text(
                  "You have not added any albums to your photo library.",
                  style: TextStyle(
                    fontSize: isAlbumsPage ? 16 : 20, 
                    fontWeight: FontWeight.normal
                  ),
                  textAlign: TextAlign.center
                )
              ],
            ),
          );
        }
    
        return GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing),
          shrinkWrap: true,
          physics: isAlbumsPage ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: isAlbumsPage ? 160 : null
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                onTap?.call(album);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  color: Colors.grey[900]
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      album.coverBytes != null 
                        ? Image.memory(
                            album.coverBytes!,
                            fit: BoxFit.cover,
                          )
                        : const Icon(CupertinoIcons.photo_fill, size: 40),

                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            stops: const [0.0, 0.6],
                            colors: [
                              Colors.black.withAlpha(190),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsGeometry.only(top: 15, bottom: 15, left: 15, right: 30),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            album.name, 
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }
}