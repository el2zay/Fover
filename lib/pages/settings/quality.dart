import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/main.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:fover/src/widgets/checkbox_tile.dart';

class QualityPage extends StatefulWidget {
  const QualityPage({super.key});

  @override
  State<QualityPage> createState() => _QualityPageState();
}

class _QualityPageState extends State<QualityPage> {
  int selectedQualityMobile = box.get('qualityMobile', defaultValue: 2);
  int selectedQualityWifi = box.get('qualityWifi', defaultValue: 1);

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
            onPressed: () => Navigator.pop(context)
          )
        ),
        title: Text("Video quality", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView(
          children: [
            Text("Quality via mobile data", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            SizedBox(height: 10),
            buildCardQuality(
              context, 
              selectedQualityMobile, 
              (quality) {
                setState(() {
                  selectedQualityMobile = quality;
                });
                box.put('qualityMobile', quality);
              },

            ),
            SizedBox(height: 15),
            Text("Quality via Wi-Fi", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            SizedBox(height: 10),
            buildCardQuality(
              context, 
              selectedQualityWifi, 
              (quality) {
                setState(() {
                  selectedQualityWifi = quality;
                });
                box.put('qualityWiFi', quality);
              },
            ),
            SizedBox(height: 20),
            ListTile(
              title: Text("Enable HDR"),
              subtitle: Text("Enable HDR playback for supported videos"),
              trailing: CNSwitch(
                value: box.get('enableHDR', defaultValue: true),
                color: CupertinoColors.activeGreen,
                onChanged: (value) async {
                  box.put('enableHDR', value);
                }
              ),
            ),
          ],
        ),
      )
    );
  }

  Widget buildCardQuality(BuildContext context, int value, Function onSelect) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          MyCheckboxListTile(
            title: Text("4K (if available)"),
            value: value == 0,
            onChanged: (_) => onSelect(0)
          ),
          MyCheckboxListTile(
            title: Text("1080p"),
            value: value == 1,
            onChanged: (_) => onSelect(1)
          ),
          MyCheckboxListTile(
            title: Text("720p"),
            value: value == 2,
            onChanged: (_) => onSelect(2)
          ),
          MyCheckboxListTile(
            title: Text("480p"),
            value: value == 3,
            onChanged: (_) => onSelect(3)
          ),
          MyCheckboxListTile(
            title: Text("240p"),
            value: value == 4,
            onChanged: (_) => onSelect(4)
          ),
        ],
      ),
    );
  }
}