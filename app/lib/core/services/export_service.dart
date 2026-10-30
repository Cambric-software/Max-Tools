import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../storage/cambric_paths.dart';

/// Exports a value to the clipboard, a file, or a variable.
///
/// Shared by every tool so "export" means the same thing everywhere: a copy
/// to the clipboard, a file written under the product's exports directory, or
/// a value handed back to the caller for storage as a variable.
class ExportService {
  const ExportService();

  /// Copy [value] to the clipboard and report success.
  Future<bool> toClipboard(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied.'), duration: Duration(seconds: 1)),
      );
    }
    return true;
  }

  /// Write [value] to a file under the product's exports directory.
  /// Returns the file, or null on failure.
  Future<File?> toFile(String productId, String fileName, String value) async {
    try {
      final dir = await CambricPaths.productData(productId);
      final exports = Directory('${dir.path}${Platform.pathSeparator}exports');
      if (!await exports.exists()) await exports.create(recursive: true);
      final file = File('${exports.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(value);
      return file;
    } catch (_) {
      return null;
    }
  }
}