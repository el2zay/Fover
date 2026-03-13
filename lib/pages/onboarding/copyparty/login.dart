import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/style/sf_symbol.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fover/main.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:fover/src/widgets/dialog.dart';

class CopypartyLoginPage extends StatefulWidget {
  const CopypartyLoginPage({super.key});

  @override
  State<CopypartyLoginPage> createState() => _CopypartyLoginPageState();
}

class _CopypartyLoginPageState extends State<CopypartyLoginPage> {
  TextEditingController urlController = TextEditingController();
  TextEditingController userController = TextEditingController();
  TextEditingController passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Connect with Copyparty", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: EdgeInsets.only(top: 10, left: 5),
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: 
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "What is Copyparty?", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 5),
              Text(
                "Copyparty is a lightweight open-source file server you install on your NAS or home computer.\nIt lets Fover access and browse your photos directly from your own server.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 10),
              Text(
                "Your photos stay at home, under YOUR control.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 15),
              Text(
                "How to set it?", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              RichText(
                strutStyle: StrutStyle(fontSize: 20),
                text: TextSpan(
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  children: [
                    TextSpan(
                      text: "Click ",
                    ),
                    TextSpan(
                      text: "here",
                      style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          showCupertinoSheet(
                            context: context,
                            enableDrag: true,
                            builder: (context) {
                              return Scaffold(
                                backgroundColor: Colors.grey[900],
                                appBar: AppBar(
                                  leading: Transform.scale(
                                    scale: 0.9,
                                    child: Button.iconOnly(
                                      glassIcon: CNSymbol('xmark', size: 14),
                                      icon: Icon(CupertinoIcons.xmark),
                                      onPressed: () => Navigator.pop(context)
                                    ),
                                  )
                                ),
                              );
                            }
                          );
                      }
                    ),
                    TextSpan(
                      text: " to see the instructions.\nIt will take you no more than 10 minutes !",
                    )
                  ]
                )
              ),
              SizedBox(height: 10),
              Container(
                margin: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20)
                ),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 25),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 20,
                    children: [
                      Text(
                        "Login", 
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.start
                      ),
                      _buildTextField(controller: urlController, hint: "IP Address"),
                      _buildTextField(controller: userController, hint: "Username"),
                      _buildTextField(controller: passController, hint: "Password", isPassword: true)
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 50),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[800],
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    //? Pour éviter le warning
                    final navigator = Navigator.of(context);
                    if (!_formKey.currentState!.validate()) return;
                    try {
                      await CopypartyService.connect(
                        url: urlController.text.trim(),
                        username: userController.text.trim(),
                        password: passController.text.trim()
                      );
                      
                      await initApp();

                      if (!mounted) return;
                      navigator.pushAndRemoveUntil(
                        CupertinoPageRoute(builder: (_) => const MainApp()),
                        (_) => false,
                      );
                    } on TimeoutException {
                      if (!mounted) return;
                      showGeneralDialog(
                        barrierDismissible: false,
                        // ignore: use_build_context_synchronously
                        context: context,
                        pageBuilder: (context, animation, secondaryAnimation) {
                          return MyDialog(
                            content: "Connection timed out. Please check your URL and your Internet connection.",
                            secondLabel: "OK",
                          );
                        }
                      );
                    } catch (e) {
                      print(e);
                      if (!mounted) return;
                      showGeneralDialog(
                        barrierDismissible: false,
                        // ignore: use_build_context_synchronously
                        context: context,
                        pageBuilder: (context, animation, secondaryAnimation) {
                          return MyDialog(
                            content: e.toString().replaceAll("Exception: ", ""),
                            secondLabel: "OK",
                          );
                        }
                      );
                    }
                  },
                  child: Text("Continue", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                )
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({TextEditingController? controller,  String hint = "", bool isPassword=false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hint: Text(hint, style: TextStyle(fontSize: 15, color: Colors.white70)),
        fillColor: Colors.grey.withAlpha(10),
        filled: true,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.transparent),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter the $hint';
        }
        return null;
      },
      obscureText: isPassword,
    );
  }
}