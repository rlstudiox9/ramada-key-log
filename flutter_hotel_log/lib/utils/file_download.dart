import 'dart:typed_data';

import 'file_download_stub.dart' if (dart.library.html) 'file_download_web.dart'
    as implementation;

void downloadTextFile(String contents, String filename, String mimeType) =>
    implementation.downloadTextFile(contents, filename, mimeType);

void downloadBinaryFile(Uint8List contents, String filename, String mimeType) =>
    implementation.downloadBinaryFile(contents, filename, mimeType);
