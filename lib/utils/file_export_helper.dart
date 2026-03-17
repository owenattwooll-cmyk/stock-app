import 'file_export_helper_stub.dart'
    if (dart.library.html) 'file_export_helper_web.dart'
    if (dart.library.io) 'file_export_helper_io.dart';

Future<bool> saveTextFile({
  required String filename,
  required String content,
}) {
  return saveTextFileImpl(
    filename: filename,
    content: content,
  );
}
