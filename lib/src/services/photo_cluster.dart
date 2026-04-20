// AI Generated

import 'dart:math' as math;

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:fover/src/models/photo_entry.dart';

class PhotoCluster {
  final List<PhotoEntry> photos;
  final LatLng center;
  final PhotoEntry representative;
  PhotoCluster(this.photos, this.center, this.representative);

  String get id => representative.path;
}

List<PhotoCluster> clusterPhotos(List<PhotoEntry> photos, double zoom) {
  final double threshold = _thresholdForZoom(zoom);
  final List<PhotoCluster> clusters = [];
  final Set<String> assigned = {};

  for (final photo in photos) {
    if (assigned.contains(photo.path)) continue;

    final List<PhotoEntry> group = photos.where((other) {
      if (assigned.contains(other.path)) return false;
      final dLat = (photo.latitude! - other.latitude!).abs();
      final dLng = (photo.longitude! - other.longitude!).abs();
      return dLat < threshold && dLng < threshold;
    }).toList();

    for (final p in group) {
      assigned.add(p.path);
    }

    // ← Représentant = la photo la plus proche du centre géographique du groupe
    final avgLat = group.map((p) => p.latitude!).reduce((a, b) => a + b) / group.length;
    final avgLng = group.map((p) => p.longitude!).reduce((a, b) => a + b) / group.length;

    final representative = group.reduce((a, b) {
      final dA = math.pow(a.latitude! - avgLat, 2) + math.pow(a.longitude! - avgLng, 2);
      final dB = math.pow(b.latitude! - avgLat, 2) + math.pow(b.longitude! - avgLng, 2);
      return dA < dB ? a : b;
    });

    clusters.add(PhotoCluster(group, LatLng(representative.latitude!, representative.longitude!), representative));
  }

  return clusters;
}

double _thresholdForZoom(double zoom) {
  if (zoom < 3)  return 15.0;
  if (zoom < 5)  return 8.0;
  if (zoom < 8)  return 2.0;
  if (zoom < 11) return 0.5;
  if (zoom < 14) return 0.05; 
  return 0.005;
}