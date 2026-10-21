import 'package:diemdanh_dodangkhoa_2380614683/config/app_config.dart';
import 'package:diemdanh_dodangkhoa_2380614683/screens/auth/login_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/auth_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ===== APP ĐIỂM DANH SINH VIÊN - Đỗ Đăng Khoa - 2380614683 =====
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const DiemDanhApp());
}

class DiemDanhApp extends StatelessWidget {
  const DiemDanhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppConfig.appName} - ${AppConfig.author}',
      debugShowCheckedModeBanner: false,
      theme: AppConfig.theme(),
      home: const SplashScreen(),
    );
  }
}

/// Mở app: token còn hạn -> vào thẳng trang theo vai trò; không thì đăng nhập
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final user = await AuthService.currentUser();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => user == null ? const LoginScreen() : homeFor(user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
