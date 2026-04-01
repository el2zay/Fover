import 'dart:typed_data';


import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class PhotoEditorPage extends StatefulWidget {
  const PhotoEditorPage({super.key, required this.bytes});
  final Uint8List bytes;

  @override
  State<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<PhotoEditorPage> {
  late final _editorKey = GlobalKey<ProImageEditorState>();
  @override
  Widget build(BuildContext context) {
    return ProImageEditor.memory(
      widget.bytes,
      key: _editorKey,
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (bytes) async {
          Navigator.pop(context, bytes);
        },
        onCloseEditor: (_) => Navigator.pop(context),
      ),
      configs: ProImageEditorConfigs(
        designMode: ImageEditorDesignMode.cupertino,
        tuneEditor: TuneEditorConfigs(
          style: const TuneEditorStyle(
            background: Colors.black,
          ),
          widgets: TuneEditorWidgets(
            appBar: (tuneEditor, rebuildStream) => null,
            bodyItemsRecorded: (tuneEditor, rebuildStream) => [
              _buildSubAppBar(
                rebuildStream: rebuildStream, 
                onCancel: tuneEditor.close,
                onDone: tuneEditor.done
              )
            ]
          )
        ),
        filterEditor: FilterEditorConfigs(
          style: const FilterEditorStyle(
            background: Colors.black
          ),
          widgets: FilterEditorWidgets(
            appBar: (filterEditor, rebuildStream) => null,
            bodyItemsRecorded: (tuneEditor, rebuildStream) => [
              _buildSubAppBar(
                rebuildStream: rebuildStream, 
                onCancel: tuneEditor.close,
                onDone: tuneEditor.done
              )
            ]
          )
        ),
        cropRotateEditor: CropRotateEditorConfigs(
          style: const CropRotateEditorStyle(
            background: Colors.black
          ),
          widgets: CropRotateEditorWidgets(
            appBar: (cropRotateEditor, rebuildStream) => null,
            bodyItems:(tuneEditor, rebuildStream) => [
              _buildSubAppBar(
                rebuildStream: rebuildStream, 
                onCancel: tuneEditor.close,
                onDone: tuneEditor.done
              )
            ]
          )
        ),
        mainEditor: MainEditorConfigs(
          style: const MainEditorStyle(
            background: Color(0xFF0A0A0A),
          ),
          tools: [
            SubEditorMode.cropRotate,
            SubEditorMode.tune,
            SubEditorMode.filter,
          ],
          widgets: MainEditorWidgets(
            appBar: (editor, rebuildStream) => ReactiveAppbar(
              stream: rebuildStream,
              builder: (_) => AppBar(
                backgroundColor: Colors.black,
                centerTitle: true,
                leading: Transform.scale(
                  scale: 0.85,
                  child: Button.iconOnly(
                    
                    icon: const Icon(Icons.close, color: Colors.white, size: 18,),
                    glassIcon: CNSymbol('xmark', size: 18),
                    onPressed: editor.closeEditor,
                  ),
                ),
                title: CNGlassButtonGroup(
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
              ),
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
    );
  }

  Widget _toolBtn(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onTap,
          ),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  ReactiveWidget _buildSubAppBar({
    required Stream rebuildStream,
    required VoidCallback onCancel,
    required VoidCallback onDone
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
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  glassIcon: const CNSymbol('xmark', size: 18),
                  onPressed: onCancel
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