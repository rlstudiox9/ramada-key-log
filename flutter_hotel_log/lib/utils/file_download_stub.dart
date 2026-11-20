import 'dart:typed_data';

void downloadTextFile(String contents, String filename, String mimeType) {
  throw UnsupportedError('File downloads are only supported in a web browser.');
}

void downloadBinaryFile(Uint8List contents, String filename, String mimeType) {
  throw UnsupportedError('File downloads are only supported in a web browser.');
}
