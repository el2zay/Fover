import 'package:cupertino_native_better/style/sf_symbol.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/main.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:gradient_progress_bar/gradient_progress_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double storageUsed = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 50), () {
    setState(() {
      storageUsed = 0.519;
    });
  });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        leading: Row(
          children: [
            Button.iconOnly(
              icon: Icon(Icons.close),
              glassIcon: CNSymbol('xmark', size: 14),
               onPressed: () {
                Navigator.pop(context);
               },
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          if (model != null)...[
            Center(
              child: Image.asset("assets/illustrations/freebox/${model!.toLowerCase()}.png", height: 45)
            ),
            SizedBox(height: 15),
            Center(child: Text("Freebox Server $model", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          ],
          Card(
            color: Colors.white10,
            child: Padding(padding: EdgeInsetsGeometry.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("519 Go used out of 1To", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70)),
                  SizedBox(height: 10),
                  GradientProgressIndicator([
                      Colors.green,
                      Colors.yellow,
                      Colors.orange,
                      Colors.red[500]!,
                      Colors.red[700]!,
                    ], storageUsed),
                ],
              ),
            )
          ),
          SizedBox(height: 5),
          ListTile(
            leading: Icon(CupertinoIcons.folder),
            title: Text("Change the photo folder"),
            trailing: Icon(CupertinoIcons.chevron_forward),
          ),
          ListTile(
            leading: Icon(CupertinoIcons.exclamationmark_triangle),
            title: Text("Report a bug"),
            trailing: Icon(CupertinoIcons.chevron_forward),
          ),
          ListTile(
            leading: Icon(CupertinoIcons.bell),
            title: Text("Notifications"),
            trailing: Icon(CupertinoIcons.chevron_forward),
          ),
          ListTile(
            leading: Icon(CupertinoIcons.globe),
            title: Text("Language"),
            trailing: Icon(CupertinoIcons.chevron_forward),
          ),
          ListTile(
            leading: Icon(CupertinoIcons.ellipsis_circle),
            title: Text("Peronalize the context menu"),
            trailing: Icon(CupertinoIcons.chevron_forward),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text("Disconnect"),
            trailing: Icon(CupertinoIcons.chevron_forward),
          ),
        ]
      ),
    );
  }
}