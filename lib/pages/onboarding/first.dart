import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/pages/onboarding/copyparty/login.dart';
import 'package:fover/pages/onboarding/freebox/login.dart';

class FirstPage extends StatelessWidget {
  const FirstPage({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            Colors.pinkAccent.shade700.withAlpha(200),
            Colors.blue[800]!.withAlpha(100),
          ],
        )
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            children: [
              Spacer(),
              const Text(
                "Fover",
                style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              const Text(
                "Free up your phone. Keep your photos.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white30)
                  ),
                  margin: EdgeInsets.only(top: 90, bottom: 30, left: 20, right: 20),      
                  padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.075),
                   child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        "Fover connects to your home server and turns it into your personal cloud, without the monthly bill",
                        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ), 
                        child: const Text(
                          "Start with your server",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        onPressed: () {
                          Navigator.push(
                            context, 
                            CupertinoPageRoute(
                              builder: (_) => CopypartyLoginPage()
                            )
                          );
                        }
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ), 
                        child: const Text(
                          "Start with Freebox",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                        ),
                        onPressed: () {
                          Navigator.push(
                            context, 
                            CupertinoPageRoute(builder: (_) => FreeboxLoginPage())
                          );
                        }
                      ),
                      SizedBox(height: height * 0.02),
                    ]
                  )
                )
              )
            ]
          )
        )
      ),
    );
  }
}