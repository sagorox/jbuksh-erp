import 'package:flutter/material.dart';

class ExportUtilsImpl {
  static Future<void> exportCsvAsXls(
    BuildContext context, {
    required String fileBaseName,
    required List<List<String>> rows,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export not supported on this platform.')),
    );
  }
}
