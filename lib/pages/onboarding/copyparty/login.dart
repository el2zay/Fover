import 'package:cupertino_native_better/style/sf_symbol.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fover/src/widgets/button.dart';

class CopypartyLoginPage extends StatefulWidget {
  const CopypartyLoginPage({super.key});

  @override
  State<CopypartyLoginPage> createState() => _CopypartyLoginPageState();
}

class _CopypartyLoginPageState extends State<CopypartyLoginPage> {
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
                      text: " to see the instructions.\nIt will take you no more than 5 minutes !",
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 20,
                  children: [
                    Text(
                      "Login", 
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.start
                    ),
                    _buildTextField(hint: "IP Address"),
                    _buildTextField(hint: "Login"),
                    _buildTextField(hint: "Password", isPassword: true)
                  ],
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
                  onPressed: () {},
                  child: Text("Continue", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                )
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({String hint = "", bool isPassword=false}) {
    return TextField(
      decoration: InputDecoration(
        hint: Text(hint, style: TextStyle(fontSize: 15)),
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
      obscureText: isPassword,
    );
  }
}