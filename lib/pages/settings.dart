import 'package:cupertino_native_better/style/sf_symbol.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:fover/main.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/utils/common_utils.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:fover/src/widgets/dialog.dart';
import 'package:gradient_progress_bar/gradient_progress_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int freeStorage = 0;
  int totalStorage = 0;
  double storageUsed = 0;

  @override
  void initState() {
    super.initState();
    CopypartyService.getDiskUsage().then((usage) {
      setState(() {
        freeStorage = usage?["free"] ?? 0;
        totalStorage = usage?["total"] ?? 0;
        storageUsed = freeStorage / totalStorage;
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
                  Text(
                    "${formatSize(totalStorage - freeStorage)} used out of ${formatSize(totalStorage)}",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70
                   )
                  ),
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
          if (detectBackend() == ServerBackend.freebox)
            ListTile(
              leading: Icon(CupertinoIcons.folder),
              title: Text("Change the photo folder"),
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
            leading: Icon(CupertinoIcons.exclamationmark_triangle),
            title: Text("Report a bug"),
            trailing: Icon(CupertinoIcons.chevron_forward),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red[600]),
            title: Text("Log out", style: TextStyle(color: Colors.red)),
            onTap: () {
              // TODO freebox
              showGeneralDialog(
                context: context, 
                 pageBuilder: (context, animation, secondaryAnimation) {
                  return MyDialog(
                    content: "Are you sure you want to log out?",
                    principalButton: TextButton(
                      child: Text("Log out", style: TextStyle(fontSize: 16, color: CupertinoColors.destructiveRed)),
                      onPressed: () {
                        Navigator.pop(context);
                        CopypartyService.disconnect();
                        Phoenix.rebirth(context);
                      }
                    ),
                  );
                }
              );
            },
          ),
        ]
      ),
    );
  }
}