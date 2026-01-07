import 'dart:io';

import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:freebox/freebox.dart';
import 'package:get_storage/get_storage.dart';

final box = GetStorage();

Future signUp(context) async {
  var register = await FreeboxClient.registerFreebox(
    appId: 'fbx.freebox_photos',
    appName: 'Freebox Photos',
    appVersion: '1.0.0',
    deviceName: Platform.operatingSystem,
    verbose: false
  );

  String sRegister = register.toString();

  if (sRegister.contains("appToken") && sRegister.contains("apiDomain") && sRegister.contains("httpsPort")) {
    box.write("appToken", register["appToken"]);
    box.write("apiDomain", register["apiDomain"]);
    box.write("httpsPort", register["httpsPort"]);

    Phoenix.rebirth(context);
  }

  return register;
}