import 'package:diemdanh_dodangkhoa_2380614683/services/auth_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/face_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:flutter/material.dart';

/// 5a. ĐĂNG KÝ KHUÔN MẶT: chụp 3 lần, lấy trung bình làm mẫu
class FaceEnrollScreen extends StatefulWidget {
  const FaceEnrollScreen({super.key});

  @override
  State<FaceEnrollScreen> createState() => _FaceEnrollScreenState();
}

class _FaceEnrollScreenState extends State<FaceEnrollScreen> {
  static const _needed = 3;
  final _samples = <List<double>>[];
  bool _busy = false;

  Future<void> _capture() async {
    setState(() => _busy = true);
    try {
      final v = await FaceService.captureVector();
      setState(() => _samples.add(v));
      if (_samples.length >= _needed) {
        await AuthService.faceEnroll(FaceService.average(_samples));
        if (!mounted) return;
        showSnack(context, 'Đã đăng ký khuôn mặt - giờ có thể đăng nhập bằng khuôn mặt', success: true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) await handleError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final done = _samples.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký khuôn mặt')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(value: done / _needed, strokeWidth: 8, backgroundColor: c.primaryContainer),
                  Icon(Icons.face, size: 90, color: c.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Đã chụp $done/$_needed ảnh',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Chụp 3 ảnh khuôn mặt (nhìn thẳng, đủ sáng, mở mắt). '
            'App trích các điểm đặc trưng bằng Google ML Kit và lưu mẫu lên server - không lưu ảnh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _capture,
            icon: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Icon(Icons.camera_front),
            label: Text(done == 0 ? 'Bắt đầu chụp' : 'Chụp ảnh ${done + 1}'),
          ),
          if (done > 0)
            TextButton(onPressed: () => setState(_samples.clear), child: const Text('Chụp lại từ đầu')),
        ],
      ),
    );
  }
}
