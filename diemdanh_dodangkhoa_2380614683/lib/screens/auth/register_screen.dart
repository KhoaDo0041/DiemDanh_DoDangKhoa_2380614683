import 'package:diemdanh_dodangkhoa_2380614683/screens/auth/confirm_email_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/auth_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:flutter/material.dart';

/// YÊU CẦU 1: ĐĂNG KÝ TÀI KHOẢN QUA EMAIL (tài khoản sinh viên)
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _code = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [_fullName, _code, _username, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Không được để trống' : null;

  String? _passwordRule(String? v) {
    if (v == null || v.length < 6) return 'Ít nhất 6 ký tự';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Cần ít nhất 1 chữ hoa';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Cần ít nhất 1 chữ thường';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Cần ít nhất 1 chữ số';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v)) return 'Cần ít nhất 1 ký tự đặc biệt (VD: @)';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await AuthService.register(
        username: _username.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
        code: _code.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, res['message'] ?? 'Đăng ký thành công', success: true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmEmailScreen(username: _username.text.trim(), devCode: res['devCode']),
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký tài khoản')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Tài khoản sinh viên - mã xác nhận sẽ được gửi về email',
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fullName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.badge_outlined)),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'MSSV', prefixIcon: Icon(Icons.numbers)),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) {
                if (v == null || v.trim().length < 3) return 'Ít nhất 3 ký tự';
                // Giống quy định của server (ASP.NET Identity)
                if (!RegExp(r'^[a-zA-Z0-9._@+-]+$').hasMatch(v.trim())) {
                  return 'Chỉ dùng chữ không dấu, số và . _ - @ + (không có dấu cách)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) =>
                  (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? 'Email không hợp lệ' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Mật khẩu (VD: Khoa@123)',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: _passwordRule,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu', prefixIcon: Icon(Icons.lock_reset)),
              validator: (v) => v != _password.text ? 'Mật khẩu không khớp' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Đăng ký'),
            ),
          ],
        ),
      ),
    );
  }
}
