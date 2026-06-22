import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/pages/settings/swipe.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:fover/src/utils/requests.dart';

class DateList extends StatelessWidget {
  final int? filterDate;

  const DateList({
    super.key,
    this.filterDate
  });

  @override
  Widget build(BuildContext context) {
    final albums = filterDate == 0 
      ? PhotoStore.getAvailableYears() 
      : PhotoStore.getAvailableMonths();
      
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return GestureDetector(
            onTap: () {
              print("Tapped on album ${album.toString()}");
              print("Filter date: $filterDate");
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => SwipePage(
                    filter: filterDate == 0 ? SwipeFilter.year : SwipeFilter.month,
                    month: album.month,
                    year: album.year,
                  )
                )
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.grey[900]
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FutureBuilder<Uint8List?>(
                      future: () async {
                        final path = PhotoStore.getFirstPhotoOf(album);
                        if (path == null) return null;
                        return fetchImageBytes(path, 'image/jpeg');
                      }(),
                      builder: (context, snapshot) {
                        final bytes = snapshot.data;
                        if (bytes == null) {
                          return const Center(child: CupertinoActivityIndicator());
                        }

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        );
                      },
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: const [0.0, 0.6],
                          colors: [
                            Colors.black.withAlpha(150),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsGeometry.only(bottom: 10, left: 15, right: 30),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          formatDate(album.toString(), yearsOnly: filterDate == 0),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold
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
}