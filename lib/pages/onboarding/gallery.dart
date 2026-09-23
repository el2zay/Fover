import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:fover/pages/library.dart';
import 'package:fover/pages/onboarding/login.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  int page = 0;
  Future<PermissionState> isGalleryAvailable() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    return ps;
  }

  @override
  void initState() {
    super.initState();
    isGalleryAvailable().then((ps) {
      if (ps == PermissionState.authorized) {
        setState(() => page = 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SafeArea(
          child: page == 0 
            ? galleryAccess()
            : serverAccess(context),
        ),
      )
    );
  }

  Center serverAccess(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Icon(LucideIcons.router, size: 100),
                ),
                SizedBox(height: 20),
                Text(
                  "Would you like to connect to a server?",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                Text(
                  "You can always do that later.",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400)
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CopypartyLoginPage())),
              child: Text("Connect to a server", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryPage())),
              child: Text("Continue without a server", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          )
        ],
      )
    );
  }

  Widget galleryAccess() {
    return Column(
      children: [
        Spacer(),
        FutureBuilder(
          future: isGalleryAvailable(),
          builder: (context, snapshot) {
            if (snapshot.data == PermissionState.denied || snapshot.data == PermissionState.notDetermined || snapshot.data == null) {
              return Column(
                children: [
                  Center(
                    child: Text(
                      "Please grant access to the gallery", 
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (snapshot.data == PermissionState.denied)
                    grantPermissionButton()
                ]
              );
            } else if (snapshot.data == PermissionState.authorized) {
              setState(() => page = 1);
              // Passer a la page suivante
              return Center(
                child: Text(
                  "Access has indeed been granted",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                )
              );
            } else {
              return Center(
                child: Column(
                  children: [
                    Text(
                      "Access to the gallery is restricted.",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)
                    ),
                    Text(
                      "Would you like to continue anyway?",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400)
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        grantPermissionButton(),
                        TextButton(
                          onPressed: () {
                            setState(() => page = 1);
                          },
                          child: Text(
                            "Continue anyway",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.indigoAccent[200])
                          ),
                        )
                      ],
                    )
                  ],
                ),
              );
            }
          }
        ),
      ],
    );
  } 

  TextButton grantPermissionButton() {
    return TextButton(
      child: Text(
        "Grant permission",
        style: TextStyle(
          color: Colors.indigoAccent[200],
          fontWeight: FontWeight.bold,
          fontSize: 18
        )
      ),
      onPressed : () async {
        final PermissionState ps = await PhotoManager.requestPermissionExtend();
        if (ps == PermissionState.authorized) {
          setState(() {});
        } else {
          // TODO a essayer sur un vrai appareil
          AppSettings.openAppSettings(type: AppSettingsType.appLocale, asAnotherTask: true);
        }
      }
    );
  }
}