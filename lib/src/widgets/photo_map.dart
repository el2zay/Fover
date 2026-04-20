import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:cupertino_native_better/cupertino_native.dart' show CNSymbol;
import 'package:flutter/material.dart';
import 'package:fover/pages/viewer.dart';
import 'package:fover/src/models/photo_entry.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/services/photo_cluster.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:geolocator/geolocator.dart';

class PhotoMap extends StatefulWidget {
  final PhotoEntry? photo;
  final bool fullscreen;
  const PhotoMap({super.key, required this.photo, this.fullscreen = false});

  @override
  State<PhotoMap> createState() => _PhotoMapState();
}

class _PhotoMapState extends State<PhotoMap> {
  AppleMapController? _mapController;
  Set<Annotation>? _annotations;
  bool _mapReady = false;
  late LatLng _initialTarget;
  double _currentZoom = 0.0;
  final Map<String, BitmapDescriptor> _iconCache = {};
  Timer? _zoomDebounce;

  @override
  void initState() {
    super.initState();
    _initialTarget = widget.photo != null
      ? LatLng(widget.photo!.latitude!, widget.photo!.longitude!)
      : const LatLng(48.8584, 0.2945);
  }

  LatLng? myLocation() {
    Geolocator.getCurrentPosition().then((position) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(
        LatLng(position.latitude, position.longitude)
      ));
      return LatLng(position.latitude, position.longitude);
    });
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppleMap(
          key: ValueKey('photo_map'),
          annotations: _annotations ?? {},
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          onMapCreated: (controller) { 
            _mapController = controller;
            if (!_mapReady) {
              _mapReady = true;
              _buildAnnotations();
            }
          },
          initialCameraPosition: CameraPosition(
            zoom: 13,
            target: _initialTarget
          ),
          onCameraMove: (position) {
            _zoomDebounce?.cancel();
            _currentZoom = position.zoom;
            _zoomDebounce = Timer(const Duration(milliseconds: 400), () {
              _buildAnnotations();
            });
          },
        ),
        // TODO rendre responsive
        if (widget.fullscreen)...[
          Positioned(
            top: 50,
            left: 16,
            child: Button.iconOnly(
              glassIcon: CNSymbol('xmark', size: 16),
              icon: const Icon(Icons.close, size: 16,),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 50,
            right: 16,
            child: Button.iconOnly(
              glassIcon: CNSymbol('location', size: 16),  
              onPressed: () => myLocation()
            ),
          )
        ]
      ],
    );
  }

  Future<void> _buildAnnotations() async {
    final photos = PhotoStore.getGeotagged();
    final clusters = clusterPhotos(photos, _currentZoom);

    if (mounted) {
      setState(() {
        _annotations = clusters.map((cluster) {
          final cacheKey = '${cluster.photos.first.path}_${(100.0 * pow(1.15, _currentZoom - 2)).clamp(30.0, 150.0).toInt()}';
          return Annotation(
            annotationId: AnnotationId(cluster.id),
            position: cluster.center,
            anchor: const Offset(0.5, 0.5),
            icon: _iconCache[cacheKey] ?? BitmapDescriptor.defaultAnnotation,
            onTap: () => _onClusterTap(cluster),
          );
        }).toSet();
      });
    }

    for (final cluster in clusters) {
      final icon = await _buildClusterIcon(cluster, _currentZoom);
      final cacheKey = '${cluster.photos.first.path}_${(100.0 * pow(1.15, _currentZoom - 2)).clamp(30.0, 150.0).toInt()}';
      
      // Ne mettre à jour que si l'icône n'était pas déjà en cache
      if (!_iconCache.containsKey(cacheKey) && mounted) {
        _iconCache[cacheKey] = icon;
        setState(() {
          _annotations = _annotations?.map((a) {
            if (a.annotationId.value == cluster.id) {
              return a.copyWith(iconParam: icon);
            }
            return a;
          }).toSet();
        });
      }
    }
  }

  Future<BitmapDescriptor> _buildClusterIcon(PhotoCluster cluster, double zoom) async {
    final double size = (100.0 * pow(1.15, zoom - 2)).clamp(30.0, 150.0).toDouble();

    if (cluster.photos.length == 1) {
      return _buildAnnotationIcon(cluster.photos.first, size);
    }

    return _buildClusterBadgeIcon(cluster, size);
  }

  void _onClusterTap(PhotoCluster cluster) {
    if (cluster.photos.length == 1) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ViewerPage(
          mimetype: [cluster.photos.first.mimetype ?? 'image/jpeg'], 
          encodedPaths: [cluster.photos.first.path],
          index: 0, 
          trashMode: false,
          onRefresh: () {}
        )
      ));
    } else {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(cluster.center, _currentZoom + 2)
      );
    }
  }


  // AI Generated
  Future<BitmapDescriptor> _buildClusterBadgeIcon(PhotoCluster cluster, double size) async {
    final double padding = size * 0.04;
    final double cornerRadius = size * 0.13;
    final double badgeSize = size * 0.38;

    final cacheKey = '${cluster.representative.path}_${size.toInt()}_cluster';
    if (_iconCache.containsKey(cacheKey)) return _iconCache[cacheKey]!;

    Uint8List? bytes;
    if (detectBackend() == ServerBackend.copyparty) {
      bytes = await CopypartyService.getThumbnail(cluster.representative.path);
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2, 4, size, size), Radius.circular(cornerRadius)),
      Paint()
        ..color = Colors.black.withAlpha(100)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Fond blanc
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size, size), Radius.circular(cornerRadius)),
      Paint()..color = Colors.white,
    );

    if (bytes != null) {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: size.toInt(), targetHeight: size.toInt());
      final frame = await codec.getNextFrame();
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(padding, padding, size - padding * 2, size - padding * 2),
        Radius.circular(cornerRadius - padding),
      ));
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(padding, padding, size - padding * 2, size - padding * 2),
        image: frame.image,
        fit: BoxFit.cover,
      );
      canvas.restore();
    }

    final badgeX = size - badgeSize * 0.6;
    final badgeY = -badgeSize * 0.4;
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${cluster.photos.length}',
        style: TextStyle(
          color: Colors.white,
          fontSize: badgeSize * 0.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(badgeX - textPainter.width / 2, badgeY + badgeSize / 2 - textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final totalH = size + badgeSize * 0.4;
    final finalImage = await picture.toImage(size.toInt() + badgeSize.toInt(), totalH.toInt());
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return BitmapDescriptor.defaultAnnotation;
    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _buildAnnotationIcon(PhotoEntry photo, double zoom) async {
    try {
      final double size = (zoom * 8).clamp(50.0, 130.0);
      final double padding = size * 0.04;
      final double cornerRadius = size * 0.13;

      final cacheKey = '${photo.path}_${size.toInt()}';
      if (_iconCache.containsKey(cacheKey)) return _iconCache[cacheKey]!;

      Uint8List? bytes;
      if (detectBackend() == ServerBackend.copyparty) {
        bytes = await CopypartyService.getThumbnail(photo.path);
      }

      if (bytes == null) return BitmapDescriptor.defaultAnnotation;

      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: size.toInt(),
        targetHeight: size.toInt(),
      );
      final frame = await codec.getNextFrame();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Ombre
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(2, 4, size, size),
          Radius.circular(cornerRadius),
        ),
        Paint()
          ..color = Colors.black.withAlpha(100)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size, size),
          Radius.circular(cornerRadius),
        ),
        Paint()..color = Colors.white,
      );

      canvas.clipRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(padding, padding, size - padding * 2, size - padding * 2),
          Radius.circular(cornerRadius - padding),
        ),
      );

      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(padding, padding, size - padding * 2, size - padding * 2),
        image: frame.image,
        fit: BoxFit.cover,
      );

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return BitmapDescriptor.defaultAnnotation;

      final descriptor = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
      _iconCache[cacheKey] = descriptor;
      return descriptor;

    } catch (_) {
      return BitmapDescriptor.defaultAnnotation;
    }
  }
  //

}