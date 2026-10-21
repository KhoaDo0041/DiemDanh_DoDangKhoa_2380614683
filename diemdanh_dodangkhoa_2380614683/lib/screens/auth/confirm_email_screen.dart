import 'package:diemdanh_dodangkhoa_2380614683/services/auth_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:diemdanh_dodangkhoa_2380614683/widgets/common.dart';
import 'package:flutter/material.dart';

/// YÊU CẦU 1 (bước 2): nhập mã xác nhận đã gửi về email để kích hoạt tài khoản
class ConfirmEmailScreen extends StatefulWidget {
  const ConfirmEmailScreen({super.key, required this.username, this.devCode});

  final String username;
  final String? devCode;

  @override
  State<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  late String? _devCode = widget.devCode;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_code.text.trim().length != 6) {
      showSnack(context, 'Mã xác nhận gồm 6 số', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await AuthService.confirmEmail(widget.username, _code.text.trim());
      if (!mounted) return;
      showSnack(context, res['message'] ?? 'Đã xác nhận email', success: true);
      Navigator.popUntil(context, (route) => route.isFirst); // về trang đăng nhập
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      final res = await AuthService.resendConfirm(widget.username);
      if (!mounted) return;
      setState(() => _devCode = res['devCode']);
      showSnack(context, res['message'] ?? 'Đã gửi lại mã');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận email')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.mark_email_unread_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('Nhập mã 6 số đã gửi về email để kích hoạt tài khoản',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, letterSpacing: 12, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _confirm,
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Kích hoạt tài khoản'),
          ),
          TextButton(onPressed: _resend, child: const Text('Gửi lại mã')),
          if (_devCode != null) ...[const SizedBox(height: 12), DevCodeBanner(code: _devCode!)],
        ],
      ),
    );
  }
}
