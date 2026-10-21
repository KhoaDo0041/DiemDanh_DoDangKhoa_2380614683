import 'dart:async';

import 'package:diemdanh_dodangkhoa_2380614683/services/data_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/location_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/format.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Màn hình buổi học của giảng viên:
///  - QR ĐỘNG (5e): mã đổi mỗi 15 giây, chiếu lên cho sinh viên quét
///  - Danh sách có mặt / vắng cập nhật liên tục, điểm danh tay
///  - Vị trí sinh viên chia sẻ (5b): khoảng cách tới lớp, mở bản đồ
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.sessionId, required this.courseName});

  final int sessionId;
  final String courseName;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  Json? _qr;
  Json? _data;
  int _secondsLeft = 0;
  Timer? _tick;
  Timer? _refresh;
  bool _showQr = true;

  bool get _isOpen => _data?['session']?['isOpen'] == true;

  @override
  void initState() {
    super.initState();
    _loadAll();
    // đếm ngược QR mỗi giây, hết giờ thì lấy mã mới
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else if (_isOpen) {
        _loadQr();
      }
    });
    // cập nhật danh sách điểm danh mỗi 5 giây
    _refresh = Timer.periodic(const Duration(seconds: 5), (_) => _loadAttendances(silent: true));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadAttendances();
    if (_isOpen) await _loadQr();
  }

  Future<void> _loadQr() async {
    try {
      final qr = await DataService.sessionQr(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _qr = qr;
        _secondsLeft = (qr['secondsLeft'] as num?)?.toInt() ?? 15;
      });
    } catch (_) {
      _secondsLeft = 5; // lỗi mạng tạm thời: thử lại sau
    }
  }

  Future<void> _loadAttendances({bool silent = false}) async {
    try {
      final d = await DataService.sessionAttendances(widget.sessionId);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (!silent && mounted) await handleError(context, e);
    }
  }

  Future<void> _toggle(Json st, bool present) async {
    try {
      await DataService.setAttendance(widget.sessionId, st['studentId'], present);
      await _loadAttendances();
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  Future<void> _closeOrReopen() async {
    final open = _isOpen;
    if (open &&
        !await confirmDialog(context, 'Kết thúc điểm danh',
            'Sinh viên sẽ không quét được nữa. Các bạn chưa điểm danh sẽ tính là VẮNG.',
            ok: 'Kết thúc')) {
      return;
    }
    try {
      open ? await DataService.closeSession(widget.sessionId) : await DataService.reopenSession(widget.sessionId);
      setState(() => _qr = null);
      await _loadAll();
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final s = d?['session'];
    final students = (d?['students'] as List? ?? []).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final int present = (d?['presentCount'] as num?)?.toInt() ?? 0;
    final int total = (d?['total'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(s?['title'] ?? 'Buổi học'),
        actions: [
          IconButton(
            tooltip: _showQr ? 'Ẩn QR' : 'Hiện QR',
            icon: Icon(_showQr ? Icons.qr_code_2 : Icons.qr_code),
            onPressed: () => setState(() => _showQr = !_showQr),
          ),
        ],
      ),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (_isOpen && _showQr) _qrCard(),
                  if (!_isOpen)
                    Card(
                      color: Colors.grey.shade200,
                      child: const ListTile(
                        leading: Icon(Icons.lock_clock),
                        title: Text('Buổi học đã kết thúc điểm danh'),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Có mặt $present/$total',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                          onPressed: _closeOrReopen,
                          icon: Icon(_isOpen ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                          label: Text(_isOpen ? 'Kết thúc' : 'Mở lại'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0.0 : present / total,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  ...students.map(_studentTile),
                ],
              ),
            ),
    );
  }

  Widget _qrCard() {
    final qr = _qr;
    final double step = (qr?['stepSeconds'] as num?)?.toDouble() ?? 15;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(widget.courseName, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (qr == null)
              const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
            else
              QrImageView(data: qr['qrContent'], size: 240, backgroundColor: Colors.white),
            const SizedBox(height: 8),
            if (qr != null)
              Text('Mã buổi: ${qr['sessionId']}   •   Mã: ${qr['code']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, size: 18),
                const SizedBox(width: 4),
                Text('Mã mới sau $_secondsLeft giây'),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: step == 0 ? 0.0 : (_secondsLeft / step).clamp(0.0, 1.0),
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentTile(Json st) {
    final bool present = st['present'] == true;
    final bool out = st['outOfRange'] == true;
    final lat = (st['latitude'] as num?)?.toDouble(), lng = (st['longitude'] as num?)?.toDouble();
    final sub = <String>[
      if ((st['code'] ?? '').toString().isNotEmpty) 'MSSV ${st['code']}',
      if (present) '${st['method'] == 'Manual' ? 'Điểm danh tay' : 'Quét QR'} lúc ${fmtTime(st['checkInTime'])}',
      if (present && st['method'] != 'Manual') LocationService.distanceText(st['distanceMeters'] as num?),
    ].join('  •  ');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: present ? (out ? Colors.orange.shade100 : Colors.green.shade100) : Colors.grey.shade200,
          child: Icon(
            present ? (out ? Icons.wrong_location : Icons.check) : Icons.close,
            color: present ? (out ? Colors.orange.shade800 : Colors.green.shade700) : Colors.grey,
          ),
        ),
        title: Text(st['fullName'] ?? ''),
        subtitle: Text(out ? '$sub\n⚠ Ngoài phạm vi lớp' : sub),
        isThreeLine: out,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lat != null && lng != null)
              IconButton(
                tooltip: 'Xem vị trí trên bản đồ',
                icon: const Icon(Icons.map_outlined),
                onPressed: () => LocationService.openMap(lat, lng),
              ),
            Switch(value: present, onChanged: (v) => _toggle(st, v)),
          ],
        ),
      ),
    );
  }
}
