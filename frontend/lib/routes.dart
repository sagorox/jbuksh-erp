import 'package:flutter/material.dart';
import 'package:jbuksh/screens/feature/approvals_screen.dart';

// Screens Import
import 'package:jbuksh/screens/feature/transactions_screen.dart';
import 'package:jbuksh/screens/feature/parties_screen.dart';
import 'package:jbuksh/screens/feature/collections_screen.dart';
import 'screens/feature/expenses_screen.dart';
import 'package:jbuksh/screens/feature/reports_screen.dart';
import 'package:jbuksh/screens/feature/attendance_screen.dart';
import 'package:jbuksh/screens/feature/schedule_screen.dart';
import 'package:jbuksh/screens/feature/stock_summary_screen.dart';
import 'package:jbuksh/screens/feature/deliveries_screen.dart';
import 'package:jbuksh/screens/feature/adjust_stock_screen.dart';
import 'package:jbuksh/screens/feature/admin_users_screen.dart';
import 'package:jbuksh/screens/feature/admin_territory_screen.dart';
import 'package:jbuksh/screens/feature/audit_logs_screen.dart';
import 'package:jbuksh/screens/feature/sync_status_screen.dart';
import 'package:jbuksh/screens/feature/audit_log_details_screen.dart';
import 'package:jbuksh/screens/feature/settings_screen.dart';
import 'package:jbuksh/screens/feature/add_sale_screen.dart';
import 'package:jbuksh/screens/feature/transaction_details_screen.dart';
import 'package:jbuksh/screens/feature/party_details_screen.dart';
import 'package:jbuksh/screens/feature/take_payment_screen.dart';
import 'package:jbuksh/screens/feature/report_filter_screen.dart';
import 'package:jbuksh/screens/feature/add_party_screen.dart';
import 'package:jbuksh/screens/feature/product_details_screen.dart';
import 'package:jbuksh/screens/feature/add_edit_item_screen.dart';
import 'package:jbuksh/screens/feature/conflicts_screen.dart';
import 'package:jbuksh/screens/feature/invoice_preview_screen.dart';
import 'package:jbuksh/screens/feature/report_preview_screen.dart';
import 'package:jbuksh/screens/feature/notifications_screen.dart';
import 'package:jbuksh/screens/feature/accounting_screen.dart';
import 'package:jbuksh/screens/feature/voucher_details_screen.dart';
// ✅ ReportResultScreen ইমপোর্ট যুক্ত করা হলো
import 'package:jbuksh/screens/feature/report_result_screen.dart';

class RouteNames {
  static const transactions = '/transactions';
  static const addSale = '/transactions/add';
  static const transactionDetails = '/transactions/details';
  static const parties = '/parties';
  static const addParty = '/parties/add';
  static const partyDetails = '/party/details';
  static const takePayment = '/party/take-payment';
  static const collections = '/collections';
  static const expenses = '/expenses';
  static const reports = '/reports';
  static const reportFilter = '/reports/filter';
  static const reportResult = '/reports/result';
  static const attendance = '/attendance';
  static const schedule = '/schedule';
  static const approvals = '/approvals';
  static const stockSummary = '/stock-summary';
  static const productDetails = '/products/details';
  static const addEditItem = '/products/add-edit';
  static const deliveries = '/deliveries';
  static const adjustStock = '/adjust-stock';
  static const adminUsers = '/admin/users';
  static const adminTerritory = '/admin/territory';
  static const auditLogs = '/admin/audit-logs';
  static const auditLogDetails = '/admin/audit-logs/details';
  static const syncStatus = '/sync-status';
  static const conflicts = '/conflicts';
  static const invoicePreview = '/transactions/preview';
  static const reportPreview = '/reports/preview';
  static const notifications = '/notifications';
  static const accounting = '/accounting';
  static const voucherDetails = '/accounting/voucher-details';
  static const settings = '/settings';
}

class AppRoutes {
  static Map<String, WidgetBuilder> get routes => {
    RouteNames.transactions: (_) => const TransactionsScreen(),
    RouteNames.addSale: (_) => const AddSaleScreen(),
    RouteNames.transactionDetails: (ctx) {
      final args =
          ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
      return TransactionDetailsScreen(invoice: args ?? {});
    },
    RouteNames.parties: (_) => const PartiesScreen(),
    RouteNames.addParty: (_) => const AddPartyScreen(),
    RouteNames.partyDetails: (ctx) {
      final args =
          ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
      return PartyDetailsScreen(party: args ?? {});
    },
    RouteNames.takePayment: (ctx) {
      final args =
          ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
      return TakePaymentScreen(party: args ?? {});
    },
    RouteNames.collections: (_) => const CollectionsScreen(),
    RouteNames.expenses: (_) => const ExpensesScreen(),
    RouteNames.reports: (_) => const ReportsScreen(),
    RouteNames.reportFilter: (ctx) {
      final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
      final key = args?['reportKey']?.toString() ?? 'Sales Report';
      final prePartyId = args?['partyId'];
      return ReportFilterScreen(reportKey: key, presetPartyId: prePartyId);
    },
    RouteNames.reportResult: (ctx) {
      final args =
          ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
      return ReportResultScreen(
        args: args ?? {},
      ); // ✅ এখন এটি এরর ছাড়াই কাজ করবে
    },
    RouteNames.attendance: (_) => const AttendanceScreen(),
    RouteNames.schedule: (_) => const ScheduleScreen(),
    RouteNames.approvals: (_) => const ApprovalsScreen(),
    RouteNames.stockSummary: (_) => const StockSummaryScreen(),
    RouteNames.productDetails: (ctx) {
      final args =
          ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
      return ProductDetailsScreen(product: args ?? {});
    },
    RouteNames.addEditItem: (ctx) {
      final args =
          ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
      return args != null
          ? AddEditItemScreen(product: args)
          : const AddEditItemScreen();
    },
    RouteNames.deliveries: (_) => const DeliveriesScreen(),
    RouteNames.adjustStock: (_) => const AdjustStockScreen(),
    RouteNames.adminUsers: (_) => const AdminUsersScreen(),
    RouteNames.adminTerritory: (_) => const AdminTerritoryScreen(),
    RouteNames.auditLogs: (_) => const AuditLogsScreen(),
    RouteNames.auditLogDetails: (ctx) {
      final args =
          ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
      return AuditLogDetailsScreen(log: args ?? {});
    },
    RouteNames.syncStatus: (_) => const SyncStatusScreen(),
    RouteNames.conflicts: (_) => const ConflictsScreen(),
    RouteNames.invoicePreview: (ctx) {
      final args =
          ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
      return InvoicePreviewScreen(invoice: args ?? {});
    },
    RouteNames.reportPreview: (ctx) {
      final args =
          ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
      return ReportPreviewScreen(args: args ?? {});
    },
    RouteNames.notifications: (_) => const NotificationsScreen(),
    RouteNames.accounting: (_) => const AccountingScreen(),
    RouteNames.voucherDetails: (ctx) {
      final args =
          ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
      return VoucherDetailsScreen(voucher: args ?? {});
    },
    RouteNames.settings: (_) => const SettingsScreen(),
  };
}
