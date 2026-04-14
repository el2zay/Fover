import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;


import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/src/services/photo_store.dart' show PhotoStore;
import 'package:fover/src/utils/common_utils.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:fover/src/widgets/dialog.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class PhotoEditorPage extends StatefulWidget {
  const PhotoEditorPage({super.key, required this.bytes, required this.encodedPath});
  final Uint8List bytes;
  final String encodedPath;

  @override
  State<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<PhotoEditorPage> {
  late final _editorKey = GlobalKey<ProImageEditorState>();
  bool _didComplete = false;
  String _buildEditedName(String name) {
    final hasExt = name.contains('.');
    final base = hasExt ? name.substring(0, name.lastIndexOf('.')) : name;
    final ext  = hasExt ? '.${name.split('.').last}' : '';
    return '${base}_edited_${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  String _extractFolder(String encodedPath) {
    if (detectBackend() == ServerBackend.freebox) {
      final decoded = utf8.decode(base64.decode(encodedPath));
      final folder  = decoded.substring(0, decoded.lastIndexOf('/'));
      return base64.encode(utf8.encode(folder));
    } else {
      return base64.encode(utf8.encode("/photos"));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ProImageEditor.memory(
        widget.bytes,
        key: _editorKey,
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (editedBytes) async {
            final originalPhoto = PhotoStore.get(widget.encodedPath)!;
            final folder = _extractFolder(widget.encodedPath);
            final filename = _buildEditedName(originalPhoto.name);
            final navigator = Navigator.of(context);
            final newPath = await PhotoStore.uploadEditedPhoto(
              bytes: editedBytes,
              filename: filename,
              folderEncodedPath: folder
            );

            final codec = await ui.instantiateImageCodec(editedBytes);
            final frame = await codec.getNextFrame();
            final editedWidth = frame.image.width;
            final editedHeight = frame.image.height;
            frame.image.dispose();

            if (newPath == null) return;

            await PhotoStore.update(path: widget.encodedPath, isOldVersion: true);

            await PhotoStore.addPhoto(
              path: newPath, 
              name: filename, 
              date: originalPhoto.date,
              size: editedBytes.length, 
              mimetype: originalPhoto.mimetype ?? 'image/jpeg',
              displayDate: originalPhoto.displayDate,
              editedFrom: widget.encodedPath,
              width: editedWidth,
              height: editedHeight,
              cameraBrand: originalPhoto.cameraBrand,
              cameraModel: originalPhoto.cameraModel,
              iso: originalPhoto.iso,
              focalLength: originalPhoto.focalLength,
              exposureValue: originalPhoto.exposureValue,
              focus: originalPhoto.focus,
              shutterSpeed: originalPhoto.shutterSpeed,
              latitude: originalPhoto.latitude,
              longitude: originalPhoto.longitude,
            );
            if (!mounted) return;
            _didComplete = true;
            navigator.pop(newPath);
          },
          onCloseEditor: (_) {
            if (!_didComplete) Navigator.pop(context);
          }
        ),
        configs: ProImageEditorConfigs(
          designMode: ImageEditorDesignMode.cupertino,
          dialogConfigs: DialogConfigs(
            widgets: DialogWidgets(
              loadingDialog: (message, configs) {
                return MyDialog(
                  content: message,
                  needCancel: false,
                  principalButton: null,
                );
              },
            )
          ),
          videoEditor: VideoEditorConfigs(
          ),
          tuneEditor: TuneEditorConfigs(
            style: TuneEditorStyle(
              background: Theme.of(context).scaffoldBackgroundColor,
            ),
            widgets: TuneEditorWidgets(
              appBar: (tuneEditor, rebuildStream) => ReactiveAppbar(
                stream: rebuildStream,
                builder: (_) => PreferredSize(preferredSize: Size.zero, child: const SizedBox.shrink()),
              ),
              slider: (editorState, rebuildStream, value, onChanged, onChangeEnd) => ReactiveWidget(builder: (context) => SizedBox(), stream: rebuildStream),
              bodyItems: (tuneEditor, rebuildStream) => [
                _buildSubAppBar(
                  rebuildStream: rebuildStream, 
                  onCancel: tuneEditor.close,
                  onDone: tuneEditor.done,
                )
              ],
              bottomBar: (tuneEditor, rebuildStream) => ReactiveWidget(
                stream: rebuildStream,  
                builder: (context) {
                  final selected = tuneEditor.tuneAdjustmentList[tuneEditor.selectedIndex];
                  final sliderValue = ValueNotifier<double>(
                    tuneEditor.tuneAdjustmentMatrix[tuneEditor.selectedIndex].value,
                  );
                  return SafeArea(
                    child: Container(
                    constraints: BoxConstraints(
                      maxHeight: 115,
                      minHeight: 115
                    ),
                    child: Column(
                        children: [
                          SizedBox(height: 15),
                          SizedBox(
                            height: 40,
                            child: ValueListenableBuilder<double>(
                              valueListenable: sliderValue,
                              builder: (_, value, __) => CNSlider(
                                min: selected.min,
                                max: selected.max,
                                value: value,
                                onChanged: (val) {
                                  sliderValue.value = val;
                                  tuneEditor.onChanged(val);
                                },
                              ),
                            ),
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: List.generate(tuneEditor.tuneAdjustmentList.length - 1, (i) {

                              final item = tuneEditor.tuneAdjustmentList[i];
                              final isSelected = tuneEditor.selectedIndex == i;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    tuneEditor.selectedIndex = i;
                                    tuneEditor.uiStream.add(null);
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _tuneIcon(i),
                                        size: 24, 
                                        color: isSelected ? Colors.white : Colors.white54,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.label,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white54,
                                          fontSize: 11,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              );
                              })
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          ),
          filterEditor: FilterEditorConfigs(
            style: FilterEditorStyle(
              background: Theme.of(context).scaffoldBackgroundColor
            ),
            widgets: FilterEditorWidgets(
              appBar: (filterEditor, rebuildStream) => ReactiveAppbar(
                stream: rebuildStream,
                builder: (_) => PreferredSize(preferredSize: Size.zero, child: const SizedBox.shrink()),
              ),
              slider: (editorState, rebuildStream, value, onChanged, onChangeEnd) => ReactiveWidget(
                stream: rebuildStream,
                builder: (_) => Padding(
                  padding: const EdgeInsetsGeometry.symmetric(horizontal: 20),
                  child: CNSlider(
                    value: value, 
                    onChanged: onChanged,
                  ),
                ),
              ),
              bodyItems: (filterEditor, rebuildStream) => [
                _buildSubAppBar(
                  rebuildStream: rebuildStream, 
                  onCancel: filterEditor.close,
                  onDone: filterEditor.done,
                )
              ]
            )
          ),
          cropRotateEditor: CropRotateEditorConfigs(
            style: CropRotateEditorStyle(
              cropCornerColor: Colors.white,
              cropCornerLength: 20,
              cropCornerThickness: 4,
              background: Theme.of(context).scaffoldBackgroundColor
            ),
            widgets: CropRotateEditorWidgets(
              appBar: (cropRotateEditor, rebuildStream) => null,
              bodyItems:(cropRotateEditor, rebuildStream) => [
                _buildSubAppBar(
                  rebuildStream: rebuildStream, 
                  onCancel: cropRotateEditor.close,
                  onDone: cropRotateEditor.done,
                  editor: cropRotateEditor,
                )
              ]
            )
          ),
          mainEditor: MainEditorConfigs(
            style: MainEditorStyle(
              background: Theme.of(context).scaffoldBackgroundColor,
            ),
            tools: [
              SubEditorMode.cropRotate,
              SubEditorMode.tune,
              SubEditorMode.filter,
            ],
            
            widgets: MainEditorWidgets(
              closeWarningDialog: (editor) async => true,
              
              appBar: (editor, rebuildStream) => ReactiveAppbar(
                stream: rebuildStream,
                builder: (_) => 
                // si il y a eu des modification
                AppBar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  centerTitle: true,
                  leading: editor.canUndo 
                    ? CNPopupMenuButton.icon(
                      buttonIcon: CNSymbol("xmark", size: 16),
                      items: [
                        CNPopupMenuItem(
                          enabled: false,
                          label: "Are you sure you want to discard your changes?",
                        ),
                        CNPopupMenuItem(label: "Discard Changes")
                      ],
                      onSelected: (selected) {
                        if (selected == 1) {
                          editor.closeEditor();
                        }
                      }
                    ) : Transform.scale(
                      scale: 0.9,
                      child: Button.iconOnly(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        glassIcon: const CNSymbol('xmark', size: 18),
                        onPressed: editor.closeEditor,
                      ),
                    ),
                  title: CNGlassButtonGroup(
                    axis: Axis.horizontal,
                    spacing: 5.0,
                    buttons: [
                      CNButtonData.icon(
                        enabled: !editor.isSubEditorOpen,
                        icon: CNSymbol('arrow.uturn.backward', size: 20, color: !editor.canUndo ? Colors.grey : null),
                        onPressed: editor.canUndo ? editor.undoAction : null,
                        config: const CNButtonDataConfig(
                          style: CNButtonStyle.prominentGlass,
                          glassEffectUnionId: 'undo-redo',
                          glassEffectId: 'undo',
                          glassEffectInteractive: true,
                        ),
                      ),
                      CNButtonData.icon(
                        enabled: !editor.isSubEditorOpen,
                        icon: CNSymbol('arrow.uturn.forward', size: 20, color: !editor.canRedo ? Colors.grey : null),
                        onPressed: editor.canRedo ? editor.redoAction : null,
                        config: const CNButtonDataConfig(
                          style: CNButtonStyle.prominentGlass,
                          glassEffectUnionId: 'undo-redo',
                          glassEffectId: 'redo',
                          glassEffectInteractive: true,
                        ),
                      ),
                    ],
                  ), 
                  actions: [
                    Button.iconOnly(
                      tint: Colors.blue,
                      backgroundColor: Colors.blue,
                      glassConfig: CNButtonConfig(
                        style: CNButtonStyle.prominentGlass
                      ),
                      icon: const Icon(Icons.check, color: Colors.white, size: 16,),
                      glassIcon: CNSymbol('checkmark', size: 16),
                      onPressed: editor.doneEditing,
                    ),
                    const SizedBox(width: 8),
                  ],
                )
              ),
              bottomBar: (editor, rebuildStream, key) => ReactiveWidget(
                key: key,
                stream: rebuildStream,
                builder: (_) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 100,
                    minHeight: 100
                  ),
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.6
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _toolBtn(context, CupertinoIcons.dial, 'Adjust', editor.openTuneEditor),
                          _toolBtn(context, CupertinoIcons.color_filter, 'Filters', editor.openFilterEditor),
                          _toolBtn(context,  CupertinoIcons.crop_rotate, 'Crop', editor.openCropRotateEditor),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _tuneIcon(int index) {
    const icons = [
      CupertinoIcons.sun_max,
      CupertinoIcons.circle_lefthalf_fill, 
      CupertinoIcons.drop,
      CupertinoIcons.plus_slash_minus,
      CupertinoIcons.triangle,
      CupertinoIcons.thermometer,
      // Material icon right-triangle
      CupertinoIcons.triangle_fill,
      CupertinoIcons.lightbulb,
    ];
    return icons[index];
  }

  Widget _toolBtn(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(icon, color: Theme.of(context).primaryColor),
            onPressed: onTap,
          ),
          Text(label, style: TextStyle(color: Theme.of(context).primaryColor.withAlpha(180), fontSize: 13)),
        ],
      ),
    );
  }

  ReactiveWidget _buildSubAppBar({
    required Stream rebuildStream,
    required VoidCallback onCancel,
    required VoidCallback onDone,
    dynamic editor,
  })  {
    return ReactiveWidget(
      stream: rebuildStream,
      builder: (_) => Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Button.iconOnly(
                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                  glassIcon: const CNSymbol('xmark', size: 16),
                  onPressed: onCancel
                ),
                if (editor != null)
                  CNGlassButtonGroup(
                      axis: Axis.horizontal,
                      spacing: 5.0,
                      buttons: [
                      CNButtonData.icon(
                        icon: CNSymbol('arrow.uturn.backward', size: 20, color: !editor.canUndo ? Colors.grey : null),
                        onPressed: editor.canUndo ? editor.undoAction : null,
                        config: const CNButtonDataConfig(
                          style: CNButtonStyle.prominentGlass,
                          glassEffectUnionId: 'undo-redo',
                          glassEffectId: 'undo',
                          glassEffectInteractive: true,
                        ),
                      ),
                      CNButtonData.icon(
                        icon: CNSymbol('arrow.uturn.forward', size: 20, color: !editor.canRedo ? Colors.grey : null),
                        onPressed: editor.canRedo ? editor.redoAction : null,
                        config: const CNButtonDataConfig(
                          style: CNButtonStyle.prominentGlass,
                          glassEffectUnionId: 'undo-redo',
                          glassEffectId: 'redo',
                          glassEffectInteractive: true,
                        ),
                      ),
                    ],
                  ),
                Button.iconOnly(
                  tint: Colors.blue,
                  backgroundColor: Colors.blue,
                  glassConfig: CNButtonConfig(style: CNButtonStyle.prominentGlass),
                  icon: const Icon(Icons.check, color: Colors.white, size: 16),
                  glassIcon: const CNSymbol('checkmark', size: 16),
                  onPressed: onDone
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}