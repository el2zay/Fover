import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fover/src/services/photo_store.dart' show PhotoStore;
import 'package:fover/src/utils/common_utils.dart';
import 'package:fover/src/widgets/button.dart';
import 'package:fover/src/widgets/container.dart';
import 'package:fover/src/widgets/dialog.dart';
import 'package:ios_color_picker/show_ios_color_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

class PhotoEditorPage extends StatefulWidget {
  const PhotoEditorPage({
    super.key,
    required this.bytes,
    required this.encodedPath,
    this.localVideoPath,
    this.isVideo = false,
  });

  final Uint8List bytes;
  final String encodedPath;
  final String? localVideoPath;
  final bool isVideo;

  @override
  State<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<PhotoEditorPage> {
  VideoPlayerController? _videoController;
  ProVideoController? _proVideoController;
  bool _isSeeking = false;
  TrimDurationSpan? _durationSpan;
  TrimDurationSpan? _tempSpan;
  late final _editorKey = GlobalKey<ProImageEditorState>();
  bool _didComplete = false;
  final _iosColorPickerController = IOSColorPickerController();
  Color _currentColor = Colors.white;
  int _currentTool = 0;
  PaintEditorState? _paintEditor;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _initVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _proVideoController?.dispose();
    _dismissToolOverlay();
    _iosColorPickerController.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    final tmpFile = File(widget.localVideoPath!);
    _videoController = VideoPlayerController.file(tmpFile);

    final meta = await ProVideoEditor.instance.getMetadata(
      EditorVideo.file(widget.localVideoPath!),
    );

    List<Uint8List> thumbs = [];
    try {
      thumbs = await ProVideoEditor.instance.getKeyFrames(
        KeyFramesConfigs(
          video: EditorVideo.file(widget.localVideoPath!),
          maxOutputFrames: 10,
          outputSize: const Size.square(80),
          outputFormat: ThumbnailFormat.webp,
        ),
      );
    } catch (e) {
      debugPrint('Thumbnail generation failed: $e');
    }

    await Future.wait([
      _videoController!.initialize(),
      _videoController!.setLooping(false),
    ]);

    _videoController!.addListener(_onTick);

    _proVideoController = ProVideoController(
      videoPlayer: _buildVideoWidget(),
      initialResolution: meta.resolution,
      videoDuration: meta.duration,
      fileSize: meta.fileSize,
      bitrate: meta.bitrate,
      thumbnails: thumbs
          .where((b) => b.isNotEmpty)
          .map((b) => MemoryImage(b))
          .toList(),
    );

    if (mounted) setState(() {});
  }

  void _onTick() {
    final pos = _videoController!.value.position;
    _proVideoController?.setPlayTime(pos);
    if (_durationSpan != null && pos >= _durationSpan!.end) {
      _seekTo(_durationSpan!);
    }
  }

  Future<void> _seekTo(TrimDurationSpan span) async {
    _durationSpan = span;
    if (_isSeeking) {
      _tempSpan = span;
      return;
    }
    _isSeeking = true;
    _proVideoController!.pause();
    await _videoController!.seekTo(span.start);
    _isSeeking = false;
    if (_tempSpan != null) {
      final next = _tempSpan!;
      _tempSpan = null;
      await _seekTo(next);
    }
  }

  Widget _buildVideoWidget() => Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );

  String _buildEditedName(String name) {
    final hasExt = name.contains('.');
    final base = hasExt ? name.substring(0, name.lastIndexOf('.')) : name;
    final ext = hasExt ? '.${name.split('.').last}' : '';
    return '${base}_edited_${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  String _extractFolder(String encodedPath) {
    if (detectBackend() == ServerBackend.freebox) {
      final decoded = utf8.decode(base64.decode(encodedPath));
      final folder = decoded.substring(0, decoded.lastIndexOf('/'));
      return base64.encode(utf8.encode(folder));
    } else {
      return base64.encode(utf8.encode("/photos"));
    }
  }

  void applyPenStyle(PaintEditorState editor) {
    editor.setMode(PaintMode.freeStyle);
    editor.setStrokeWidth(3.0);
    editor.setOpacity(1.0);
    setState(() => _currentTool = 0);

  }

  void applyCrayonStyle(PaintEditorState editor) {
    editor.setMode(PaintMode.freeStyle);
    editor.setStrokeWidth(5.0);
    editor.setOpacity(0.75);
    setState(() => _currentTool = 1);
  }

    void applyMarkerStyle(PaintEditorState editor) {
    editor.setMode(PaintMode.freeStyle);
    editor.setStrokeWidth(18.0);
    editor.setOpacity(0.45);
    setState(() => _currentTool = 2);
  }

  OverlayEntry? _toolOverlay;
  final _penKey = GlobalKey();
  final _crayonKey = GlobalKey();
  final _markerKey = GlobalKey();
  final _eraserKey = GlobalKey();

  int _penSizeIndex = 0;
  int _crayonSizeIndex = 0;
  int _markerSizeIndex = 0;
  int _eraserSizeIndex = 0;

  void _dismissToolOverlay() {
    _toolOverlay?.remove();
    _toolOverlay = null;
  }

  void _showStrokePicker({
    required GlobalKey key,
    required PaintEditorState paintEditor,
    required List<double> sizes,
    required int selectedIndex,
    required void Function(double size, int index) onSelected,
  }) {
    _dismissToolOverlay();

    final box = key.currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final btnWidth = box.size.width;

    _toolOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissToolOverlay,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: (offset.dx + btnWidth / 2) - (sizes.length * 30.0) / 2,
            top: offset.dy - 75,
            child: Listener(
              onPointerDown: (_) {},
              behavior: HitTestBehavior.opaque,
              child: Material(
                color: Colors.transparent,
                child: MyContainer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(sizes.length, (i) {
                        final s = sizes[i];
                        final isSelected = i == selectedIndex;
                        return GestureDetector(
                          onTap: () {
                            onSelected(s, i);
                            _toolOverlay?.markNeedsBuild();
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 7),
                            height: s,
                            width: s,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.white54,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_toolOverlay!);
  }



  @override
  Widget build(BuildContext context) {
    if (widget.isVideo && _proVideoController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final configs = ProImageEditorConfigs(
      designMode: ImageEditorDesignMode.cupertino,
      dialogConfigs: DialogConfigs(
        widgets: DialogWidgets(
          loadingDialog: (message, configs) => MyDialog(
            content: message,
            needCancel: false,
            principalButton: null,
          ),
        ),
      ),
      mainEditor: MainEditorConfigs(
        tools: [
          SubEditorMode.cropRotate,
          SubEditorMode.tune,
          SubEditorMode.filter,
          SubEditorMode.paint
        ],
        widgets: MainEditorWidgets(
          closeWarningDialog: (editor) async => true,
          appBar: (editor, rebuildStream) => ReactiveAppbar(
            stream: rebuildStream,
            builder: (_) => AppBar(
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
                        CNPopupMenuItem(label: "Discard Changes"),
                      ],
                      onSelected: (selected) {
                        if (selected == 1) editor.closeEditor();
                      },
                    )
                  : Transform.scale(
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
                  glassConfig: CNButtonConfig(style: CNButtonStyle.prominentGlass),
                  icon: const Icon(Icons.check, color: Colors.white, size: 16),
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
              constraints: const BoxConstraints(maxHeight: 100, minHeight: 100),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _toolBtn(context, CupertinoIcons.dial, 'Adjust', editor.openTuneEditor),
                      _toolBtn(context, CupertinoIcons.color_filter, 'Filters', editor.openFilterEditor),
                      _toolBtn(context, CupertinoIcons.pencil, 'Markup', editor.openPaintEditor),
                      _toolBtn(context, CupertinoIcons.crop_rotate, 'Crop', editor.openCropRotateEditor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      tuneEditor: TuneEditorConfigs(
        style: TuneEditorStyle(
          background: Theme.of(context).scaffoldBackgroundColor,
        ),
        widgets: TuneEditorWidgets(
          appBar: (tuneEditor, rebuildStream) => ReactiveAppbar(
            stream: rebuildStream,
            builder: (_) => PreferredSize(
              preferredSize: Size.zero,
              child: const SizedBox.shrink(),
            ),
          ),
          slider: (editorState, rebuildStream, value, onChanged, onChangeEnd) =>
              ReactiveWidget(
            builder: (context) => const SizedBox(),
            stream: rebuildStream,
          ),
          bodyItems: (tuneEditor, rebuildStream) => [
            _buildSubAppBar(
              rebuildStream: rebuildStream,
              onCancel: tuneEditor.close,
              onDone: tuneEditor.done,
            ),
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
                  constraints: const BoxConstraints(maxHeight: 115, minHeight: 115),
                  child: Column(
                    children: [
                      const SizedBox(height: 15),
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
                          children: List.generate(
                            tuneEditor.tuneAdjustmentList.length - 1,
                            (i) {
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
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      filterEditor: FilterEditorConfigs(
        style: FilterEditorStyle(
          background: Theme.of(context).scaffoldBackgroundColor,
        ),
        widgets: FilterEditorWidgets(
          appBar: (filterEditor, rebuildStream) => ReactiveAppbar(
            stream: rebuildStream,
            builder: (_) => PreferredSize(
              preferredSize: Size.zero,
              child: const SizedBox.shrink(),
            ),
          ),
          slider: (editorState, rebuildStream, value, onChanged, onChangeEnd) =>
              ReactiveWidget(
            stream: rebuildStream,
            builder: (_) => Padding(
              padding: const EdgeInsetsGeometry.symmetric(horizontal: 20),
              child: CNSlider(value: value, onChanged: onChanged),
            ),
          ),
          bodyItems: (filterEditor, rebuildStream) => [
            _buildSubAppBar(
              rebuildStream: rebuildStream,
              onCancel: filterEditor.close,
              onDone: filterEditor.done,
            ),
          ],
        ),
      ),
      paintEditor: PaintEditorConfigs(
        eraserSize: 15,
        style: PaintEditorStyle(
          background: Theme.of(context).scaffoldBackgroundColor,
          bottomBarBackground: Colors.transparent,
        ),
        widgets: PaintEditorWidgets(
          colorPicker: (editorState, rebuildStream, currentColor, setColor) => ReactiveWidget(
            stream: rebuildStream,
            builder: (_) => SizedBox()
          ),
          appBar: (paintEditor, rebuildStream) => ReactiveAppbar(
            stream: rebuildStream,
            builder: (_) => PreferredSize(
              preferredSize: Size.zero,
              child: const SizedBox.shrink(),
            ),
          ),
          bottomBar: (_, rebuildStream) => ReactiveWidget(
            stream: rebuildStream,
            builder: (_) => const SizedBox.shrink(),
          ),
          bodyItems: (paintEditor, rebuildStream) {
            _paintEditor = paintEditor;
            const _penSizes    = [2.0, 4.0, 6.0, 9.0, 13.0];
            const _crayonSizes = [3.0, 5.0, 8.0, 12.0, 16.0];
            const _markerSizes = [10.0, 16.0, 22.0, 30.0, 40.0];
            const _eraserSizes = [15.0, 20.0, 28.0, 36.0, 46.0];
            return [
              _buildSubAppBar(
                rebuildStream: rebuildStream,
                onCancel: paintEditor.close,
                onDone: paintEditor.done,
                editor: paintEditor,
              ),
              ReactiveWidget(
                stream: rebuildStream,
                builder: (_) => Positioned(
                  bottom: 0, 
                  left: 0, 
                  right: 0,
                  child: SafeArea(
                    child: Container(
                      color: Colors.black.withAlpha(120),
                      padding: EdgeInsetsGeometry.symmetric(horizontal: 30, vertical: 5),
                      child: MyContainer(
                        child: Padding(
                          padding: EdgeInsetsGeometry.only(top: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                key: _penKey,
                                onTap: () {
                                  applyPenStyle(paintEditor);
                                  paintEditor.setStrokeWidth(_penSizes[_penSizeIndex]);
                                },
                                onLongPress: () => _showStrokePicker(
                                  key: _penKey,
                                  paintEditor: paintEditor,
                                  sizes: const [10, 14, 18, 22, 26],
                                  selectedIndex: _penSizeIndex,
                                  onSelected: (s, i) {
                                    setState(() => _penSizeIndex = i);
                                    applyPenStyle(paintEditor);
                                    paintEditor.setStrokeWidth(_penSizes[i]);
                                    _dismissToolOverlay();
                                  },
                                ),
                                child: Image.asset(
                                  "assets/icons/editor/pen.png",
                                  height: _currentTool == 0 ? 60 : 50,
                                ),
                              ),
                              GestureDetector(
                                key: _crayonKey,
                                onTap: () {
                                  applyCrayonStyle(paintEditor);
                                  paintEditor.setStrokeWidth(_crayonSizes[_crayonSizeIndex]);
                                },
                                onLongPress: () => _showStrokePicker(
                                  key: _crayonKey, 
                                  paintEditor: paintEditor, 
                                  sizes: const [10, 14, 18, 22, 26],
                                  selectedIndex: _crayonSizeIndex, 
                                  onSelected: (size, index) {
                                    setState(() => _crayonSizeIndex = index);
                                    applyCrayonStyle(paintEditor);
                                    paintEditor.setStrokeWidth(_crayonSizes[index]);
                                  }
                                ),
                                child: Image.asset(
                                  "assets/icons/editor/crayon.png",
                                  height: _currentTool == 1 ? 60 : 50,
                                ),
                              ),
                              GestureDetector(
                                key: _markerKey,
                                onTap: () {
                                  applyMarkerStyle(paintEditor);
                                  paintEditor.setStrokeWidth(_markerSizes[_markerSizeIndex]);
                                },
                                onLongPress: () =>  _showStrokePicker(
                                  key: _markerKey,
                                  paintEditor: paintEditor,
                                  sizes: const [10, 14, 18, 22, 26],
                                  selectedIndex: _markerSizeIndex,
                                  onSelected: (s, i) {
                                    setState(() => _markerSizeIndex = i);
                                    applyMarkerStyle(paintEditor);
                                    paintEditor.setStrokeWidth(_markerSizes[i]);
                                    _dismissToolOverlay();
                                  },
                                ),
                                child: Image.asset(
                                  "assets/icons/editor/marker.png",
                                  height: _currentTool == 2 ? 60 : 50,
                                ),
                              ),
                              GestureDetector(
                                key: _eraserKey,
                                onTap: () => paintEditor.setMode(PaintMode.eraser),
                                onLongPress: () => _showStrokePicker(
                                  key: _eraserKey,
                                  paintEditor: paintEditor,
                                  sizes: const [10, 14, 18, 22, 26],
                                  selectedIndex: _eraserSizeIndex,
                                  onSelected: (s, i) {
                                    setState(() => _eraserSizeIndex = i);
                                    paintEditor.setMode(PaintMode.eraser);
                                    paintEditor.eraserRadius = _eraserSizes[i] / 2;
                                    _dismissToolOverlay();
                                  },
                                ),
                                child: Image.asset(
                                  "assets/icons/editor/eraser.png",
                                  height: PaintMode.values.indexOf(paintEditor.paintMode) == PaintMode.eraser.index ? 55 : 50,
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      _iosColorPickerController.showNativeIosColorPicker(
                                        startingColor: _currentColor,
                                        darkMode: Theme.of(context).brightness == Brightness.dark,
                                        onColorChanged: (color) {
                                          setState(() => _currentColor = color);
                                          paintEditor.setColor(color);
                                        }
                                      );
                                    },
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          height: 28,
                                          width: 28,
                                          decoration: BoxDecoration(
                                            gradient: SweepGradient(
                                              transform: GradientRotation(-pi / 2),
                                              colors: [
                                                Colors.yellow,
                                                Colors.orange,
                                                Colors.red,
                                                Colors.pink,
                                                Colors.purple,
                                                Colors.blue,
                                                Colors.green,
                                                Colors.yellow
                                              ]
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Container(
                                          height: 19,
                                          width: 19,
                                          decoration: BoxDecoration(
                                            color: _currentColor,
                                            boxShadow: [
                                              BoxShadow(
                                                spreadRadius: 0.8,
                                                color: Colors.black
                                              )
                                            ],
                                            shape: BoxShape.circle
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 15),
                                  CupertinoButton.tinted(
                                    sizeStyle: CupertinoButtonSize.small,
                                    padding: EdgeInsets.all(5),
                                    borderRadius: BorderRadius.all(Radius.circular(30)),
                                    child: Icon(
                                      CupertinoIcons.plus, 
                                      size: 22,
                                      color: Theme.of(context).primaryColor,
                                    ), 
                                    onPressed: () {}
                                  ),
                                ],
                              )
                            ],
                          )
                        ),
                      )
                    ),
                  ),
                ),
              ),
            ];
          }
        ),
      ),
      cropRotateEditor: CropRotateEditorConfigs(
        style: CropRotateEditorStyle(
          cropCornerColor: Colors.white,
          cropCornerLength: 20,
          cropCornerThickness: 4,
          background: Theme.of(context).scaffoldBackgroundColor,
        ),
        widgets: CropRotateEditorWidgets(
          appBar: (cropRotateEditor, rebuildStream) => null,
          bodyItems: (cropRotateEditor, rebuildStream) => [
            _buildSubAppBar(
              rebuildStream: rebuildStream,
              onCancel: cropRotateEditor.close,
              onDone: cropRotateEditor.done,
              editor: cropRotateEditor,
            ),
          ],
        ),
      ),
      videoEditor: const VideoEditorConfigs(
        minTrimDuration: Duration(seconds: 2),
        animatedIndicatorDuration: Duration(milliseconds: 200),
        controlsPosition: VideoEditorControlPosition.bottom
      ),
    );

    final callbacks = ProImageEditorCallbacks(
      onCloseEditor: (_) {
        if (!_didComplete) Navigator.pop(context);
      },
      onImageEditingComplete: widget.isVideo ? null : (editedBytes) async {
        final originalPhoto = PhotoStore.get(widget.encodedPath)!;
        final folder = _extractFolder(widget.encodedPath);
        final filename = _buildEditedName(originalPhoto.name);
        final navigator = Navigator.of(context);

        final newPath = await PhotoStore.uploadEditedPhoto(
          bytes: editedBytes,
          filename: filename,
          folderEncodedPath: folder,
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
      onCompleteWithParameters: !widget.isVideo ? null : (result) async {
        final originalPhoto = PhotoStore.get(widget.encodedPath)!;
        final folder = _extractFolder(widget.encodedPath);
        final filename = _buildEditedName(originalPhoto.name);
        final navigator = Navigator.of(context);

        final data = VideoRenderData(
          videoSegments: [
            VideoSegment(
              video: EditorVideo.file(widget.localVideoPath!),
              startTime: result.startTime,
              endTime: result.endTime,
            ),
          ],
          colorFilters: result.colorFiltersCombined.isEmpty
              ? []
              : [ColorFilter(matrix: result.colorFiltersCombined)],
        );

        final dir = await getTemporaryDirectory();
        final out = '${dir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.mp4';
        await ProVideoEditor.instance.renderVideoToFile(out, data);

        final editedBytes = await File(out).readAsBytes();

        final newPath = await PhotoStore.uploadEditedPhoto(
          bytes: editedBytes,
          filename: filename,
          folderEncodedPath: folder,
        );

        if (newPath == null) return;

        await PhotoStore.update(path: widget.encodedPath, isOldVersion: true);
        await PhotoStore.addPhoto(
          path: newPath,
          name: filename,
          date: originalPhoto.date,
          size: editedBytes.length,
          mimetype: originalPhoto.mimetype ?? 'video/mp4',
          displayDate: originalPhoto.displayDate,
          editedFrom: widget.encodedPath,
          width: originalPhoto.width,
          height: originalPhoto.height,
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

        try { await File(out).delete(); } catch (_) {}

        if (!mounted) return;
        _didComplete = true;
        navigator.pop(newPath);
      },
      videoEditorCallbacks: !widget.isVideo
        ? null
        : VideoEditorCallbacks(
            onPause: _videoController!.pause,
            onPlay: _videoController!.play,
            onMuteToggle: (isMuted) => _videoController!.setVolume(isMuted ? 0 : 1),
            onTrimSpanUpdate: (_) {
              if (_videoController!.value.isPlaying) _proVideoController!.pause();
            },
            onTrimSpanEnd: _seekTo,
          ),

      paintEditorCallbacks: PaintEditorCallbacks(
        onInit: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_paintEditor != null) { 
              applyPenStyle(_paintEditor!);
              _paintEditor!.setColor(_currentColor);
              setState(() => _currentTool = 0);
            }
          });
        },
      ),
    );

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: widget.isVideo
          ? ProImageEditor.video(
              _proVideoController!,
              callbacks: callbacks,
              configs: configs,
            )
          : ProImageEditor.memory(
              widget.bytes,
              key: _editorKey,
              callbacks: callbacks,
              configs: configs,
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
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).primaryColor.withAlpha(180),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  ReactiveWidget _buildSubAppBar({
    required Stream rebuildStream,
    required VoidCallback onCancel,
    required VoidCallback onDone,
    dynamic editor,
  }) {
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
                  onPressed: onCancel,
                ),
                if (editor != null)
                  CNGlassButtonGroup(
                    axis: Axis.horizontal,
                    spacing: 5.0,
                    buttons: [
                      CNButtonData.icon(
                        icon: CNSymbol('arrow.uturn.backward', size: 20,
                            color: !editor.canUndo ? Colors.grey : null),
                        onPressed: editor.canUndo ? editor.undoAction : null,
                        config: const CNButtonDataConfig(
                          style: CNButtonStyle.prominentGlass,
                          glassEffectUnionId: 'undo-redo',
                          glassEffectId: 'undo',
                          glassEffectInteractive: true,
                        ),
                      ),
                      CNButtonData.icon(
                        icon: CNSymbol('arrow.uturn.forward', size: 20,
                            color: !editor.canRedo ? Colors.grey : null),
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
                  onPressed: onDone,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int _selectedIndex = 0;
class _EraserSizePicker extends StatelessWidget {
  const _EraserSizePicker({required this.onSizeSelected});
  final ValueChanged<double> onSizeSelected;
  @override
  Widget build(BuildContext context) {
    return MyContainer(
      child: Padding(
        padding: EdgeInsetsGeometry.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          children: [
            // Text(
            //   "Eraser Size",
            //   style: TextStyle(
            //     color: Colors.white,
            //     fontSize: 16,
            //     fontWeight: FontWeight.bold,
            //   ),
            // ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 14,
              children: List.generate(5, (i) {
                final size = 15 + i * 4.0;
                return GestureDetector(
                  onTap: () { 
                    onSizeSelected(size);
                    _selectedIndex = i;
                  },
                  child: Container(
                    height: size,
                    width: size,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == _selectedIndex ? Colors.white : Colors.white54,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}