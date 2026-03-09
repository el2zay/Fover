import 'dart:typed_data';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:fover/main.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:pull_down_button/pull_down_button.dart';

enum PopMenuAction {
  download(0),
  copy(1),
  share(2),
  favorite(3),
  duplicate(4),
  hide(5),
  addToAlbum(6),
  adjustDate(7),
  adjustLocation(8);

  final int id;
  const PopMenuAction(this.id);
}

class PopMenu extends StatelessWidget {
  final bool showCopy;
  final bool isViewer;
  final bool isDownloaded;
  final bool isFavorite;
  final Function(PopMenuAction) onSelected;

  const PopMenu({
    super.key, 
    required this.showCopy, 
    required this.isViewer, 
    this.isDownloaded = false, 
    this.isFavorite = false,
    required this.onSelected
  });

  List<PopMenuAction> get _visibleActions => [
  PopMenuAction.download,
  if (showCopy && isViewer) PopMenuAction.copy,
  if (!isViewer) PopMenuAction.share,
  if (!isViewer) PopMenuAction.favorite,
  if (isViewer) PopMenuAction.duplicate,
  PopMenuAction.hide,
  PopMenuAction.addToAlbum,
  if (isViewer) PopMenuAction.adjustDate,
  if (isViewer) PopMenuAction.adjustLocation,
];

  @override
  Widget build(BuildContext context) {
    if (is26OrNewer) {
      return CNPopupMenuButton.icon(
        size: 40,
        buttonIcon: CNSymbol('ellipsis', size: 15),
        items: [
          CNPopupMenuItem(
              label: isDownloaded ? 'Remove download' : 'Download',
              icon: CNSymbol('arrow.down.circle', size: 20),
          ),
          if (showCopy && isViewer)
            CNPopupMenuItem(
              label: 'Copy',
              icon: CNSymbol('doc.on.doc', size: 20),
            ),
          if (!isViewer) 
            CNPopupMenuItem(
              label: 'Share',
              icon: CNSymbol('plus.square.on.square', size: 20),
            ),
          if (!isViewer)
            CNPopupMenuItem(
              label: isFavorite ? "Remove from favorites" : "Add to favorites",
              icon: CNSymbol('heart', size: 18),
            ),
          if (isViewer)
            CNPopupMenuItem(
              label: 'Duplicate',
              icon: CNSymbol('plus.square.on.square', size: 20),
            ),
          CNPopupMenuItem(
            label: 'Hide',
            icon: CNSymbol('eye.slash', size: 20),
          ),
          CNPopupMenuItem(
            label: 'Add to Album',
            icon: CNSymbol('plus.rectangle.on.rectangle', size: 20),
          ),
          CNPopupMenuDivider(),
          if (isViewer)...[
            CNPopupMenuItem(
              label: 'Adjust the date and time',
              icon: CNSymbol('calendar.badge.clock', size: 20),
            ),
            CNPopupMenuItem(
              label: 'Adjust the location',
              icon: CNSymbol('mappin.circle', size: 20),
            )
          ]
        ],
        onSelected: (id) {
          if (id < _visibleActions.length) {
            onSelected(_visibleActions[id]);
          }
        }
      );
    } else {
      return PullDownButton(
        itemBuilder: (context) => [
          PullDownMenuItem(
            title: isDownloaded ? 'Remove download' : 'Download',
            icon: isDownloaded ? CupertinoIcons.arrow_down_circle_fill : CupertinoIcons.arrow_down_circle,
            onTap: () {
              onSelected(PopMenuAction.download);
            },
          ),
          if (showCopy && isViewer)
            PullDownMenuItem(
              title: 'Copy',
              icon: CupertinoIcons.doc_on_doc,
              onTap: () {
                onSelected(PopMenuAction.copy);
              },
            ),
          if (!isViewer) 
            PullDownMenuItem(
              title: 'Share',
              icon: CupertinoIcons.share_up,
              onTap: () {
                onSelected(PopMenuAction.share);
              },
            ),
          if (!isViewer)
            PullDownMenuItem(
              title: isFavorite ? "Remove from favorites" : "Add to favorites",
              icon: isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              onTap: () {
                onSelected(PopMenuAction.favorite);
              },
            ),
          if (isViewer)
            PullDownMenuItem(
              title: 'Duplicate',
              icon: CupertinoIcons.plus_square_on_square,
              onTap: () {
                onSelected(PopMenuAction.duplicate);
              },
            ),
          PullDownMenuItem(
            title: 'Hide',
            icon: CupertinoIcons.eye_slash,
            onTap: () {
              onSelected(PopMenuAction.hide);
            },
          ),
          PullDownMenuItem(
            title: 'Add to Album',
            icon: CupertinoIcons.plus_rectangle_on_rectangle,
            onTap: () {
              onSelected(PopMenuAction.addToAlbum);
            },
          ),
          if (isViewer)...[
            PullDownMenuItem(
              title: 'Adjust the date and time',
              icon: CupertinoIcons.calendar,
              onTap: () {
                onSelected(PopMenuAction.adjustDate);
              },
            ),
            PullDownMenuItem(
              title: 'Adjust the location',
              icon: CupertinoIcons.map_pin_ellipse,
              onTap: () {
                onSelected(PopMenuAction.adjustLocation);
              },
            )
          ]
        ],
        buttonBuilder: (context, showMenu) => CupertinoButton(
          onPressed: showMenu,
          padding: EdgeInsets.zero,
          child: Transform.scale(
            scale: 0.7,
            child: Button.iconOnly(icon: Icon(CupertinoIcons.ellipsis, color: CupertinoColors.white), onPressed: showMenu),
          ),
        ),
      );
    }
  }
}