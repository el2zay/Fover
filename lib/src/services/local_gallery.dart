import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fover/src/models/photo_entry.dart';
import 'package:fover/src/services/auto_backup.dart';
import 'package:fover/src/services/photo_store.dart';
import 'package:hive_ce/hive.dart';
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
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(needTitle: true),
        videoOption: const FilterOption(needTitle: true),
      ),
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
    _reloadDebounce = Timer(const Duration(seconds: 1), () async {
      await reload();
      AutoBackup.run();
    });
  }
  
}

class LocalLinks {
  static Box<String> get _box => Hive.box<String>('local_links');
  static String? serverPathOf(String assetId) => _box.get(assetId);
  static Set<String> assetIds() => _box.keys.cast<String>().toSet();

  static Future<void> link(String assetId, String serverPath) =>
      _box.put(assetId, serverPath);

    static Future<void> autoMatch() async {
    final linked = assetIds();
    final serverByName = <String, List<PhotoEntry>>{};
    for (final e in PhotoStore.getAll()) {
      serverByName.putIfAbsent(e.name.toLowerCase(), () => []).add(e);
    }

    for (final asset in LocalGallery.assets.value) {
      if (linked.contains(asset.id)) continue;
      final title = asset.title?.toLowerCase();
      if (title == null || title.isEmpty) continue;

      final candidates = serverByName[title] ?? const <PhotoEntry>[];
      for (final e in candidates) {
        if (e.date.difference(asset.createDateTime).abs() < const Duration(minutes: 1)) {
          await link(asset.id, e.path);
          break;
        }
      }
    }
  }
}