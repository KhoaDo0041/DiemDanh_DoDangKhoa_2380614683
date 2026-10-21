import 'package:diemdanh_dodangkhoa_2380614683/screens/admin/admin_home.dart';
import 'package:diemdanh_dodangkhoa_2380614683/screens/auth/login_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/screens/lecturer/lecturer_home.dart';
import 'package:diemdanh_dodangkhoa_2380614683/screens/student/student_home.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/api_client.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/auth_service.dart';
import 'package:flutter/material.dart';

/// YÊU CẦU 3: PHÂN QUYỀN - mỗi vai trò vào đúng trang của mình
Widget homeFor(CurrentUser user) => switch (user.role) {
      'Admin' => AdminHome(user: user),
      'Lecturer' => LecturerHome(user: user),
      _ => StudentHome(user: user),
    };

void goHome(BuildContext context, CurrentUser user) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => homeFor(user)),
    (route) => false,
  );
}

Future<void> logout(BuildContext context) async {
  await AuthService.logout();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

void showSnack(BuildContext context, String message, {bool error = false, bool success = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error
          ? Colors.red.shade700
          : success
              ? Colors.green.shade700
              : null,
    ));
}

/// Hiện lỗi; nếu token hết hạn (401) thì đưa về trang đăng nhập
Future<void> handleError(BuildContext context, Object e) async {
  showSnack(context, e.toString(), error: true);
  if (e is ApiException && e.isUnauthorized) await logout(context);
}

Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String ok = 'Đồng ý', bool danger = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red.shade600, minimumSize: const Size(88, 40)) : FilledButton.styleFrom(minimumSize: const Size(88, 40)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return result == true;
}
