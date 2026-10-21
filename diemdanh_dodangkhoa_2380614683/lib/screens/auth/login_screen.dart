import 'package:diemdanh_dodangkhoa_2380614683/config/app_config.dart';
import 'package:diemdanh_dodangkhoa_2380614683/screens/auth/confirm_email_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/screens/auth/face_login_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/screens/auth/otp_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/screens/auth/register_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/api_client.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/auth_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:flutter/material.dart';

/// YÊU CẦU 2: Đăng nhập = Tên đăng nhập + Mật khẩu + OTP (bước sau)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    AuthService.lastUsername().then((u) {
      if (u != null && mounted && _username.text.isEmpty) _username.text = u;
    });
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await AuthService.login(_username.text.trim(), _password.text);
      if (!mounted) return;
      // Đúng mật khẩu -> sang bước nhập OTP
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            username: res['username'] ?? _username.text.trim(),
            password: _password.text,
            message: res['message'] ?? '',
            devCode: res['devCode'],
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // Email chưa xác nhận -> sang màn hình nhập mã xác nhận
      if (e.statusCode == 403 && e.data is Map && e.data['needConfirmEmail'] == true) {
        showSnack(context, e.message);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConfirmEmailScreen(username: e.data['username'], devCode: e.data['devCode']),
          ),
        );
      } else {
        showSnack(context, e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [c.primary, c.tertiary]),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.how_to_reg_rounded, size: 52, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(AppConfig.appName,
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  Text(AppConfig.author, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _username,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập hoặc email',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên đăng nhập' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('Đăng nhập'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FaceLoginScreen(initialUsername: _username.text.trim())),
                    ),
                    icon: const Icon(Icons.face_retouching_natural),
                    label: const Text('Đăng nhập bằng khuôn mặt'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Chưa có tài khoản?'),
                      TextButton(
                        onPressed: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: const Text('Đăng ký bằng email'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
