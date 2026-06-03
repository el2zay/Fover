import 'package:cupertino_native_better/cupertino_native_better.dart' show CNSymbol;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/src/widgets/button.dart';

class CleanerPage extends StatelessWidget {
  const CleanerPage({super.key});

// TODO afficher les statistiques quelques part
//* Surement entre les cards et le bouton "How does it work?" 

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 60,
        leading: Transform.scale(
          scale: 0.8,
          child: Button.iconOnly(
            icon: Icon(CupertinoIcons.chevron_left),
            glassIcon: CNSymbol('chevron.left', size: 20),
            backgroundColor: Colors.transparent,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        toolbarHeight: height * 0.2,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(10),
          child:  Text(
          "Choose your\ncleaning mode", 
          style: TextStyle(
            fontSize: height * 0.056, 
            fontWeight: FontWeight.bold
          ),
          textAlign: TextAlign.center,
        ),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: height * 0.03),
            SizedBox(
              height: height * 0.58,
              child: Wrap(
                spacing: 20,
                runSpacing: 15,
                alignment: WrapAlignment.center,
        
                  children: [
                    buildCard(
                      context, 
                      CupertinoIcons.shuffle, 
                      "Random", 
                      LinearGradient(
                        colors: [Colors.blue, Colors.indigo[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight
                      ), 
                      "Fover will randomly select medias to clean",
                      () {}
                    ),
                    buildCard(
                      context,
                      CupertinoIcons.layers, 
                      "Size", 
                      LinearGradient(
                        colors: [Colors.indigo, Colors.purple[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight  
                      ),
                      "Fover will select your heaviest medias to clean",
                      () {}  
                    ),
                    buildCard(
                      context,
                      CupertinoIcons.calendar, 
                      "Date", 
                      LinearGradient(
                        colors: [Colors.purple[600]!, Colors.pink],
                        begin: Alignment.topLeft,   
                        end: Alignment.bottomRight
                      ),
                      "Select the month or year you want to clean",
                      () {}
                    ),
                    buildCard(
                      context,
                      CupertinoIcons.collections, 
                      "Albums", 
                      LinearGradient(
                        colors: [Colors.yellow[800]!, Colors.red[600]!],      
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight
                      ),
                      "Select the albums you want to clean",
                      () {}
                    ),
                  ],
                ),
              ),
               TextButton(
                child: Text(
                  "How does it work?",
                  style: TextStyle(
                    color: Colors.blueAccent[200],
                    fontWeight: FontWeight.w500,
                    fontSize: 18
                  )
                ),
                onPressed : () {
                }
              )
          ],
        ),
      )
    );
  }
  Widget buildCard(BuildContext context, IconData icon, String title, LinearGradient gradient, String description, VoidCallback onTap) {
    final width = (MediaQuery.of(context).size.width - 20 - 40) / 2;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.3,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(15)
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 10,
                  children: [
                    Icon(icon, color: Colors.white, size: 25),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18
                      ),
                    )
                  ],
                ),
              ),
            )
          ),
          SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).primaryColor.withAlpha(150),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}