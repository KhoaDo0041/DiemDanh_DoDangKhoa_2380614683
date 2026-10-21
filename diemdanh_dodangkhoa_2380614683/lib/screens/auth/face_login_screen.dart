import 'package:diemdanh_dodangkhoa_2380614683/services/auth_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/face_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:flutter/material.dart';

/// 5a. ĐĂNG NHẬP BẰNG KHUÔN MẶT
/// Nhập tên đăng nhập -> chụp mặt -> ML Kit trích đặc trưng -> server so với mẫu đã đăng ký
class FaceLoginScreen extends StatefulWidget {
  const FaceLoginScreen({super.key, this.initialUsername = ''});

  final String initialUsername;

  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen> {
  late final _username = TextEditingController(text: widget.initialUsername);
  bool _loading = false;
  String? _status;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_username.text.trim().isEmpty) {
      showSnack(context, 'Nhập tên đăng nhập trước', error: true);
      return;
    }
    setState(() {
      _loading = true;
      _status = 'Đang nhận diện khuôn mặt...';
    });
    try {
      final vector = await FaceService.captureVector();
      setState(() => _status = 'Đang so khớp với mẫu đã đăng ký...');
      final user = await AuthService.faceLogin(_username.text.trim(), vector);
      if (!mounted) return;
      showSnack(context, 'Xin chào ${user.fullName}!', success: true);
      goHome(context, user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = e.toString());
      showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập bằng khuôn mặt')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primaryContainer,
                border: Border.all(color: c.primary, width: 3),
              ),
              child: Icon(Icons.face_retouching_natural, size: 96, color: c.primary),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _scan,
            icon: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Icon(Icons.camera_front),
            label: const Text('Quét khuôn mặt'),
          ),
          const SizedBox(height: 16),
          if (_status != null) Text(_status!, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Text(
            'Lưu ý: tài khoản phải đăng ký khuôn mặt trước (Tài khoản → Đăng ký khuôn mặt). '
            'Nhìn thẳng, đủ sáng, mở mắt khi chụp.',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
