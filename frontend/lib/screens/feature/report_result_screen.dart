import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/export_utils.dart';
import '../../core/local_store.dart';
import '../../routes.dart';
import 'feature_scaffold.dart';

class ReportResultScreen extends StatelessWidget {
  final Map<String, dynamic> args;
  const ReportResultScreen({super.key, required this.args});

  DateTime _dt(String iso) {
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return DateTime.now();
    }
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  bool _inRange(String? d, DateTime from, DateTime to) {
    if (d == null || d.isEmpty) return false;
    try {
      final dt = DateTime.parse(d);
      return !dt.isBefore(DateTime(from.year, from.month, from.day)) &&
          !dt.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59));
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> _buildRows(
      String reportKey,
      DateTime from,
      DateTime to,
      dynamic partyId,
      dynamic status,
      ) {
    final invoicesAll = LocalStore.allBoxMaps('invoices');
    final collectionsAll = LocalStore.allBoxMaps('collections');
    final productsAll = LocalStore.allBoxMaps('products');
    final vouchersAll = Hive.box('vouchers')
        .values
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    List<Map<String, dynamic>> rows = [];

    if (reportKey == 'Sales Report') {
      rows = invoicesAll.where((e) {
        final okDate = _inRange(e['invoice_date']?.toString(), from, to);
        final okParty = partyId == null
            ? true
            : (e['party_id'] ?? (e['party']?['id'])) == partyId;
        final okStatus =
        status == null ? true : (e['status'] ?? '').toString() == status;
        return okDate && okParty && okStatus;
      }).toList();
    } else if (reportKey == 'Party Statement') {
      final inv = invoicesAll.where((e) {
        final sameParty = partyId != null &&
            (e['party_id'] ?? (e['party']?['id'])) == partyId;
        return sameParty && _inRange(e['invoice_date']?.toString(), from, to);
      });

      final col = collectionsAll.where((e) {
        final sameParty = partyId != null &&
            (e['party_id'] ?? (e['party']?['id'])) == partyId;
        return sameParty &&
            _inRange(e['collection_date']?.toString(), from, to);
      });

      for (final e in inv) {
        rows.add({
          'date': e['invoice_date'] ?? '-',
          'type': 'INVOICE',
          'ref': e['invoice_no'] ?? '-',
          'debit': _toNum(e['net_total']),
          'credit': 0,
        });
      }

      for (final e in col) {
        rows.add({
          'date': e['collection_date'] ?? '-',
          'type': 'PAYMENT',
          'ref': e['collection_no'] ?? '-',
          'debit': 0,
          'credit': _toNum(e['amount']),
        });
      }
    } else if (reportKey == 'Day Book') {
      rows = vouchersAll
          .where((v) => _inRange(v['voucher_date']?.toString(), from, to))
          .toList();
    } else if (reportKey == 'Trial Balance') {
      final ledger = <String, Map<String, dynamic>>{};
      for (final v in vouchersAll.where(
            (v) => _inRange(v['voucher_date']?.toString(), from, to),
      )) {
        final lines = (v['lines'] as List?) ?? const [];
        for (final line in lines.whereType<Map>()) {
          final m = line.cast<String, dynamic>();
          final code = (m['account_code'] ?? '-').toString();
          final name = (m['account_name'] ?? code).toString();

          final curr = ledger[code] ??
              {
                'account_code': code,
                'account_name': name,
                'debit': 0,
                'credit': 0,
              };

          curr['debit'] = _toNum(curr['debit']) + _toNum(m['debit']);
          curr['credit'] = _toNum(curr['credit']) + _toNum(m['credit']);
          ledger[code] = curr;
        }
      }
      rows = ledger.values.toList();
    } else if (reportKey == 'Stock Summary') {
      final totalItems = productsAll.length;
      final stockValue = productsAll.fold<num>(
        0,
            (s, e) => s + (_toNum(e['in_stock']) * _toNum(e['purchase_price'])),
      );
      final lowCount = productsAll
          .where(
            (e) =>
        _toNum(e['reorder_level']) > 0 &&
            _toNum(e['in_stock']) <= _toNum(e['reorder_level']),
      )
          .length;

      rows = [
        {'label': 'Total Items', 'value': totalItems},
        {'label': 'Low Stock Items', 'value': lowCount},
        {'label': 'Stock Value', 'value': stockValue},
      ];
    } else if (reportKey == 'Low Stock Summary') {
      rows = productsAll
          .where(
            (e) =>
        _toNum(e['reorder_level']) > 0 &&
            _toNum(e['in_stock']) <= _toNum(e['reorder_level']),
      )
          .toList();
    }

    return rows;
  }

  List<List<String>> _toExportRows(
      String reportKey,
      List<Map<String, dynamic>> rows,
      ) {
    if (rows.isEmpty) {
      return const [
        ['Info'],
        ['No data'],
      ];
    }

    if (reportKey == 'Sales Report') {
      final out = <List<String>>[
        ['Invoice', 'Date', 'Party', 'Net Total', 'Status'],
      ];
      for (final r in rows) {
        out.add([
          (r['invoice_no'] ?? '-').toString(),
          (r['invoice_date'] ?? '-').toString(),
          (r['party_name'] ?? r['party']?['name'] ?? '-').toString(),
          _toNum(r['net_total']).toStringAsFixed(2),
          (r['status'] ?? '-').toString(),
        ]);
      }
      return out;
    }

    if (reportKey == 'Party Statement') {
      final out = <List<String>>[
        ['Date', 'Type', 'Reference', 'Debit', 'Credit'],
      ];
      for (final r in rows) {
        out.add([
          (r['date'] ?? '-').toString(),
          (r['type'] ?? '-').toString(),
          (r['ref'] ?? '-').toString(),
          _toNum(r['debit']).toStringAsFixed(2),
          _toNum(r['credit']).toStringAsFixed(2),
        ]);
      }
      return out;
    }

    if (reportKey == 'Trial Balance') {
      final out = <List<String>>[
        ['Account Code', 'Account Name', 'Debit', 'Credit'],
      ];
      for (final r in rows) {
        out.add([
          (r['account_code'] ?? '-').toString(),
          (r['account_name'] ?? '-').toString(),
          _toNum(r['debit']).toStringAsFixed(2),
          _toNum(r['credit']).toStringAsFixed(2),
        ]);
      }
      return out;
    }

    if (reportKey == 'Stock Summary') {
      final out = <List<String>>[
        ['Label', 'Value'],
      ];
      for (final r in rows) {
        out.add([
          (r['label'] ?? '-').toString(),
          _toNum(r['value']).toStringAsFixed(2),
        ]);
      }
      return out;
    }

    if (reportKey == 'Low Stock Summary') {
      final out = <List<String>>[
        ['Product', 'In Stock', 'Reorder Level'],
      ];
      for (final r in rows) {
        out.add([
          (r['name'] ?? r['product_name'] ?? r['sku'] ?? '-').toString(),
          _toNum(r['in_stock']).toStringAsFixed(0),
          _toNum(r['reorder_level']).toStringAsFixed(0),
        ]);
      }
      return out;
    }

    final out = <List<String>>[
      ['Data'],
    ];
    for (final r in rows) {
      out.add([r.toString()]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final reportKey = (args['reportKey'] ?? 'Report').toString();
    final from = _dt(args['from'] ?? DateTime.now().toIso8601String());
    final to = _dt(args['to'] ?? DateTime.now().toIso8601String());
    final partyId = args['partyId'];
    final status = args['status'];

    final rows = _buildRows(reportKey, from, to, partyId, status);

    return FeatureScaffold(
      title: reportKey,
      actions: [
        IconButton(
          tooltip: 'Preview',
          onPressed: () {
            Navigator.pushNamed(
              context,
              RouteNames.reportPreview,
              arguments: args,
            );
          },
          icon: const Icon(Icons.picture_as_pdf_outlined),
        ),
        IconButton(
          tooltip: 'Export XLS',
          onPressed: () {
            ExportUtils.exportCsvAsXls(
              context,
              fileBaseName:
              '${reportKey.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
              rows: _toExportRows(reportKey, rows),
            );
          },
          icon: const Icon(Icons.table_view_outlined),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'From ${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')} '
                    'to ${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No data found for this filter.'),
            )
          else
            ...rows.map(
                  (r) => Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text(
                    (r['invoice_no'] ??
                        r['voucher_no'] ??
                        r['label'] ??
                        r['account_code'] ??
                        r['ref'] ??
                        '-')
                        .toString(),
                  ),
                  subtitle: Text(
                    (r['invoice_date'] ??
                        r['voucher_date'] ??
                        r['date'] ??
                        r['party_name'] ??
                        r['account_name'] ??
                        '')
                        .toString(),
                  ),
                  trailing: Text(
                    r.containsKey('net_total')
                        ? _toNum(r['net_total']).toStringAsFixed(2)
                        : (r.containsKey('value')
                        ? _toNum(r['value']).toStringAsFixed(2)
                        : ((r.containsKey('debit') ||
                        r.containsKey('credit'))
                        ? 'Dr ${_toNum(r['debit']).toStringAsFixed(2)} / Cr ${_toNum(r['credit']).toStringAsFixed(2)}'
                        : '')),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}