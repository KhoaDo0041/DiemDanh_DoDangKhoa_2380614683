import 'package:diemdanh_dodangkhoa_2380614683/services/api_client.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thông tin người dùng đọc từ JWT
class CurrentUser {
  CurrentUser({required this.id, required this.username, required this.fullName, required this.role});

  final String id;
  final String username;
  final String fullName;
  final String role; // Admin | Lecturer | Student

  bool get isAdmin => role == 'Admin';
  bool get isLecturer => role == 'Lecturer';
  bool get isStudent => role == 'Student';

  String get roleLabel => switch (role) {
        'Admin' => 'Quản trị viên',
        'Lecturer' => 'Giảng viên',
        _ => 'Sinh viên',
      };

  static CurrentUser fromToken(String token) {
    final d = JwtDecoder.decode(token);
    const roleKey = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';
    final raw = d['role'] ?? d[roleKey];
    final roles = raw is List ? raw.map((e) => '$e').toList() : [if (raw != null) '$raw'];
    final role = roles.contains('Admin')
        ? 'Admin'
        : roles.contains('Lecturer')
            ? 'Lecturer'
            : 'Student';
    return CurrentUser(
      id: '${d['nameid'] ?? d['sub'] ?? ''}',
      username: '${d['unique_name'] ?? d['name'] ?? ''}',
      fullName: '${d['fullName'] ?? ''}',
      role: role,
    );
  }
}

/// Tất cả chức năng tài khoản: đăng ký email, OTP, khuôn mặt, token
class AuthService {
  static const _lastUserKey = 'last_username';

  // ---------- 1. Đăng ký qua email ----------
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String? code,
  }) async {
    return Map<String, dynamic>.from(await ApiClient.post('Auth/register', {
      'username': username,
      'email': email,
      'password': password,
      'fullName': fullName,
      'code': code,
    }));
  }

  static Future<Map<String, dynamic>> confirmEmail(String username, String code) async =>
      Map<String, dynamic>.from(await ApiClient.post('Auth/confirm-email', {'username': username, 'code': code}));

  static Future<Map<String, dynamic>> resendConfirm(String username) async =>
      Map<String, dynamic>.from(await ApiClient.post('Auth/resend-confirm', {'username': username}));

  // ---------- 2. Đăng nhập: mật khẩu -> OTP email ----------
  /// Bước 1: đúng mật khẩu -> server gửi OTP (trả về {otpRequired, username, devCode?})
  static Future<Map<String, dynamic>> login(String username, String password) async =>
      Map<String, dynamic>.from(await ApiClient.post('Auth/login', {'username': username, 'password': password}));

  /// Bước 2: đúng OTP -> lưu token, trả về người dùng
  static Future<CurrentUser> verifyOtp(String username, String code) async {
    final data = await ApiClient.post('Auth/verify-otp', {'username': username, 'code': code});
    return _saveToken(data['token'], username);
  }

  // ---------- 5a. Đăng nhập bằng khuôn mặt ----------
  static Future<CurrentUser> faceLogin(String username, List<double> vector) async {
    final data = await ApiClient.post('Auth/face-login', {'username': username, 'faceVector': vector});
    return _saveToken(data['token'], username);
  }

  static Future<void> faceEnroll(List<double> vector) async =>
      ApiClient.post('Auth/face-enroll', {'faceVector': vector});

  static Future<void> faceRemove() async => ApiClient.delete('Auth/face-enroll');

  static Future<Map<String, dynamic>> me() async =>
      Map<String, dynamic>.from(await ApiClient.get('Auth/me'));

  // ---------- Token ----------
  static Future<CurrentUser> _saveToken(String token, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiClient.tokenKey, token);
    await prefs.setString(_lastUserKey, username);
    return CurrentUser.fromToken(token);
  }

  /// Token còn hạn -> người dùng; hết hạn / chưa đăng nhập -> null
  static Future<CurrentUser?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiClient.tokenKey);
    if (token == null) return null;
    try {
      if (JwtDecoder.isExpired(token)) {
        await prefs.remove(ApiClient.tokenKey);
        return null;
      }
      return CurrentUser.fromToken(token);
    } catch (_) {
      await prefs.remove(ApiClient.tokenKey);
      return null;
    }
  }

  static Future<String?> lastUsername() async =>
      (await SharedPreferences.getInstance()).getString(_lastUserKey);

  static Future<void> logout() async =>
      (await SharedPreferences.getInstance()).remove(ApiClient.tokenKey);
}
