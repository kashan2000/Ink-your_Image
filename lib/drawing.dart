import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'drawing/drawn_line.dart';
import 'drawing/sketcher.dart';
import 'helpers.dart';

late final MyHelper h;

const BACKGROUND_COLOR = Colors.white;

class DrawingPage extends StatefulWidget {
  const DrawingPage({this.background, this.prevDrawing, Key? key})
      : super(key: key);
  final String? background;
  final String? prevDrawing;

  @override
  DrawingPageState createState() => DrawingPageState();
}

// const _zoomScaleMin = 0.1;
// const _zoomScaleMax = 3.0;

class DrawingPageState extends State<DrawingPage> {
  final _globalKey = GlobalKey();
  final _transformationController = TransformationController();
  var _selectedColor = Colors.black;
  var _selectedWidth = 5.0;
  var _lines = <dynamic>[];
  var _isAddText = false;
  var _isEraser = false;
  var _isPan = false;
  var _startPoint = const Offset(0, 0);
  var _startX = 0.0;
  var _startY = 0.0;
  var _currentZoom = 1.0;
  var _zoom = 1.0;
  DrawnLine? _line;
  DrawnText? _text;
  ui.Image? _background;
  ui.Image? _prevDrawing;

  final linesStreamController = StreamController<List<dynamic>>.broadcast();
  final currentLineStreamController = StreamController<dynamic>.broadcast();

  Color get _lineColor => _isEraser ? Colors.white : _selectedColor;

  _save() async {
    try {
      // capture
      final boundary = _globalKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final screenshot = byteData?.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

      if (mounted) Navigator.pop(context, screenshot);
    } catch (e) {}
  }

  double get _currentPanX => _transformationController.value.getTranslation().x;
  double get _currentPanY => _transformationController.value.getTranslation().y;
  bool get _isDrawText => _isAddText && _text != null;

  // Future<ui.Image> loadUiAssetImage(String assetPath) async {
  //   final data = await rootBundle.load(assetPath);
  //   final list = Uint8List.view(data.buffer);
  //   final completer = Completer<ui.Image>();
  //   ui.decodeImageFromList(list, completer.complete);
  //   return completer.future;
  // }

  // Future<ui.Image> loadUiUploadedImage(File imageFile) async {
  //   final data = await imageFile.openRead().toBytes();
  //   final completer = Completer<ui.Image>();
  //   ui.decodeImageFromList(data, completer.complete);
  //   return completer.future;
  // }

  Future<ui.Image?> loadUiNetworkImage(String? url) async {
    if (url == null) return null;
    final http.Response response = await http.get(Uri.parse(url));
    final list = response.bodyBytes;
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(list, completer.complete);
    return completer.future;
  }

  @override
  void initState() {
    final backgroundUrl = widget.background;

    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (backgroundUrl != null)
        _background = await loadUiNetworkImage(backgroundUrl);

      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Scaffold(
        backgroundColor: BACKGROUND_COLOR,
        body: SafeArea(
          child: Stack(
            children: [
              InteractiveViewer(
                transformationController: _transformationController,
                onInteractionStart: (scaleDetails) {
                  if (_isPan || _isDrawText) {
                    _startPoint = scaleDetails.focalPoint;
                    _startX = _currentPanX;
                    _startY = _currentPanY;
                    return;
                  }
                  final box = context.findRenderObject() as RenderBox;
                  final point = box.globalToLocal(scaleDetails.focalPoint);
                  final pdtop = MediaQuery.of(context).padding.top;
                  final fixed = Offset(
                      point.dx / _currentZoom - _currentPanX / _currentZoom,
                      (point.dy - pdtop) / _currentZoom -
                          _currentPanY / _currentZoom);
                  _line = DrawnLine(
                    [fixed],
                    _lineColor,
                    _selectedWidth,
                    panX: _currentPanX,
                    panY: _currentPanY,
                  );
                },
                onInteractionUpdate: (scaleUpdates) {
                  if (scaleUpdates.pointerCount == 0) return;
                  final box = context.findRenderObject() as RenderBox;
                  final point = box.globalToLocal(scaleUpdates.focalPoint);
                  final pdtop = MediaQuery.of(context).padding.top;
                  final fixed = Offset(
                      point.dx / _currentZoom - _currentPanX / _currentZoom,
                      (point.dy - pdtop) / _currentZoom -
                          _currentPanY / _currentZoom);
                  final List<Offset> path = List.from(_line?.path ?? [])
                    ..add(fixed);
                  _line = DrawnLine(
                    path,
                    _lineColor,
                    _selectedWidth,
                    panX: _currentPanX,
                    panY: _currentPanY,
                  );
                  currentLineStreamController.add(_line!);
                },
                onInteractionEnd: (scaleEndDetails) {
                  if (_isPan || _isDrawText) {
                    setState(() {
                      _startX = _currentPanX;
                      _startY = _currentPanY;
                    });
                    return;
                  }
                  if (_line == null) return;
                  setState(() {
                    _lines.add(_line!..isEraser = _isEraser);
                    _line = null;
                  });
                  linesStreamController.add(_lines);
                },
                child: Stack(
                  children: [
                    buildAllPaths(context),
                    buildCurrentPath(context),
                  ],
                ),
              ),
              buildColorToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCurrentPath(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: Colors.transparent,
        child: StreamBuilder<dynamic>(
          stream: currentLineStreamController.stream,
          builder: (context, snapshot) {
            return CustomPaint(
              painter: Sketcher(
                lines: _line == null ? [] : [_line!],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildAllPaths(BuildContext context) {
    return RepaintBoundary(
      key: _globalKey,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: BACKGROUND_COLOR,
        child: StreamBuilder<List<dynamic>>(
          stream: linesStreamController.stream,
          builder: (context, snapshot) {
            return CustomPaint(
              painter: Sketcher(
                background: _background,
                prevDrawing: _prevDrawing,
                lines: _lines,
              ),
            );
          },
        ),
      ),
    );
  }

  _addText() async {
    setState(() {
      _isAddText = true;
    });
  }

  Widget buildColorToolbar() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(
                  width: 10.0,
                ),
                buildSaveButton(),
              ],
            ),
            const SizedBox(
              height: 8,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Color>[
                const Color(0xFFE21B00),
                const Color(0xFF0077DC),
                const Color(0xFF8B00DB),
                const Color(0xFF3AB000),
                const Color(0xFFFAC800),
                const Color(0xFFFA6A00),
                Colors.black,
                Colors.white,
              ].map<Widget>((color) {
                return buildColorButton(color);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildColorButton(Color color) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: SizedBox(
        width: 24,
        height: 24,
        child: ElevatedButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(color),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color:
                          color == Colors.white ? Colors.black : Colors.white,
                      width: 1)),
            ),
            elevation: MaterialStateProperty.all(0),
          ),
          child: Container(),
          onPressed: () {
            setState(() {
              _selectedColor = color;
              _text?.color = color;
            });
          },
        ),
      ),
    );
  }

  Widget buildSaveButton() {
    return GestureDetector(
      onTap: _save,
      child: const CircleAvatar(
        backgroundColor: Colors.blue,
        child: Icon(
          Icons.check_rounded,
          size: 24.0,
          color: Colors.white,
        ),
      ),
    );
  }
}
