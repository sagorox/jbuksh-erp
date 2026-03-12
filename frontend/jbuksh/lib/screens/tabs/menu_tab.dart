import 'package:flutter/material.dart';

import '../../core/local_store.dart';
import '../../core/role_utils.dart';
import '../../routes.dart';

class MenuTab extends StatelessWidget {
  const MenuTab({super.key});

  Widget _tile(BuildContext context,
      {required IconData icon,
        required String title,
        required String route}) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleUtils.normalize(LocalStore.role());

    Widget gatedTile({
      required IconData icon,
      required String title,
      required String route,
      required Set<String> allowed,
    }) {
      if (!RoleUtils.canAccess(role, allowed)) return const SizedBox.shrink();
      return _tile(context, icon: icon, title: title, route: route);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _section("My Business"),
        gatedTile(
            icon: Icons.receipt_long,
            title: "Transactions / Sales",
            route: RouteNames.transactions,
            allowed: const {RoleUtils.mpo, RoleUtils.rsm, RoleUtils.salesDept}),
        gatedTile(
            icon: Icons.people,
            title: "Parties",
            route: RouteNames.parties,
            allowed: const {RoleUtils.mpo, RoleUtils.rsm, RoleUtils.accounting, RoleUtils.salesDept}),
        gatedTile(
            icon: Icons.payments,
            title: "Collections",
            route: RouteNames.collections,
            allowed: const {RoleUtils.mpo, RoleUtils.rsm, RoleUtils.accounting}),
        gatedTile(
            icon: Icons.money_off,
            title: "Expenses",
            route: RouteNames.expenses,
            allowed: const {RoleUtils.mpo, RoleUtils.rsm, RoleUtils.accounting}),

        _section("Reports"),
        gatedTile(
            icon: Icons.bar_chart,
            title: "Reports",
            route: RouteNames.reports,
            allowed: const {RoleUtils.mpo, RoleUtils.rsm, RoleUtils.salesDept, RoleUtils.accounting, RoleUtils.stockKeeper}),
        gatedTile(
            icon: Icons.account_balance_wallet_outlined,
            title: "Accounting",
            route: RouteNames.accounting,
            allowed: const {RoleUtils.accounting}),
        gatedTile(
            icon: Icons.inventory,
            title: "Stock Summary",
            route: RouteNames.stockSummary,
            allowed: const {RoleUtils.mpo, RoleUtils.rsm, RoleUtils.stockKeeper, RoleUtils.salesDept}),

        _section("Stock"),
        gatedTile(
            icon: Icons.build,
            title: "Adjust Stock",
            route: RouteNames.adjustStock,
            allowed: const {RoleUtils.stockKeeper, RoleUtils.rsm}),
        gatedTile(
            icon: Icons.local_shipping,
            title: "Deliveries",
            route: RouteNames.deliveries,
            allowed: const {RoleUtils.stockKeeper, RoleUtils.rsm}),

        _section("HR / Field"),
        gatedTile(
            icon: Icons.access_time,
            title: "Attendance",
            route: RouteNames.attendance,
            allowed: const {RoleUtils.mpo, RoleUtils.rsm}),
        gatedTile(
            icon: Icons.calendar_month,
            title: "Schedule",
            route: RouteNames.schedule,
            allowed: const {RoleUtils.mpo, RoleUtils.rsm}),

        _section("Approvals"),
        gatedTile(
            icon: Icons.verified,
            title: "Approvals",
            route: RouteNames.approvals,
            allowed: const {RoleUtils.rsm, RoleUtils.accounting, RoleUtils.salesDept}),

        _section("Admin"),
        gatedTile(
            icon: Icons.group,
            title: "Admin Users",
            route: RouteNames.adminUsers,
            allowed: const {RoleUtils.superAdmin}),
        gatedTile(
            icon: Icons.map,
            title: "Admin Territory",
            route: RouteNames.adminTerritory,
            allowed: const {RoleUtils.superAdmin}),
        gatedTile(
            icon: Icons.history,
            title: "Audit Logs",
            route: RouteNames.auditLogs,
            allowed: const {RoleUtils.superAdmin}),

        _section("Sync"),
        gatedTile(
            icon: Icons.sync,
            title: "Sync Status",
            route: RouteNames.syncStatus,
            allowed: const {RoleUtils.mpo, RoleUtils.rsm, RoleUtils.salesDept, RoleUtils.accounting, RoleUtils.stockKeeper}),
        gatedTile(
            icon: Icons.warning,
            title: "Conflict Center",
            route: RouteNames.conflicts,
            allowed: const {RoleUtils.mpo, RoleUtils.rsm, RoleUtils.salesDept, RoleUtils.accounting, RoleUtils.stockKeeper}),

        _section("Settings"),
        gatedTile(
            icon: Icons.settings,
            title: "Settings",
            route: RouteNames.settings,
            allowed: const {RoleUtils.mpo, RoleUtils.rsm, RoleUtils.salesDept, RoleUtils.accounting, RoleUtils.stockKeeper}),
      ],
    );
  }
}
