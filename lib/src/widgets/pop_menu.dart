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
  adjustLocation(8),
  revert(9);

  final int id;
  const PopMenuAction(this.id);
}

class PopMenu extends StatelessWidget {
  final double scale;
  final bool showCopy;
  final bool isViewer;
  final bool isDownloaded;
  final bool isFavorite;
  final bool isHidden;
  final bool canRevert;
  final Function(PopMenuAction) onSelected;

  const PopMenu({
    super.key, 
    this.scale = 0.7,
    required this.showCopy, 
    required this.isViewer, 
    this.isDownloaded = false, 
    this.isFavorite = false,
    required this.isHidden,
    this.canRevert = false,
    required this.onSelected
  });

  @override
  Widget build(BuildContext context) {
    if (is26OrNewer) {
        final items = [];
        final actions = <PopMenuAction?>[];

        void add(dynamic item, PopMenuAction? action) {
          items.add(item);
          actions.add(action);
        }

        add(CNPopupMenuItem(label: isDownloaded ? 'Remove download' : 'Download', icon: CNSymbol('arrow.down.circle', size: 20)), PopMenuAction.download);
        if (showCopy && isViewer) {
          add(CNPopupMenuItem(label: 'Copy', icon: CNSymbol('doc.on.doc', size: 20)), PopMenuAction.copy);
        }
        if (canRevert) {
          add(CNPopupMenuItem(label: 'Revert to original', icon: CNSymbol('arrow.counterclockwise.circle')), PopMenuAction.revert);
        }
        if (!isViewer) {
          add(CNPopupMenuItem(label: 'Share', icon: CNSymbol('square.and.arrow.up', size: 20)), PopMenuAction.share);
        }
        if (!isViewer) {
          add(CNPopupMenuItem(label: isFavorite ? 'Remove from favorites' : 'Add to favorites', icon: CNSymbol('heart', size: 18)), PopMenuAction.favorite);
        }
        add(CNPopupMenuItem(label: isHidden ? 'Unhide' : 'Hide', icon: CNSymbol(isHidden ? 'eye' : 'eye.slash', size: 20)), PopMenuAction.hide);
        add(CNPopupMenuItem(label: 'Add to Album', icon: CNSymbol('plus.rectangle.on.rectangle', size: 20)), PopMenuAction.addToAlbum);
        if (isViewer) {
          add(CNPopupMenuDivider(), null); 
          add(CNPopupMenuItem(label: 'Adjust the date and time', icon: CNSymbol('calendar.badge.clock', size: 20)), PopMenuAction.adjustDate);
          add(CNPopupMenuItem(label: 'Adjust the location', icon: CNSymbol('mappin.circle', size: 20)), PopMenuAction.adjustLocation);
        }


      return CNPopupMenuButton.icon(
        size: 40,
        buttonIcon: CNSymbol('ellipsis', size: 15),
        items: items.cast(),
        onSelected: (id) {
          final action = actions[id];
          if (action != null) onSelected(action);
        },
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
          if (canRevert)
            PullDownMenuItem(
              title: 'Revert to original',
              onTap: () => onSelected(PopMenuAction.revert),
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
            title: isHidden ? 'Unhide' : 'Hide',
            icon: isHidden 
              ? CupertinoIcons.eye
              : CupertinoIcons.eye_slash,
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
            scale: scale,
            child: Button.iconOnly(icon: Icon(CupertinoIcons.ellipsis, color: CupertinoColors.white), onPressed: showMenu),
          ),
        ),
      );
    }
  }
}