import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class FoverPickerDelegate extends DefaultAssetPickerBuilderDelegate<DefaultAssetPickerProvider> {
  
  // AI generated
  FoverPickerDelegate({
    required super.provider,
    required super.initialPermission,
  }) : super(
    textDelegate: const AssetPickerTextDelegate(),
    // specialPickerType: SpecialPickerType.noPreview
  );

  @override
  ThemeData get theme => ThemeData.dark().copyWith(
    // appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent),
    colorScheme: const ColorScheme.dark(primary: Colors.white),
  );

  @override
  Widget assetGridItemSemanticsBuilder(
    BuildContext context,
    int index,
    AssetEntity asset,
    Widget child,
    List<SpecialItemFinalized> specialItemsFinalized,
  ) {
    return GestureDetector(
      onTap: () => selectAsset(
        context,
        asset,
        index,
        provider.selectedAssets.contains(asset),
      ),
      child: child,
    );
  }


  @override
  Future<void> viewAsset(
    BuildContext context,
    int? index,
    AssetEntity currentAsset,
  ) async {
    selectAsset(
      context,
      currentAsset,
      index ?? 0,
      provider.selectedAssets.contains(currentAsset),
    );
  }


  // 

  @override
  Widget pathEntitySelector(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, __) {
        return GestureDetector(
          onTap: () => isSwitchingPath.value = !isSwitchingPath.value,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                provider.currentPath?.path.name ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 10),
              ValueListenableBuilder<bool>(
                valueListenable: isSwitchingPath,
                builder: (_, bool isSwitching, __) {
                  return AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: isSwitching ? -0.25 : 0,
                    child: const Icon(
                      CupertinoIcons.chevron_down,
                      color: Colors.white,
                      size: 18,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget selectedBackdrop(BuildContext context, int index, AssetEntity asset) {
    return ListenableBuilder(
      listenable: provider,
      builder: (_, __) {
        final selected = provider.selectedAssets.contains(asset);
        return IgnorePointer(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: selected
                ? Colors.black.withAlpha(50)
                : Colors.transparent,
          ),
        );
      },
    );
  }




  @override
  AssetPickerAppBar appBar(BuildContext context) {
    return AssetPickerAppBar(
      leading: Row(
        children: [
          SizedBox(width: 10),
          Button.iconOnly(
            icon: Icon(CupertinoIcons.xmark),
            glassIcon: CNSymbol('xmark', size: 16),
            backgroundColor: CupertinoColors.transparent,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      title: pathEntitySelector(context),
      actions: [
        ListenableBuilder(
          listenable: provider, 
          builder: (context, __) {
            return Button.iconOnly(
              icon: Icon(CupertinoIcons.check_mark, size: 20),
              glassIcon: CNSymbol('checkmark', size: 14, color: provider.selectedAssets.isNotEmpty ? Colors.white70 : Colors.white38),
              enabled: provider.selectedAssets.isNotEmpty,
              tint: Colors.blue,
              glassConfig: const CNButtonConfig(
                style: CNButtonStyle.prominentGlass
              ),
              onPressed: () {
                if (provider.selectedAssets.isEmpty) {
                  return;
                } else {
                  Navigator.pop(context, provider.selectedAssets);
                }
              }
            );
          }
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  @override
  Widget selectIndicator(BuildContext context, int index, AssetEntity asset) {
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: provider,
        builder: (context, __) {
          final selected = provider.selectedAssets.contains(asset);
          return Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? CupertinoColors.systemBlue : Colors.transparent,
                  border: Border.all(
                    color: selected ? CupertinoColors.white : CupertinoColors.transparent,
                    width: 2
                  )
                ),
                child: selected
                  ? const Icon(CupertinoIcons.checkmark, size: 12, color: Colors.white, fontWeight: FontWeight.w900,)
                  : null,
              ),
            ),
          );
        }
      )
    );
  }

  @override
  Widget bottomActionBar(BuildContext context) => const SizedBox();

}