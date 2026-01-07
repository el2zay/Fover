

/*
Première page : "Comment souhaitez-vous vous connecter ?"

2 gros boutons circulaires centrés :
- Bouton 1 : Freebox (avec une icone Freebox à l'interieur)
- Bouton 2 : Serveur NAS (avec une icone NAS à l'interieur)

Lorsque bouton 1 sélectionné : faire comme Call Notifier
Lorsque bouton 2 sélectionné : Popup pour demander adresse IP du NAS et identifiants (voir comment d'autres applis font ça)
*/

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:freebox_photos/pages/login.dart';

class FirstPage extends StatefulWidget {
  const FirstPage({super.key});

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 38, 38, 38),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // ElevatedButton(
                //   onPressed: () {
                //   },
                //   style: ElevatedButton.styleFrom(
                //     shape: const CircleBorder(),
                //     padding: const EdgeInsets.all(40),
                //     backgroundColor: Colors.transparent,
                //     side: const BorderSide(color: Colors.white, width: 1),
                //   ),
                //   child: const Icon(Icons.router, size: 50),
                // ),
                CNButton.icon(onPressed: () {
                  Navigator.push(context, CupertinoPageRoute(builder: (context) => const LoginPage()));
                },
                imageAsset: CNImageAsset('assets/icons/freebox_icon.png'),

                ),
                // ElevatedButton(
                //   onPressed: () {

                //   },

                //   style: ElevatedButton.styleFrom(
                //     shape: const CircleBorder(),
                //     padding: const EdgeInsets.all(40),
                //     backgroundColor: Colors.transparent,
                //     side: const BorderSide(color: Colors.white, width: 1),
                //   ),
                //   child: const Icon(Icons.router, size: 50),
                // ),

              CNButton.icon(
                config: const CNButtonConfig(
                  // padding: EdgeInsets.all(40),
                  imagePlacement: CNImagePlacement.trailing,
                ),
                onPressed: () {},
                
                imageAsset: CNImageAsset('assets/icons/server.png', color: Colors.white, size: 30),
                ),
              ],
            ),
        ],
      ),
    );
  }
}