import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/material.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      appBar: AppBar(
          title: Text("Photothèque", style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
          actions: [
            CNButton.icon(
              icon: CNSymbol('settings'), 
              tint: Colors.white.withAlpha(10),
                config: const CNButtonConfig(
                  style: CNButtonStyle.prominentGlass,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                ),
              onPressed: () {},
            ),
            SizedBox(width: 5),
            CNButton(
              label: "Sélect.",
              tint: Colors.white.withAlpha(10),
                config: const CNButtonConfig(
                  style: CNButtonStyle.prominentGlass,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                ),
              onPressed: () {},
            ),
          ],
          centerTitle: false,
          backgroundColor: Colors.transparent,
      ),
      backgroundColor: Colors.black,
      body: Center(child: Text('Library Page')));
  }
}
