import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<bool> saveTextFileImpl({
  required String filename,
  required String content,
}) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save CSV export',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: const ['csv'],
    bytes: null,
  );

  if (path == null || path.trim().isEmpty) {
    return false;
  }

  final file = File(path);
  await file.writeAsString(content);
  return true;
}
