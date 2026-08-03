import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/src/widgets/container.dart';
import 'package:native_dialog_plus/native_dialog_plus.dart';
import 'package:pro_video_editor/core/platform/io/io_helper.dart';

void showMyDialog({required BuildContext context, String title = '', required String content, String? principalButtonText, Function()? onTap, bool isDestructive = false, Function()? onCancel, bool needCancel = true}) {
  if (Platform.isAndroid) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: title.isNotEmpty ? Text(title) : null,
          content: Text(content, style: TextStyle(fontSize: 15)),
          actions: [
            if (needCancel)
              TextButton(
                onPressed: onCancel ?? () {
                  Navigator.of(context).pop();
                },
                child: Text("Cancel", style: TextStyle(fontSize: 16)),
              ),
            if (principalButtonText != null)
              TextButton(
                onPressed: () {
                  onTap?.call();
                  Navigator.of(context).pop();
                },
                child: Text(
                  principalButtonText, 
                  style: TextStyle(
                    color: isDestructive ? Colors.red : null,
                    fontSize: 16
                  ) 
                ),
              ),
          ],
        );
      }
    );
  } else {    
    NativeDialogPlus(
      actions: [
        if (needCancel)
          NativeDialogPlusAction(
            text: "Cancel",
            style: NativeDialogPlusActionStyle.cancel,
            onPressed: onCancel ?? () {}
          ),
        if (principalButtonText != null)
        NativeDialogPlusAction(
          text: principalButtonText,
          onPressed: onTap,
          style: isDestructive 
            ? NativeDialogPlusActionStyle.destructive 
            : NativeDialogPlusActionStyle.defaultStyle,
          ),
        ],
        title: title,
        message: content,
    ).show();
  }
}

class MyOldDialog extends StatelessWidget {
  final String content;
  final TextButton? principalButton;
  final Function()? onCancel;
  final bool? needCancel;
  const MyOldDialog({super.key, required this.content, this.principalButton, this.onCancel, this.needCancel = true});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          minWidth: 0,
          maxWidth: 350
        ),
        child: MyContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsetsGeometry.all(20),
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    content,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
                    textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Divider(thickness: 0.5, height: 1, color: Colors.white24),
                if (needCancel != false)
                Row(
                  mainAxisAlignment: principalButton != null ? MainAxisAlignment.spaceAround : MainAxisAlignment.center,
                  children: [
                    TextButton(
                      child: Text("Cancel", style: TextStyle(fontSize: 16, color: CupertinoColors.activeBlue)),
                      onPressed: () {
                        if (onCancel != null) onCancel!();
                        Navigator.pop(context);
                      }
                    ),
                    principalButton ?? SizedBox(width: 0)
                  ],
                )
              ]
            )
          )
        ),
    );
  }
}