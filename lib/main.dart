import 'dart:io';
import 'dart:typed_data';

import 'dart:ui' as ui;
import 'dart:math';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:drawie/helpers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:image_picker/image_picker.dart';
import 'drawing.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ink your Image',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// //Function used to pick image from camera (the image file is not converting into a ui.image, that is the error in this)
//   Future pickImageC() async {
//     final image = await ImagePicker().pickImage(source: ImageSource.camera);

//     if (image == null) return;

//     final imageTemp = File(image.path);

//     setState(() => this._image = imageTemp);
//
//   }

class _MyHomePageState extends State<MyHomePage> {
  final _urlController = TextEditingController();
  var _isProcessing = false;
  dynamic _image;

  bool _isValidImageURL(String url) =>
      Uri.parse(url).isAbsolute &&
      lookupMimeType(url)?.split('/').first == 'image';

// This function redirects the page to our drawing page, this is called below
  _submit() async {
    final url = _urlController.text;
    if (!_isValidImageURL(url))
      return h.showDialog(
          type: DialogType.ERROR, message: "Please enter valid image URL!");
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DrawingPage(background: url),
      ),
    ) as Uint8List?;
    if (!mounted || result == null) return;
    setState(() {
      _image = result;
    });
  }

//takes us back to main screen
  _back() {
    setState(() {
      _image = null;
    });
  }

// saves the file
  _save() async {
    setState(() {
      _isProcessing = true;
    });
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 3000));
    } else {
      final fileName = "${DateTime.now().millisecondsSinceEpoch}";
      final filePath = await h.getDownloadPath('$fileName.png');
      final file = await File(filePath).writeAsBytes(_image);

      h.shareFile(file.path);
    }
    setState(() {
      _isProcessing = false;
      _image = null;
    });
  }

// there is a default URL present, so you don't have to check
  @override
  void initState() {
    _urlController.text = 'https://pixlr.com/images/index/remove-bg.webp';
    h = MyHelper(context);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _image != null
          ? null
          : AppBar(
              title: const Text("Ink your Image"),
            ),
      body: SafeArea(
        child: Center(
          child: _isProcessing
              ? const CircularProgressIndicator.adaptive()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _image == null
                        ? [
                            const Text(
                              "Enter URL:",
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            TextField(
                              controller: _urlController,
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            ElevatedButton(
                                onPressed: _submit, child: const Text("Paint"))
                          ]
                        : [
                            Row(
                              children: [
                                Expanded(
                                    child: ElevatedButton(
                                        onPressed: _back,
                                        child: const Text("Back"))),
                                const SizedBox(
                                  width: 20,
                                ),
                                Expanded(
                                    child: ElevatedButton(
                                        onPressed: _save,
                                        child: const Text("Save"))),
                              ],
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            Image.memory(_image),
                          ],
                  ),
                ),
        ),
      ),
    );
  }
}
