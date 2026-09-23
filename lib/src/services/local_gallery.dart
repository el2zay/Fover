import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

class LocalGallery {
  static final ValueNotifier<List<AssetEntity>> assets = ValueNotifier([]);

  static final Map<String, AssetEntity> _byId = {};
  static bool hasAccess = false;
  static bool _initialized = false;
  static Timer? _reloadDebounce;

  static Future<void> init() async {
    if (_initialized) return;

    final state = await PhotoManager.requestPermissionExtend();
    hasAccess = state.hasAccess; 
    if (!hasAccess) return;

    _initialized = true;
    await reload();

    PhotoManager.addChangeCallback(_onChange);
    PhotoManager.startChangeNotify();
  }

  static Future<void> reload() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );
    if (paths.isEmpty) {
      _byId.clear();
      assets.value = [];
      return;
    }

    final all = paths.first;
    final count = await all.assetCountAsync;

    const pageSize = 500;
    final result = <AssetEntity>[];
    for (var start = 0; start < count; start += pageSize) {
      final end = (start + pageSize).clamp(0, count);
      result.addAll(await all.getAssetListRange(start: start, end: end));
    }

    _byId
      ..clear()
      ..addEntries(result.map((a) => MapEntry(a.id, a)));
    assets.value = result;
    log('[local] ${result.length} médias chargés');
  }

  static AssetEntity? get(String id) => _byId[id];


  static void _onChange(MethodCall _) {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(seconds: 1), reload);
  }
}