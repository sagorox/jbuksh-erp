import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExportUtilsImpl {
  static Future<void> exportCsvAsXls(
    BuildContext context, {
    required String fileBaseName,
    required List<List<String>> rows,
  }) async {
    final csv = const _Csv().convert(rows);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$fileBaseName.xls (CSV content)'),
        content: SizedBox(width: 520, child: SelectableText(csv)),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csv));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              }
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
