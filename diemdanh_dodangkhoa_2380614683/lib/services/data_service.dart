import 'package:diemdanh_dodangkhoa_2380614683/services/api_client.dart';

typedef Json = Map<String, dynamic>;

List<Json> _list(dynamic data) =>
    (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

Json _map(dynamic data) => Map<String, dynamic>.from(data as Map);

/// Gọi các API dữ liệu (CRUD)
class DataService {
  // ================= NGƯỜI DÙNG (Admin) =================
  static Future<List<Json>> users({String? role, String? search}) async => _list(await ApiClient.get('Users',
      query: {if (role != null) 'role': role, if (search != null && search.isNotEmpty) 'search': search}));

  static Future<void> createUser(Json body) => ApiClient.post('Users', body);

  static Future<void> updateUser(String id, Json body) => ApiClient.put('Users/$id', body);

  static Future<void> deleteUser(String id) => ApiClient.delete('Users/$id');

  // ================= MÔN HỌC =================
  static Future<List<Json>> courses() async => _list(await ApiClient.get('Courses'));

  static Future<Json> course(int id) async => _map(await ApiClient.get('Courses/$id'));

  static Future<void> createCourse(Json body) => ApiClient.post('Courses', body);

  static Future<void> updateCourse(int id, Json body) => ApiClient.put('Courses/$id', body);

  static Future<void> deleteCourse(int id) => ApiClient.delete('Courses/$id');

  static Future<List<Json>> courseStudents(int id) async => _list(await ApiClient.get('Courses/$id/students'));

  static Future<Json> addStudent(int courseId, String codeOrUsername) async =>
      _map(await ApiClient.post('Courses/$courseId/students', {'studentCodeOrUsername': codeOrUsername}));

  static Future<void> removeStudent(int courseId, String studentId) =>
      ApiClient.delete('Courses/$courseId/students/$studentId');

  // ================= BUỔI HỌC =================
  static Future<List<Json>> sessions(int courseId) async =>
      _list(await ApiClient.get('Sessions', query: {'courseId': '$courseId'}));

  static Future<Json> openSession(
          {required int courseId, required String title, double? lat, double? lng, int radius = 100}) async =>
      _map(await ApiClient.post('Sessions', {
        'courseId': courseId,
        'title': title,
        'latitude': lat,
        'longitude': lng,
        'radiusMeters': radius,
      }));

  static Future<void> updateSession(int id, String title, int radius) =>
      ApiClient.put('Sessions/$id', {'title': title, 'radiusMeters': radius});

  static Future<void> closeSession(int id) => ApiClient.post('Sessions/$id/close');

  static Future<void> reopenSession(int id) => ApiClient.post('Sessions/$id/reopen');

  static Future<void> deleteSession(int id) => ApiClient.delete('Sessions/$id');

  /// QR động: {sessionId, code, qrContent, secondsLeft, stepSeconds}
  static Future<Json> sessionQr(int id) async => _map(await ApiClient.get('Sessions/$id/qr'));

  static Future<Json> sessionAttendances(int id) async => _map(await ApiClient.get('Sessions/$id/attendances'));

  static Future<void> setAttendance(int sessionId, String studentId, bool present) =>
      ApiClient.put('Sessions/$sessionId/attendances/$studentId', {'present': present});

  // ================= SINH VIÊN ĐIỂM DANH =================
  static Future<Json> checkIn({String? qrContent, int? sessionId, String? code, double? lat, double? lng}) async =>
      _map(await ApiClient.post('Attendance/checkin', {
        'qrContent': qrContent,
        'sessionId': sessionId,
        'code': code,
        'latitude': lat,
        'longitude': lng,
      }));

  static Future<List<Json>> myAttendance({int? courseId}) async => _list(
      await ApiClient.get('Attendance/my', query: {if (courseId != null) 'courseId': '$courseId'}));

  // ================= CẢNH BÁO CẤM THI =================
  static Future<List<Json>> myWarnings() async => _list(await ApiClient.get('Warnings/my'));

  static Future<List<Json>> courseWarnings(int courseId) async =>
      _list(await ApiClient.get('Warnings/course/$courseId'));

  static Future<List<Json>> atRisk() async => _list(await ApiClient.get('Warnings/at-risk'));

  // ================= DASHBOARD =================
  static Future<Json> adminDashboard() async => _map(await ApiClient.get('Dashboard/admin'));

  static Future<Json> lecturerDashboard() async => _map(await ApiClient.get('Dashboard/lecturer'));
}
