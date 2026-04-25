import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fover/main.dart';
import 'package:fover/src/services/copyparty_service.dart';
import 'package:fover/src/widgets/dialog.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class CopypartyLoginPage extends StatefulWidget {
  const CopypartyLoginPage({super.key});

  @override
  State<CopypartyLoginPage> createState() => _CopypartyLoginPageState();
}

class _CopypartyLoginPageState extends State<CopypartyLoginPage> {
  final TextEditingController urlController = TextEditingController();
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  final FocusNode urlFocus = FocusNode();
  final FocusNode userFocus = FocusNode();
  final FocusNode passFocus = FocusNode();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    urlController.dispose();
    userController.dispose();
    passController.dispose();
    urlFocus.dispose();
    userFocus.dispose();
    passFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Connect with Copyparty",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
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
                text: TextSpan(
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: primary),
                  children: [
                    TextSpan(
                      text: "Click ",
                    ),
                    TextSpan(
                      text: "here",
                      style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          await launchUrl(
                            Uri.parse("https://github.com/el2zay/Fover/#fover"),
                            mode: LaunchMode.inAppWebView
                          );
                        }
                    ),
                    const TextSpan(
                      text: " to see the instructions.\nIt will take you no more than 10 minutes !",
                    )
                  ]
                )
              ),
              SizedBox(height: 10),
              Container(
                margin: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(20)
                ),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 25),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 20,
                      children: [
                        const Text(
                          "Login",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.start,
                        ),
                        _buildTextField(
                          controller: urlController,
                          hint: "IP Address",
                          focusNode: urlFocus,
                          nextFocus: userFocus,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          autofocus: true,
                          autofillHints: const [AutofillHints.url],
                        ),
                        _buildTextField(
                          controller: userController,
                          hint: "Username",
                          focusNode: userFocus,
                          nextFocus: passFocus,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                        ),
                        _buildTextField(
                          controller: passController,
                          hint: "Password",
                          isPassword: true,
                          focusNode: passFocus,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[800],
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    if (!_formKey.currentState!.validate()) return;

                    try {
                      await CopypartyService.connect(
                        url: urlController.text.trim(),
                        username: userController.text.trim(),
                        password: passController.text.trim(),
                      );

                      await initApp();

                      if (!mounted) return;
                      navigator.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const MainApp()),
                        (_) => false,
                      );
                    } on TimeoutException {
                      if (!mounted) return;
                      showGeneralDialog(
                        barrierDismissible: false,
                        context: context,
                        pageBuilder: (context, animation, secondaryAnimation) {
                          return MyDialog(
                            content: "Connection timed out. Please check your URL and your Internet connection.",
                            principalButton: TextButton(onPressed: () {}, child: SizedBox()),
                          );
                        },
                      );
                    } catch (e) {
                      if (!mounted) return;
                      showGeneralDialog(
                        barrierDismissible: false,
                        // ignore: use_build_context_synchronously
                        context: context,
                        pageBuilder: (context, animation, secondaryAnimation) {
                          return MyDialog(
                            content: e.toString().replaceAll("Exception: ", ""),
                            principalButton: null
                          );
                        }
                      );
                    }
                  },
                  child: Text("Continue", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                )
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    bool isPassword = false,
    bool autofocus = false,
    TextInputAction? textInputAction,
    TextInputType? keyboardType,
    List<String>? autofillHints,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: isPassword,
      autocorrect: false,
      enableSuggestions: !isPassword,
      keyboardType: keyboardType,
      textInputAction: textInputAction ??
          (nextFocus != null ? TextInputAction.next : TextInputAction.done),
      autofillHints: autofillHints,
      onFieldSubmitted: (_) {
        if (nextFocus != null) {
          nextFocus.requestFocus();
        } else {
          FocusScope.of(context).unfocus();
        }
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 15, color: Theme.of(context).primaryColor.withAlpha(200)),
        fillColor: Colors.grey.withAlpha(10),
        filled: true,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.transparent),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter the $hint';
        }
        return null;
      },
    );
  }
}