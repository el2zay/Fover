import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:cupertino_native_better/cupertino_native.dart' show CNSymbol;
import 'package:flutter/material.dart';
import 'package:fover/src/models/photo_entry.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:geolocator/geolocator.dart';

class PhotoMap extends StatefulWidget {
  final PhotoEntry photo;
  final bool fullscreen;
  const PhotoMap({super.key, required this.photo, this.fullscreen = false});

  @override
  State<PhotoMap> createState() => _PhotoMapState();
}

class _PhotoMapState extends State<PhotoMap> {
  AppleMapController? _mapController;

  Future<void> myLocation() async {
    final position = await Geolocator.getCurrentPosition();
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(position.latitude, position.longitude)
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppleMap(
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          onMapCreated: (controller) => _mapController = controller,
          annotations: { 
            Annotation(
              annotationId: AnnotationId(widget.photo.name),
              position: LatLng(widget.photo.latitude ?? 0, widget.photo.longitude ?? 0)
            ),
          },
          // onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            zoom: 13,
            target: LatLng(widget.photo.latitude ?? 0, widget.photo.longitude ?? 0),
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