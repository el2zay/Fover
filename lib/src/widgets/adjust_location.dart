import 'dart:async';
import 'dart:convert';

import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/src/models/photo_entry.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:http/http.dart' as http;

class AdjustLocation extends StatefulWidget {
  const AdjustLocation({super.key, required this.photo});
  final PhotoEntry photo;

  @override
  State<AdjustLocation> createState() => _AdjustLocationState();
}

class _AdjustLocationState extends State<AdjustLocation> {
  TextEditingController textController = TextEditingController();
  List<Map<String, dynamic>> suggestions = [];
  bool isSearching = false;
  Timer? _debounce;

  Future<void> searchAddress(String query) async {
    if (query.length < 3) {
      setState(() => suggestions = []);
      return;
    }


    try {
      final response = await http.get(
        Uri.parse("https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5"),
        headers: {
          'User-Agent': 'Fover/1.0 (contact@tondomaine.com)',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('Search error: HTTP ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body);
      final features = data['features'] as List;

      setState(() {
        suggestions = features.map((f) {
          final props = f['properties'];
          final coords = f['geometry']['coordinates'];
          return {
            'display': [props['name'], props['city'], props['country']]
                .where((e) => e != null)
                .join(', '),
            'lat': coords[1] as double,
            'lon': coords[0] as double,
          };
        }).toList();
      });
    } on TimeoutException {
      debugPrint('Search timeout');
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }
  @override
  void dispose() {
    _debounce?.cancel();
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? CupertinoColors.secondarySystemBackground.darkColor
          : CupertinoColors.secondarySystemBackground,
      appBar: AppBar(
        centerTitle: true,
        leading: Transform.scale(
          scale: 0.8,
          child: Button.iconOnly(
            icon: Icon(Icons.close),
            glassIcon: CNSymbol('xmark', size: 16),
            backgroundColor: Colors.transparent,
            onPressed: () => Navigator.pop(context)
          ),
        ),
        title: Text("Adjust location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: EdgeInsetsGeometry.all(20),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withAlpha(50),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: textController,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  onChanged: (value) {
                    setState(() {});
                    _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), () {
                        if (!mounted) return;
                        searchAddress(value);
                      });
                  },
                  decoration: InputDecoration(
                    hint: Text(
                      "Enter a location",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[300]!.withAlpha(200),
                      ),
                    ),
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      size: 18,
                    ),
                    suffixIcon: textController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              CupertinoIcons.xmark_circle_fill,
                              size: 18,
                              color: Colors.white.withAlpha(180),
                            ),
                            onPressed: () {
                              textController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: suggestions.map((s) => ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 5),
                  leading: Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle
                    ),
                    child: Icon(CupertinoIcons.map_pin, color: Colors.black),
                  ),
                  title: Text(s['display'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context, {
                      'lat': s['lat'],
                      'lon': s['lon']
                    });
                  },
                )).toList(),
              ),
            ),  
          ],
        ),
      ),
    );
  }
}