import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../data/models/app_settings.dart';

/// Writes exports. With an export folder set (desktop) files go straight
/// there; otherwise the system save dialog asks where.
class ExportService {
  const ExportService();

  static String stampedName(String base, ExportFormat format) =>
      'pulse-$base-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}.${format.name}';

  /// Returns where the file went, or null when the user cancelled.
  Future<String?> save({required String fileName, required String content, required AppSettings settings}) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    final folder = settings.exportFolder;
    final desktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    if (desktop && folder != null && folder.isNotEmpty) {
      final dir = Directory(folder);
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, fileName));
      await file.writeAsBytes(bytes);
      return file.path;
    }
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: fileName.endsWith('.csv') ? 'text/csv' : 'text/plain',
      dialogTitle: 'Export from Pulse',
      allowedExtensions: [p.extension(fileName).replaceFirst('.', '')],
      type: FileType.custom,
    );
    if (uri == null) return null;
    // Desktop dialogs return a location without writing; write it ourselves.
    if (desktop && uri.scheme == 'file') {
      final file = File.fromUri(uri);
      if (!await file.exists() || await file.length() == 0) await file.writeAsBytes(bytes);
      return file.path;
    }
    return uri.toString();
  }
}
