import 'dart:math';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

class FaceException implements Exception {
  FaceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 5a. NHẬN DIỆN KHUÔN MẶT bằng Google ML Kit (chạy ngay trên máy, không cần mạng)
/// - Chụp ảnh bằng camera trước
/// - ML Kit tìm khuôn mặt + các đường viền (mắt, mũi, môi, cằm...)
/// - Chuẩn hóa toạ độ theo khoảng cách 2 mắt -> "vector khuôn mặt"
/// - Server so vector này với mẫu đã đăng ký
class FaceService {
  static final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true, // xác suất mở mắt -> chống dùng ảnh nhắm mắt
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  static const _contourTypes = [
    FaceContourType.face,
    FaceContourType.leftEyebrowTop,
    FaceContourType.rightEyebrowTop,
    FaceContourType.leftEye,
    FaceContourType.rightEye,
    FaceContourType.noseBridge,
    FaceContourType.noseBottom,
    FaceContourType.upperLipTop,
    FaceContourType.lowerLipBottom,
  ];

  /// Chụp 1 ảnh và trả về vector khuôn mặt
  static Future<List<double>> captureVector() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1080,
      imageQuality: 90,
    );
    if (photo == null) throw FaceException('Bạn chưa chụp ảnh');

    final faces = await _detector.processImage(InputImage.fromFilePath(photo.path));
    if (faces.isEmpty) throw FaceException('Không tìm thấy khuôn mặt - chụp lại nơi đủ sáng');
    if (faces.length > 1) throw FaceException('Trong ảnh có nhiều khuôn mặt - chỉ để 1 người');

    final face = faces.first;
    if ((face.headEulerAngleY ?? 0).abs() > 15 || (face.headEulerAngleZ ?? 0).abs() > 15) {
      throw FaceException('Hãy nhìn thẳng vào camera');
    }
    final l = face.leftEyeOpenProbability, r = face.rightEyeOpenProbability;
    if (l != null && r != null && (l < 0.4 || r < 0.4)) {
      throw FaceException('Hãy mở mắt khi chụp');
    }
    return _toVector(face);
  }

  static List<double> _toVector(Face face) {
    Point<double> center(List<Point<int>> pts) {
      double x = 0, y = 0;
      for (final p in pts) {
        x += p.x;
        y += p.y;
      }
      return Point(x / pts.length, y / pts.length);
    }

    final contours = <List<Point<int>>>[];
    for (final t in _contourTypes) {
      final c = face.contours[t];
      if (c == null || c.points.isEmpty) {
        throw FaceException('Không nhận rõ khuôn mặt - chụp gần hơn, đủ sáng');
      }
      contours.add(c.points);
    }

    // Gốc toạ độ = giữa 2 mắt, đơn vị = khoảng cách 2 mắt, xoay cho 2 mắt nằm ngang
    final le = center(face.contours[FaceContourType.leftEye]!.points);
    final re = center(face.contours[FaceContourType.rightEye]!.points);
    final cx = (le.x + re.x) / 2, cy = (le.y + re.y) / 2;
    final dx = re.x - le.x, dy = re.y - le.y;
    final eyeDist = sqrt(dx * dx + dy * dy);
    if (eyeDist < 1) throw FaceException('Khuôn mặt quá nhỏ - đưa camera lại gần');
    final angle = atan2(dy, dx);
    final cosA = cos(-angle), sinA = sin(-angle);

    final vector = <double>[];
    for (final pts in contours) {
      for (final p in pts) {
        final x = (p.x - cx) / eyeDist, y = (p.y - cy) / eyeDist;
        vector.add(double.parse((x * cosA - y * sinA).toStringAsFixed(4)));
        vector.add(double.parse((x * sinA + y * cosA).toStringAsFixed(4)));
      }
    }
    return vector;
  }

  /// Trung bình nhiều lần chụp -> mẫu khuôn mặt ổn định hơn
  static List<double> average(List<List<double>> vectors) {
    final n = vectors.first.length;
    if (vectors.any((v) => v.length != n)) {
      throw FaceException('Các lần chụp không đồng nhất - thử lại');
    }
    return List.generate(n, (i) {
      final s = vectors.fold<double>(0, (sum, v) => sum + v[i]);
      return double.parse((s / vectors.length).toStringAsFixed(4));
    });
  }
}
