import 'package:diemdanh_dodangkhoa_2380614683/services/auth_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:diemdanh_dodangkhoa_2380614683/widgets/common.dart';
import 'package:flutter/material.dart';

/// YÊU CẦU 2 (bước 2): nhập mã OTP 6 số gửi qua email
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.username,
    required this.password,
    required this.message,
    this.devCode,
  });

  final String username;
  final String password; // giữ trong bộ nhớ để "Gửi lại mã"
  final String message;
  final String? devCode;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  late String _message = widget.message;
  late String? _devCode = widget.devCode;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      showSnack(context, 'Mã OTP gồm 6 số', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final user = await AuthService.verifyOtp(widget.username, _code.text.trim());
      if (!mounted) return;
      showSnack(context, 'Xin chào ${user.fullName} (${user.roleLabel})', success: true);
      goHome(context, user); // vào đúng trang theo vai trò
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      final res = await AuthService.login(widget.username, widget.password);
      if (!mounted) return;
      setState(() {
        _message = res['message'] ?? _message;
        _devCode = res['devCode'];
      });
      showSnack(context, 'Đã gửi lại mã OTP');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xác thực OTP')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.mark_email_read_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text('Tài khoản: ${widget.username}', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, letterSpacing: 12, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            onChanged: (v) {
              if (v.length == 6) _verify();
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _verify,
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Xác nhận'),
          ),
          TextButton(onPressed: _resend, child: const Text('Không nhận được mã? Gửi lại')),
          if (_devCode != null) ...[const SizedBox(height: 12), DevCodeBanner(code: _devCode!)],
        ],
      ),
    );
  }
}
