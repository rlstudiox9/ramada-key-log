import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

void downloadTextFile(String contents, String filename, String mimeType) {
  final blob = html.Blob(
    [utf8.encode(contents)],
    mimeType,
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}

void downloadBinaryFile(Uint8List contents, String filename, String mimeType) {
  final blob = html.Blob([contents], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}
