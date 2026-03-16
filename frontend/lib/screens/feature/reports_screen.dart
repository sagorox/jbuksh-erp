import 'package:flutter/material.dart';

import '../../routes.dart';
import 'feature_scaffold.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = const [
      'Sales Report',
      'Party Statement',
      'Day Book',
      'Stock Summary',
      'Low Stock Summary',
      'Balance Sheet',
      'Trial Balance',
      'P&L',
    ];

    return FeatureScaffold(
      title: 'Reports',
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const ListTile(
              leading: Icon(Icons.tune),
              title: Text('All reports support filters and export'),
              subtitle: Text(
                'Preview, XLS export, and report filter flow are ready from this screen.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...reports.map(
                (r) => Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.insert_chart_outlined),
                title: Text(r),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    RouteNames.reportFilter,
                    arguments: {'reportKey': r},
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}