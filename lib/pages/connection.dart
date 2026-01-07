import 'dart:async';

import 'package:freebox_photos/src/utils/requests.dart';
import 'package:flutter/material.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  late Future<dynamic> infos;
  Timer? _timer;
  final ValueNotifier<int> _elapsedTimeNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    infos = signUp(context);
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedTimeNotifier.value += 1;
    });
  }

  String formatElapsedTime(int elapsedTime) {
    final minutes = (elapsedTime ~/ 6000).toString().padLeft(2, '0');
    final seconds = ((elapsedTime % 6000) ~/ 100).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(title: const Text("Ajouter une Freebox")),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        child: Column(
          children: [
            const Text("Autorisez l'association sur l'afficheur", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
                children: <TextSpan>[
                  TextSpan(text: "Pour finaliser l'ajout, vous devez autoriser l'application en "),
                  TextSpan(text: "appuyant sur la Oui/OK.", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 50),
            ValueListenableBuilder<int>(
              valueListenable: _elapsedTimeNotifier,
              builder: (context, elapsedTime, child) {
                if (elapsedTime == 0) {
                  startTimer();
                }
                if (elapsedTime >= 90) {
                  _timer?.cancel();
                  // return ElevatedButton(
                  //   onPressed: () {
                  //     Navigator.pop(context);
                  //   },
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: Colors.transparent,
                  //     elevation: 0,
                  //     side: const BorderSide(color: Colors.white, width: 1),
                  //     minimumSize: const Size(double.infinity, 50),
                  //   ),
                  //   child: const Text(
                  //     "C'est fait",
                  //     style: TextStyle(
                  //       color: Colors.white,
                  //       fontSize: 15,
                  //       fontWeight: FontWeight.bold,
                  //     ),
                  //   ),
                  // );
                }
                
                // return Text(
                //   formatElapsedTime(elapsedTime),
                //   style: const TextStyle(
                //     fontSize: 15,
                //     color: Colors.white,
                //   ),
                // );
                return Container(
                  height: 300,
                  width: 300,
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
