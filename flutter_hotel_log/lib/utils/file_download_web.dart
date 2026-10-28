import 'dart:convert';
import 'dart:html' as html;

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
