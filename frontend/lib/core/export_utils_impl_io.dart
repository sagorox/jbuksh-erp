import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class ExportUtilsImpl {
  static Future<void> exportCsvAsXls(
    BuildContext context, {
    required String fileBaseName,
    required List<List<String>> rows,
  }) async {
    final csv = const _Csv().convert(rows);

    final dir = Directory.systemTemp;
    final file = File('${dir.path}/$fileBaseName.xls');
    await file.writeAsBytes(utf8.encode(csv), flush: true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported: ${file.path}')),
      );
    }
  }
}

class _Csv {
  const _Csv();

  String convert(List<List<String>> rows) {
    final b = StringBuffer();
    for (final row in rows) {
      b.writeln(row.map(_escape).join(','));
    }
    return b.toString();
  }

  String _escape(String v) {
    final needsQuote = v.contains(',') || v.contains('\n') || v.contains('"');
    if (!needsQuote) return v;
    return '"${v.replaceAll('"', '""')}"';
  }
}
