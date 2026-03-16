import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../core/api.dart';
import '../core/sync_service.dart';
import '../core/token_store.dart';
import 'shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneCtrl = TextEditingController(text: '01755128209');
  final passCtrl = TextEditingController(text: '123456');
  bool loading = false;
  String? err;

  String _makeDeviceId(String phone) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return 'device-${phone.replaceAll(RegExp(r'[^0-9]'), '')}-$ts';
  }

  Future<void> login() async {
    setState(() {
      loading = true;
      err = null;
    });

    try {
      final phone = phoneCtrl.text.trim();

      final res = await Api.postJson(
        '/api/v1/auth/login',
        {'phone': phone, 'password': passCtrl.text},
        auth: false,
      );

      final token = res['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('No token returned from server');
      }

      final auth = Hive.box('auth');
      final existingDeviceId = auth.get('deviceId')?.toString();

      await auth.put('token', token);
      await auth.put('user', res['user'] ?? {});
      await auth.put('is_logged_in', true);
      await auth.put(
        'deviceId',
        (existingDeviceId != null && existingDeviceId.trim().isNotEmpty)
            ? existingDeviceId
            : _makeDeviceId(phone),
      );
      await auth.put(
        'last_login_at',
        DateTime.now().toUtc().toIso8601String(),
      );

      await TokenStore.save(token);

      await SyncService.bootstrapAndStore(force: true);
      await SyncService.syncAll();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ShellScreen()),
      );
    } catch (e) {
      setState(() => err = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JBCL ERP Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.lock_person, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            if (err != null)
              Text(
                err!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : login,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(loading ? 'Authenticating...' : 'Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}