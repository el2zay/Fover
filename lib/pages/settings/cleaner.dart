import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/pages/settings/swipe.dart';
import 'package:fover/src/widgets/albums_list.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:fover/src/widgets/date_list.dart';

class CleanerPage extends StatefulWidget {
  const CleanerPage({super.key});

  @override
  State<CleanerPage> createState() => _CleanerPageState();
}

class _CleanerPageState extends State<CleanerPage> {
  bool months = true;

  // TODO afficher les statistiques quelques part
  //* Surement entre les cards et le bouton "How does it work?" 
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: Transform.scale(
          scale: 0.75,
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
          child: Text(
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
                      () => Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (_) => PopScope(
                            canPop: false,
                            child: SwipePage()
                          )
                        )
                      )
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
                      () => Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (_) => PopScope(
                            canPop: false,
                            child: SwipePage(filter: SwipeFilter.size)
                          )
                        )
                      ),
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
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => chooseDate(context))
                      ),
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
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => chooseAlbum(context))
                      ),
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

  // TODO petite transition
   Widget chooseDate(BuildContext context) {
    bool monthsLocal = months;
  
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Scaffold(
          appBar: AppBar(
          leading: Transform.scale(
            scale: 0.7,
            child: Button.iconOnly(
              icon: Icon(CupertinoIcons.chevron_left),
              glassIcon: CNSymbol('chevron.left', size: 20),
              backgroundColor: Colors.transparent,
              onPressed: () => Navigator.pop(context),
              )
            ),
            title: CNPopupMenuButton(
              tint: Theme.of(context).primaryColor,
              buttonStyle: CNButtonStyle.glass,
              shrinkWrap: true,
              buttonLabel: "   ${monthsLocal ? "Months" : "Years"}   ",
              items: [
                CNPopupMenuItem(label: "Select a year", checked: !monthsLocal),
                CNPopupMenuItem(label: "Select a month", checked: monthsLocal),
              ],
              onSelected: (value) {
                setLocalState(() {
                  monthsLocal = value != 0;
                });
              },
            ),
          ),
          body: 
          // TODO transition entre les 2
          DateList(
            filterDate: monthsLocal ? 1 : 0,
          ),
        );
      },
    );
  }

  Widget chooseAlbum(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: Transform.scale(
          scale: 0.7,
          child: Button.iconOnly(
            icon: Icon(CupertinoIcons.chevron_left),
            glassIcon: CNSymbol('chevron.left', size: 20),
            backgroundColor: Colors.transparent,
            onPressed: () => Navigator.pop(context),
            )
        ),
        title: Text("Choose an album", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: EdgeInsetsGeometry.all(10),
        child: AlbumsList(
          crossAxisCount: 2,
          showSpecialAlbums: true,
          onTap: (album) {
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (_) => PopScope(
                  canPop: false,
                  child: SwipePage(
                  filter: SwipeFilter.album, 
                  album: album
                ))
              ),
            );
          },
        ),
      ),
    );
  }
}