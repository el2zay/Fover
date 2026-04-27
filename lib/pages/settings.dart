import 'dart:io';

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
        storageUsed = totalStorage > 0 
          ? (totalStorage - freeStorage) / totalStorage 
          : 0.0;
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    Color primary = Theme.of(context).primaryColor;
    bool isDark = Theme.brightnessOf(context) == Brightness.dark;
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  SizedBox(height: 20),
                  if (model != null)...[
                    Center(
                      child: Image.asset("assets/illustrations/freebox/${model!.toLowerCase()}.png", height: 45)
                    ),
                    SizedBox(height: 15),
                    Center(child: Text("Freebox Server $model", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                  ],
                  Container(
                    // elevation: 0,
                    padding: EdgeInsets.only(bottom: 10),
                    margin: EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
                    ),
                    child: Padding(padding: EdgeInsetsGeometry.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${formatSize(totalStorage - freeStorage)} used out of ${formatSize(totalStorage)}",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: primary.withAlpha(200)
                          )
                          ),
                          SizedBox(height: 10),
                          GradientProgressIndicator(
                            isDark ? [
                              Colors.green,
                              Colors.yellow,
                              Colors.orange,
                              Colors.red[500]!,
                              Colors.red[600]!,
                              Colors.red[700]!,
                            ] : [
                              Colors.green[500]!,
                              Colors.yellow[700]!,
                              Colors.orange[700]!,
                              Colors.red[400]!,
                              Colors.red[500]!,
                              Colors.red[800]!,
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
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Available in a future update!")
                          )
                        );
                      },
                    ),
                  ListTile(
                    leading: Icon(CupertinoIcons.globe),
                    title: Text("Language"),
                    trailing: Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Available in a future update!"),
                        )
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.swipe_outlined),
                    title: Text("Swipe cards"),
                    trailing: Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Available in a future update!"),
                        )
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(CupertinoIcons.exclamationmark_triangle),
                    title: Text("Report a bug"),
                    onTap: () {
                      openUrl(
                        Uri.parse(
                          "mailto:zayatelie27@gmail.com?subject=Fover — Bug Report on ${Platform.operatingSystem} ${Platform.operatingSystemVersion}"
                        )
                      );
                    },
                    trailing: Icon(CupertinoIcons.chevron_forward),
                  ),
                  ListTile(
                    leading: Icon(Icons.lightbulb_outline),
                    title: Text("Make a suggestion"),
                    onTap: () {
                      openUrl(
                        Uri.parse(
                          "mailto:zayatelie27@gmail.com?subject=Fover — Suggestion"
                        )
                      );
                    },
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
                              onPressed: () async {
                                Navigator.pop(context);
                                CopypartyService.disconnect();
                                showTabBar.value = false;
                                await Future.delayed(const Duration(milliseconds: 100));
                                Phoenix.rebirth(context);
                              }
                            ),
                          );
                        }
                      );
                    },
                  ),
                ]
              )
            ),
            Text("Developed in Paris 🥐 by Elie"),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // TODO mettre les icones 
              ],
            )
          ]
        )
      )
    );
  }
}