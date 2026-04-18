import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:cupertino_native_better/cupertino_native.dart' show CNSymbol;
import 'package:flutter/material.dart';
import 'package:fover/src/models/photo_entry.dart';
import 'package:fover/src/services/photo_store.dart';
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
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          onMapCreated: (controller) => _mapController = controller,
          annotations: widget.photo != null ? {
            Annotation(
              annotationId: AnnotationId(widget.photo?.path ?? ""),
              position: LatLng(widget.photo!.latitude!, widget.photo!.longitude!)
            ),
          } : PhotoStore.getGeotagged().map((e) => Annotation(
              annotationId: AnnotationId(e.path),
              position: LatLng(e.latitude!, e.longitude!)
            )).toSet(),

          initialCameraPosition: CameraPosition(
            zoom: 13,
            target: widget.photo != null 
              ? LatLng(widget.photo!.latitude!, widget.photo!.longitude!)
              // : myLocation() ?? const LatLng(48.8584, 2.2945)
              : myLocation() ?? const LatLng(0,0)

          ),
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
}