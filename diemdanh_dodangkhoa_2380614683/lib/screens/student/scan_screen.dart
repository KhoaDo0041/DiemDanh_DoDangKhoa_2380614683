import 'package:diemdanh_dodangkhoa_2380614683/services/data_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/location_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 5e. QUÉT QR ĐỘNG ĐỂ ĐIỂM DANH + 5b. gửi kèm vị trí
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final value = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (value == null) return;
    if (!value.startsWith('DIEMDANH:')) {
      showSnack(context, 'Đây không phải mã QR điểm danh', error: true);
      return;
    }
    await _submit(qrContent: value);
  }

  Future<void> _submit({String? qrContent, int? sessionId, String? code}) async {
    setState(() => _busy = true);
    await _controller.stop();
    try {
      // Chia sẻ vị trí lúc điểm danh (không có GPS vẫn điểm danh được)
      final pos = await LocationService.tryCurrent();
      final res = await DataService.checkIn(
        qrContent: qrContent,
        sessionId: sessionId,
        code: code,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
      if (!mounted) return;
      await _showResult(true, res['message'] ?? 'Điểm danh thành công',
          '${res['courseName'] ?? ''}${res['sessionTitle'] != null ? ' - ${res['sessionTitle']}' : ''}'
          '${res['distanceMeters'] != null ? '\nKhoảng cách tới lớp: ${LocationService.distanceText(res['distanceMeters'] as num)}' : ''}'
          '${pos == null ? '\n(Không lấy được vị trí GPS)' : ''}',
          warn: res['outOfRange'] == true);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      await _showResult(false, 'Không điểm danh được', e.toString());
      if (mounted) {
        setState(() => _busy = false);
        await _controller.start();
      }
    }
  }

  Future<void> _showResult(bool ok, String title, String message, {bool warn = false}) {
    final color = !ok ? Colors.red : (warn ? Colors.orange : Colors.green);
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(ok ? (warn ? Icons.wrong_location : Icons.check_circle) : Icons.error, color: color, size: 56),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 40)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Không quét được (VD máy ảo) -> nhập tay mã buổi + mã 6 số dưới QR
  Future<void> _manualEntry() async {
    final sid = TextEditingController();
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập mã điểm danh'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sid,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Mã buổi (VD: 12)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Mã 6 số dưới QR', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Điểm danh'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final id = int.tryParse(sid.text.trim());
    if (id == null || code.text.trim().length != 6) {
      if (mounted) showSnack(context, 'Mã không hợp lệ', error: true);
      return;
    }
    await _submit(sessionId: id, code: code.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Quét QR điểm danh', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Đèn flash',
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Đổi camera',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // khung ngắm
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          if (_busy)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('Đang điểm danh + lấy vị trí...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Column(
              children: [
                const Text('Đưa mã QR trên màn hình của giảng viên vào khung',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                  onPressed: _busy ? null : _manualEntry,
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Nhập mã thủ công'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
