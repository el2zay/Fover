import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/main.dart';
import 'package:fover/pages/viewer.dart';
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
  final bool isTablet;
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
    this.isTablet = false,
    required this.onSelected,
  });

  List<({
    PopMenuAction action,
    String label,
    String sfSymbol,
    IconData cupertinoIcon,
  })> _buildEntries() {
    return [
      (
        action: PopMenuAction.download,
        label: isDownloaded ? 'Remove download' : 'Download',
        sfSymbol: 'arrow.down.circle',
        cupertinoIcon: isDownloaded
            ? CupertinoIcons.arrow_down_circle_fill
            : CupertinoIcons.arrow_down_circle,
      ),
      if (showCopy && isViewer)
        (
          action: PopMenuAction.copy,
          label: 'Copy',
          sfSymbol: 'doc.on.doc',
          cupertinoIcon: CupertinoIcons.doc_on_doc,
        ),
      if (canRevert)
        (
          action: PopMenuAction.revert,
          label: 'Revert to original',
          sfSymbol: 'arrow.counterclockwise.circle',
          cupertinoIcon: CupertinoIcons.arrow_counterclockwise_circle,
        ),
      if (!isViewer)
        (
          action: PopMenuAction.share,
          label: 'Share',
          sfSymbol: 'square.and.arrow.up',
          cupertinoIcon: CupertinoIcons.share_up,
        ),
      if (!isViewer)
        (
          action: PopMenuAction.favorite,
          label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
          sfSymbol: 'heart',
          cupertinoIcon:
              isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
        ),
      if (isViewer)
        (
          action: PopMenuAction.duplicate,
          label: 'Duplicate',
          sfSymbol: 'plus.square.on.square',
          cupertinoIcon: CupertinoIcons.plus_square_on_square,
        ),
      (
        action: PopMenuAction.hide,
        label: isHidden ? 'Unhide' : 'Hide',
        sfSymbol: isHidden ? 'eye' : 'eye.slash',
        cupertinoIcon: isHidden ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
      ),
      (
        action: PopMenuAction.addToAlbum,
        label: 'Add to Album',
        sfSymbol: 'plus.rectangle.on.rectangle',
        cupertinoIcon: CupertinoIcons.plus_rectangle_on_rectangle,
      ),
      if (isViewer) ...[

        (
          action: PopMenuAction.adjustDate,
          label: 'Adjust the date and time',
          sfSymbol: 'calendar.badge.clock',
          cupertinoIcon: CupertinoIcons.calendar,
        ),
        (
          action: PopMenuAction.adjustLocation,
          label: 'Adjust the location',
          sfSymbol: 'mappin.circle',
          cupertinoIcon: CupertinoIcons.map_pin_ellipse,
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();

    if (isTablet) {
      return CNGlassButtonGroup(
        buttons: [
          CNButtonData.icon(
            icon: CNSymbol('slider.horizontal.3'),
            config: const CNButtonDataConfig(
              style: CNButtonStyle.prominentGlass,
              glassEffectUnionId: 'media-controls',
              glassEffectId: '',
              glassEffectInteractive: true,
            ),
            onPressed: () => viewerKey.currentState?.editMedia()
          ),
          CNButtonData.icon(
            icon: CNSymbol('info.circle'),
            config: const CNButtonDataConfig(
              style: CNButtonStyle.prominentGlass,
              glassEffectUnionId: 'media-controls',
              glassEffectId: '',
              glassEffectInteractive: true,
            ),
            onPressed: () async => viewerKey.currentState?.showOverlay(viewerKey.currentState!.alreadyPressed),
          ),
          CNButtonData.icon(
            icon: CNSymbol('trash', size: 22),
            config: const CNButtonDataConfig(
              style: CNButtonStyle.prominentGlass,
              glassEffectUnionId: 'media-controls',
              glassEffectId: '',
              glassEffectInteractive: true,
            ),
            onPressed: () => viewerKey.currentState?.deleteMedia()
          ),
          CNButtonData.popup(
            customIcon: CupertinoIcons.ellipsis,
            tint: Colors.white,
            config: CNButtonDataConfig(
              style: CNButtonStyle.prominentGlass,
              glassEffectUnionId: 'media-controls',
              glassEffectId: '',
              glassEffectInteractive: true,
            ),
            popupItems: entries
                .map((e) => CNButtonDataPopupItem(
                      label: e.label,
                      sfSymbol: e.sfSymbol,
                    ))
                .toList(),
            onMenuSelected: (index) {
              onSelected(entries[index].action);
            },
          ),
        ],
      );
    }

    if (is26OrNewer) {
      final items = entries
          .map<dynamic>((e) => CNPopupMenuItem(
                label: e.label,
                icon: CNSymbol(e.sfSymbol, size: 18),
              ))
          .toList();

      return CNPopupMenuButton.icon(
        size: 40,
        buttonIcon: CNSymbol('ellipsis', size: 15),
        items: items.cast(),
        onSelected: (index) {
          onSelected(entries[index].action);
        },
      );
    }

    return PullDownButton(
      itemBuilder: (context) => entries
          .map((e) => PullDownMenuItem(
                title: e.label,
                icon: e.cupertinoIcon,
                onTap: () => onSelected(e.action),
              ))
          .toList(),
      buttonBuilder: (context, showMenu) => CupertinoButton(
        onPressed: showMenu,
        padding: EdgeInsets.zero,
        child: Transform.scale(
          scale: scale,
          child: Button.iconOnly(
            icon: const Icon(CupertinoIcons.ellipsis, color: CupertinoColors.white),
            onPressed: showMenu,
          ),
        ),
      ),
    );
  }
}