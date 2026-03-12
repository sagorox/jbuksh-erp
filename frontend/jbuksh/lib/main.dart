import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:jbuksh/routes.dart';

import 'core/accounting_service.dart';
import 'core/sync_service.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';

Future<void> _openRequiredBoxes() async {
  const boxNames = <String>[
    'auth',
    'collections',
    'territories',
    'categories',
    'products',
    'product_batches',
    'parties',
    'invoices',
    'expenses',
    'stock_txns',
    'attendance',
    'audit_logs',
    'deliveries',
    'notifications',
    'vouchers',
    'coa_accounts',
    'cacheBox',
    'outboxBox',
    'conflicts',
    'settings',
  ];

  for (final name in boxNames) {
    if (!Hive.isBoxOpen(name)) {
      await Hive.openBox(name);
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await _openRequiredBoxes();

  try {
    await AccountingService.ensureCoaSeeded();
  } catch (e) {
    debugPrint('COA Seed Error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  bool _hasSession() {
    final auth = Hive.box('auth');
    final token = auth.get('token')?.toString();
    final user = auth.get('user');
    return token != null &&
        token.trim().isNotEmpty &&
        user is Map &&
        user.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JBCL ERP',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: _hasSession() ? const SessionBootstrapGate() : const LoginScreen(),
      routes: AppRoutes.routes,
    );
  }
}

class SessionBootstrapGate extends StatefulWidget {
  const SessionBootstrapGate({super.key});

  @override
  State<SessionBootstrapGate> createState() => _SessionBootstrapGateState();
}

class _SessionBootstrapGateState extends State<SessionBootstrapGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _resume();
  }

  Future<void> _resume() async {
    try {
      await SyncService.bootstrapAndStore(force: false);
      await SyncService.syncAll();
    } catch (e) {
      debugPrint('Session resume sync warning: $e');
    } finally {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return const ShellScreen();
  }
}