import 'file_download_stub.dart' if (dart.library.html) 'file_download_web.dart'
    as implementation;

void downloadTextFile(String contents, String filename, String mimeType) =>
    implementation.downloadTextFile(contents, filename, mimeType);
