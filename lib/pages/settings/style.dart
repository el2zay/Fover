import 'dart:io';

import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:fover/main.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:ios_color_picker/show_ios_color_picker.dart';

class StylePage extends StatefulWidget {
  const StylePage({super.key});

  @override
  State<StylePage> createState() => _StylePageState();
}

class _StylePageState extends State<StylePage> {
  int navBar = box.get("navBarStyle");
  final _iosColorPickerController = IOSColorPickerController();
  Color _currentColor = box.get("primaryColor");

  @override
  void dispose() {
    _iosColorPickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 60,
        leading: Transform.scale(
          scale: 0.7,
          child: Button.iconOnly(
            icon: Icon(CupertinoIcons.chevron_left),
            glassIcon: CNSymbol('chevron.left', size: 20),
            backgroundColor: Colors.transparent,
            onPressed: () {
              box.put("navBarStyle", navBar);
              Phoenix.rebirth(context);
            }
          )
        ),
        title: Text("Style", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("GENERAL", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Theme.of(context).primaryColor.withAlpha(80))),
              SizedBox(height: 10),
              Container(
                margin: EdgeInsets.all(10),
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(20)
                ),
                child: ListView(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    ListTile(
                      title: Text("Enable Liquid Glass", style: TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Transform.scale(
                        scale: 0.9,
                          child: CNSwitch(
                          value: box.get('liquidGlass', defaultValue: true),
                          color: CupertinoColors.activeGreen,
                          onChanged: (value) {
                            box.put('offlineMode', value);
                            setState(() {});
                          }
                        ),
                      ),
                    ),
                    Divider(height: 1.5, thickness: 2, color: Theme.of(context).primaryColor.withAlpha(20)),
                    ListTile(
                      title: Text("Primary color", style: TextStyle(fontWeight: FontWeight.w500)),
                      trailing: GestureDetector(
                        onTap: () {
                          _iosColorPickerController.showNativeIosColorPicker(
                            startingColor: _currentColor,
                            onColorChanged: (color) {
                              setState(() => _currentColor = color);
                              box.put("primaryColor", color);
                            }
                          );
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _currentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).primaryColor.withAlpha(50), width: 2)
                          ),
                        ),
                      ),
                    ),
                  ]
                )
              ),
              SizedBox(height: 30),
              Text("NAVIGATION BAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Theme.of(context).primaryColor.withAlpha(80))),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => navBar = 0);
                    },
                    child: Column(
                      children: [
                        Image.asset("assets/illustrations/style/fover_nav_dark.png", width: MediaQuery.of(context).size.width * 0.45),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                          decoration: BoxDecoration(
                            color: navBar == 0
                              ? Colors.lightBlue[700]
                              : null,
                            borderRadius: BorderRadius.circular(30)
                          ),
                          child: Text(
                            "Fover", 
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)
                          )
                        ),
                      ],
                    )
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => navBar = 1);
                    },
                    child: Column(
                      children: [
                        Image.asset("assets/illustrations/style/cupertino_nav_dark.png", width: MediaQuery.of(context).size.width * 0.45),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                          decoration: BoxDecoration(
                            color: navBar == 1
                              ? Colors.lightBlue[700]
                              : null,
                            borderRadius: BorderRadius.circular(30)
                          ),
                          child: Text(
                            "Cupertino", 
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)
                          )
                        ),
                      ],
                    )
                  ),
                ],
              ),
              SizedBox(height: 10),
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() => navBar = 2);
                  },
                  child: Column(
                    children: [
                      Image.asset("assets/illustrations/style/material_nav_dark.png", width: MediaQuery.of(context).size.width * 0.45),
                      SizedBox(height: 5),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        decoration: BoxDecoration(
                          color: navBar == 2
                            ? Colors.lightBlue[700]
                            : null,
                          borderRadius: BorderRadius.circular(30)
                        ),
                        child: Text(
                          "Material", 
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)
                        )
                      ),
                    ],
                  ),
                ),
              ),
        
              SizedBox(height: 30),
              Text("APP ICON", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Theme.of(context).primaryColor.withAlpha(80))),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Theme.of(context).primaryColor.withAlpha(20),
                ),
                margin: EdgeInsets.only(top: 10, bottom: 0),
              ),
              Center(
                child: TextButton(
                  child: Text(
                    "Want to suggest a new icon?",
                    style: TextStyle(
                      color: Colors.blueAccent[200],
                      fontWeight: FontWeight.w500
                    )
                  ),
                  onPressed : () {
                    // TODO push vers un truc pour envoyer des icones avec ce qui faut respecter (prposer de le faire avec IconKitchen)
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SuggestionPage()));
                  }
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SuggestionPage extends StatefulWidget {
  const SuggestionPage({super.key});

  @override
  State<SuggestionPage> createState() => _SuggestionPageState();
}

class _SuggestionPageState extends State<SuggestionPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Transform.scale(
          scale: 0.7,
          child: Button.iconOnly(
            icon: Icon(CupertinoIcons.chevron_left),
            glassIcon: CNSymbol('chevron.left', size: 20),
            backgroundColor: Colors.transparent,
            onPressed: () {
              Navigator.pop(context);
            }
          )
        ),
        title: Text("Suggest an icon", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      ),
      body: Center(
        // child: 
      ),
    );
  }
}