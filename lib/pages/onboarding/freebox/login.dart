import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/pages/onboarding/freebox/connection.dart';

class FreeboxLoginPage extends StatefulWidget {
  const FreeboxLoginPage({super.key});

  @override
  State<FreeboxLoginPage> createState() => _FreeboxLoginPageState();
}

class _FreeboxLoginPageState extends State<FreeboxLoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(title: const Text("Ajouter une Freebox")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            children: [
              const Text(
                "Rapprochez-vous de votre Freebox Server",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Pour autoriser l'association de l'application de manière sécurisée, il va vous être demandé de la valider sur l'afficheur de votre Freebox Server.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 50),
              // Image.asset("assets/images/validation.png", height: 250),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const FreeboxConnectionPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  side: const BorderSide(color: Colors.white, width: 1),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  "C'est fait",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
