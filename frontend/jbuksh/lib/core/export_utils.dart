import 'package:flutter/material.dart';

import 'export_utils_impl.dart';

/// Public export API used by screens.
class ExportUtils {
  static Future<void> exportCsvAsXls(
    BuildContext context, {
    required String fileBaseName,
    required List<List<String>> rows,
  }) {
    return ExportUtilsImpl.exportCsvAsXls(
      context,
      fileBaseName: fileBaseName,
      rows: rows,
    );
  }
}
