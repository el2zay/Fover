import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/main.dart';
import 'package:fover/src/widgets/adaptative_container.dart';
import 'package:super_context_menu/super_context_menu.dart';

class ContextMenu extends StatefulWidget {
  const ContextMenu({super.key});

  @override
  State<ContextMenu> createState() => _ContextMenuState();
}

class _ContextMenuState extends State<ContextMenu> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: AdaptativeContainer(
        config: LiquidGlassConfig(
          shape: CNGlassEffectShape.rect,
          effect: CNGlassEffect.regular,
          ),
        padding: const EdgeInsets.all(0),
        child: Padding(padding: const EdgeInsets.only(top: 15, bottom: 15, left: 20, right: 20), 
          child: Column(
            spacing: 12,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: const [
                      Icon(CupertinoIcons.share, size: 20),
                      SizedBox(height: 5),
                      Text('Share', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  SizedBox(width: 20),
                  Column(
                    children: [
                      const Icon(CupertinoIcons.heart, size: 20),
                      const SizedBox(height: 5),
                      Text('Favorites', style: TextStyle(fontSize: 14), textAlign: TextAlign.center),
                    ],
                  ),
                  SizedBox(width: 20),
                  Column(
                    children: [
                      const Icon(CupertinoIcons.delete, size: 20, color: CupertinoColors.destructiveRed,),
                      const SizedBox(height: 5),
                      Text('Delete', style: TextStyle(fontSize: 14, color: CupertinoColors.destructiveRed), textAlign: TextAlign.center),
                    ],
                  ),
                ],
              ),
              Divider(thickness: 0.5, color: CupertinoColors.white.withValues(alpha: 0.3),),
              Row(
                children: const [
                  Icon(CupertinoIcons.doc_on_doc, size: 18),
                  SizedBox(width: 15),
                  Text('Copy', style: TextStyle(fontSize: 18)),
                ],
              ),
              Row(
                children: const [
                  Icon(CupertinoIcons.plus_square_on_square, size: 18),
                  SizedBox(width: 15),
                  Text('Duplicate', style: TextStyle(fontSize: 18)),
                ],
              ),
              Row(
                children: const [
                  Icon(CupertinoIcons.eye_slash, size: 18),
                  SizedBox(width: 15),
                  Text('Hide', style: TextStyle(fontSize: 18)),
                ],
              ),
              Row(
                children: const [
                  Icon(CupertinoIcons.plus_rectangle_on_rectangle, size: 18),
                  SizedBox(width: 15),
                  Text('Add to album', style: TextStyle(fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}