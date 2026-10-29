import 'package:based_battery_indicator/based_battery_indicator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/main.dart';
import 'package:fover/src/services/auto_backup.dart';
import 'package:fover/src/widgets/button.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  double batteryValue = box.get("batterySync").toDouble();
  var battery = Battery();
  bool batterySwitch = false;

  @override
  void initState() {
    super.initState();
    try {
      _updateBatterySwitch();
    } catch (e) {
      print("Error getting battery level: $e");
    }
  }

  Future<void> _updateBatterySwitch() async {
    final batteryLevel = await battery.batteryLevel;
    final allowed = await AutoBackup.batteryAllows();

    if (!mounted) return;

    setState(() {
      batterySwitch = batteryLevel > batteryValue;
      batterySwitch = allowed;
    });
  }

  @override
  void dispose() {
    AutoBackup.run();
    super.dispose();
  }

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
        title: Text("Synchronization", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: EdgeInsets.all(10),
        children: [
          // ListTile(
          //   title: Text("Auto Sync"),
          //   subtitle: Text("Upload automatically your data to your cloud when you are connected to the internet"),
          //   trailing: CNSwitch(
          //     value: box.get("autoSync") ?? true,
          //     color: CupertinoColors.activeGreen,
          //     onChanged: (value) async {
          //     }
          //   ),
          // ),
          Text(
            "Auto Sync based on Battery %",
            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w600)
          ),
          SizedBox(height: 5),
          Container(
            padding: EdgeInsets.only(top: 10, left: 15, right: 15, bottom: 5),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("On"), 
                      Row(
                        children: [
                          Text(
                            batteryValue > 0 && batteryValue < 100
                              ? "When Above ${batteryValue.toInt()}%"
                              : batteryValue == 0
                                ? "Always On"
                                : "Always Off",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).primaryColor,
                              fontSize: 15,
                              fontFeatures: [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          SizedBox(width: 10),
                          if (batteryValue > 0 && batteryValue < 100)
                          BasedBatteryIndicator(
                            status: BasedBatteryStatus(
                              value: batteryValue.toInt(),
                              // type: BasedBatteryStatusType.normal,
                            ),
                            trackHeight: 12.0,
                            trackAspectRatio: 2.0,
                            duration: Duration.zero,
                          ),
                        ],
                      ),
                      Text("Off")
                    ],
                  ),
                ),
                CNSlider(
                  value: batteryValue,
                  min: 0,
                  max: 100,
                  color: Colors.blueAccent[200],
                  onChanged: (value) async {
                    setState(()  {
                      batteryValue = value;
                      box.put("batterySync", value);
                    });
                    batterySwitch = await battery.batteryLevel > batteryValue;
                  }
                ),
                ListTile(
                  contentPadding: EdgeInsets.all(0),
                  title: Text("Auto Sync enabled", style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: CNSwitch(
                    enabled: false,
                    value: batterySwitch,
                    color: Colors.green,
                    onChanged: (value) async {
                      final allowed = await AutoBackup.batteryAllows();
                      if (mounted) setState(() => batterySwitch = allowed);
                    },
                  ),
                ),
              ],
            )
          ),
          SizedBox(height: 5),

          Text(
            batteryValue == 100
              ? "Your media files will not be synced automatically.\n"
              : batteryValue == 0
                ? "Your media files will be automatically uploaded to your cloud."
                : "If your battery level is above ${batteryValue.toInt()}%, your media files will be automatically uploaded to your cloud.",
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
              fontFeatures: [
                FontFeature.tabularFigures()
              ]
            ),
            ),
          SizedBox(height: 15),
          buildDataListTile(title: "Synchronize Photos", boxName: "syncPhotos"),
          SizedBox(height: 15),
          buildDataListTile(title: "Synchronize Videos", boxName: "syncVideos"),
        ]
      )
    );
  }

  Widget buildDataListTile({required String title, required String boxName}) {
    const options = {
      'wifi': 'Wi-Fi only',
      'any': 'Mobile Data and Wi-Fi',
    };

    final current = box.get(boxName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          child: Text(
            title,
            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w600)
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Theme.of(context).primaryColor.withAlpha(20),
          child: ListView.separated(
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 20,
              endIndent: 20,
              color: Theme.of(context).primaryColor.withAlpha(20),
            ),
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final value = options.keys.elementAt(index);
              return CheckboxListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                title: Text(options[value]!),
                value: current == value,
                onChanged: (_) {
                  box.put(boxName, value);
                  setState(() {});
                },
              );
            },
          ),
        ),
      ],
    );
  }
}