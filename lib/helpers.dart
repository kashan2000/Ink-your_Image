import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class MyHelper {
  final BuildContext context;
  MyHelper(this.context) {}

  Future showDialog({
    DialogType type = DialogType.NO_HEADER,
    String? title,
    String? message,
    Widget? body,
    VoidCallback? onCancel,
    VoidCallback? onOK,
  }) {
    final dialog = AwesomeDialog(
      context: context,
      animType: AnimType.SCALE,
      dialogType: type,
      body: body == null
          ? null
          : Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: body,
            ),
      title: title,
      desc: message,
      btnCancelOnPress: onCancel,
      btnOkOnPress: onOK,
    );
    return dialog.show();
  }

  Future<Directory> getDownloadDirectory() async {
    late final Directory dir;
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      final downloadDirExist = await downloadDir.exists();
      dir = downloadDirExist
          ? downloadDir
          : (await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory());
    } else if (Platform.isIOS) {
      dir = await getApplicationDocumentsDirectory();
    }
    return await Directory('${dir.path}/IyG').create(recursive: true);
  }

  Future<String> getDownloadPath(String fileName) async {
    return '${(await getDownloadDirectory()).path}/$fileName';
  }

  Future shareFile(String filePath) {
    return Share.shareFiles([filePath]);
  }
}
