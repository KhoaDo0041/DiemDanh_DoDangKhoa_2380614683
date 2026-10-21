import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationException implements Exception {
  LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 5b. CHIA SẺ VỊ TRÍ
/// - Lấy GPS (giảng viên: vị trí lớp khi mở buổi; sinh viên: vị trí lúc điểm danh)
/// - Mở vị trí trên Google Maps
/// - Chia sẻ vị trí qua Zalo / Messenger / SMS...
class LocationService {
  static Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('Hãy bật định vị (GPS) trên máy');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw LocationException('Bạn chưa cấp quyền vị trí cho ứng dụng');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Lấy vị trí, lỗi thì trả null (không chặn việc điểm danh)
  static Future<Position?> tryCurrent() async {
    try {
      return await current();
    } catch (_) {
      return null;
    }
  }

  static String mapsUrl(double lat, double lng) =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  static Future<void> openMap(double lat, double lng) =>
      launchUrl(Uri.parse(mapsUrl(lat, lng)), mode: LaunchMode.externalApplication);

  static Future<void> share(double lat, double lng, String message) =>
      SharePlus.instance.share(ShareParams(text: '$message\n${mapsUrl(lat, lng)}'));

  static String distanceText(num? meters) {
    if (meters == null) return 'Không có vị trí';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.toStringAsFixed(0)} m';
  }
}
