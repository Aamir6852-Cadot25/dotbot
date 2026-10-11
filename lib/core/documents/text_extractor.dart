import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

/// Reads text from a .pdf (pdfrx, MIT) or any plain-text file.
Future<String> extractText(String path) async {
  if (!path.toLowerCase().endsWith('.pdf')) return File(path).readAsString();
  final doc = await PdfDocument.openFile(path);
  try {
    final out = StringBuffer();
    for (final page in doc.pages) {
      final t = await page.loadText();
      out.writeln(t?.fullText ?? '');
      if (out.length > 60000) break; // enough for a summary
    }
    return out.toString();
  } finally {
    await doc.dispose();
  }
}
