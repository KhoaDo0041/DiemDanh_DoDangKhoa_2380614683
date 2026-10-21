import 'package:diemdanh_dodangkhoa_2380614683/config/app_config.dart';
import 'package:diemdanh_dodangkhoa_2380614683/screens/common/face_enroll_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/auth_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/location_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/format.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:flutter/material.dart';

/// Trang Tài khoản dùng chung cho 3 vai trò
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.user});

  final CurrentUser user;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await AuthService.me();
      if (mounted) setState(() => _me = me);
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  Future<void> _enrollFace() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const FaceEnrollScreen()));
    if (ok == true) _load();
  }

  Future<void> _removeFace() async {
    if (!await confirmDialog(context, 'Xóa khuôn mặt', 'Sẽ không đăng nhập bằng khuôn mặt được nữa.', danger: true)) return;
    try {
      await AuthService.faceRemove();
      _load();
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  // 5b. Chia sẻ vị trí hiện tại qua Zalo / Messenger / SMS...
  Future<void> _shareLocation() async {
    setState(() => _sharing = true);
    try {
      final p = await LocationService.current();
      await LocationService.share(p.latitude, p.longitude,
          '${widget.user.fullName} (${widget.user.roleLabel}) đang ở vị trí này:');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final me = _me;
    final hasFace = me?['hasFace'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 12),
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: c.primary,
                child: Text(initials(widget.user.fullName),
                    style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.user.fullName,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Chip(label: Text(widget.user.roleLabel), avatar: const Icon(Icons.verified_user, size: 18)),
              ),
            ),
            Card(
              child: Column(
                children: [
                  ListTile(leading: const Icon(Icons.person_outline), title: const Text('Tên đăng nhập'), subtitle: Text(widget.user.username)),
                  ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email'), subtitle: Text('${me?['email'] ?? '...'}')),
                  if ((me?['code'] ?? '').toString().isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.numbers),
                      title: Text(widget.user.isStudent ? 'MSSV' : 'Mã'),
                      subtitle: Text('${me?['code']}'),
                    ),
                ],
              ),
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.face_retouching_natural, color: hasFace ? Colors.green : null),
                    title: Text(hasFace ? 'Đã đăng ký khuôn mặt' : 'Đăng ký khuôn mặt'),
                    subtitle: Text(hasFace ? 'Có thể đăng nhập bằng khuôn mặt' : 'Để đăng nhập không cần mật khẩu'),
                    trailing: hasFace
                        ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: _removeFace)
                        : const Icon(Icons.chevron_right),
                    onTap: _enrollFace,
                  ),
                  ListTile(
                    leading: const Icon(Icons.share_location),
                    title: const Text('Chia sẻ vị trí của tôi'),
                    subtitle: const Text('Gửi link Google Maps qua Zalo, Messenger...'),
                    trailing: _sharing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right),
                    onTap: _sharing ? null : _shareLocation,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                onPressed: () async {
                  if (await confirmDialog(context, 'Đăng xuất', 'Bạn muốn đăng xuất?', ok: 'Đăng xuất') && context.mounted) {
                    await logout(context);
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
              ),
            ),
            const SizedBox(height: 16),
            Text(AppConfig.author, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
