import 'package:diemdanh_dodangkhoa_2380614683/screens/common/profile_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/screens/student/scan_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/auth_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/data_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/format.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:diemdanh_dodangkhoa_2380614683/widgets/common.dart';
import 'package:flutter/material.dart';

/// YÊU CẦU 3: SINH VIÊN (vai trò "khách hàng") -> trang sinh viên
class StudentHome extends StatefulWidget {
  const StudentHome({super.key, required this.user});

  final CurrentUser user;

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _tab = 0;
  final _homeKey = GlobalKey<_StudentDashboardState>();
  final _historyKey = GlobalKey<_HistoryTabState>();

  Future<void> _scan() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (ok == true) {
      _homeKey.currentState?.load();
      _historyKey.currentState?.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _StudentDashboard(key: _homeKey, user: widget.user, onScan: _scan),
          _HistoryTab(key: _historyKey),
          ProfileScreen(user: widget.user),
        ],
      ),
      floatingActionButton: _tab == 2
          ? null
          : FloatingActionButton.extended(
              heroTag: 'scanFab',
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Điểm danh'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Lịch sử'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }
}

// ================= TRANG CHỦ: cảnh báo cấm thi từng môn =================

class _StudentDashboard extends StatefulWidget {
  const _StudentDashboard({super.key, required this.user, required this.onScan});

  final CurrentUser user;
  final VoidCallback onScan;

  @override
  State<_StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<_StudentDashboard> {
  List<Json>? _items;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final w = await DataService.myWarnings();
      if (mounted) setState(() => _items = w);
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final risky = items?.where((i) => (i['warning']?['level'] ?? 'SAFE') != 'SAFE').length ?? 0;
    final openCount = items?.where((i) => i['hasOpenSession'] == true).length ?? 0;

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            subtitle: 'Xin chào,',
            title: widget.user.fullName,
            trailing: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white24,
              child: Text(initials(widget.user.fullName),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          if (openCount > 0)
            Card(
              color: Colors.green.shade50,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ListTile(
                leading: const Icon(Icons.campaign, color: Colors.green),
                title: Text('$openCount lớp đang mở điểm danh'),
                subtitle: const Text('Bấm để quét QR ngay'),
                trailing: const Icon(Icons.qr_code_scanner),
                onTap: widget.onScan,
              ),
            ),
          if (risky > 0)
            Card(
              color: Colors.orange.shade50,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                title: Text('$risky môn có nguy cơ cấm thi'),
                subtitle: const Text('Xem chi tiết bên dưới'),
              ),
            ),
          const SectionTitle('Chuyên cần & cảnh báo cấm thi'),
          if (items == null)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            const EmptyView(icon: Icons.school_outlined, message: 'Bạn chưa có trong lớp học nào.\nLiên hệ Admin để được thêm vào lớp.')
          else
            ...items.map(_courseCard),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _courseCard(Json c) {
    final w = Map<String, dynamic>.from(c['warning'] as Map);
    final style = WarningStyle.of(w['level']);
    final total = (w['totalSessions'] as num).toInt();
    final attended = (w['attended'] as num).toInt();
    final absences = (w['absences'] as num).toInt();
    final held = (w['heldSessions'] as num).toInt();
    final maxAbsent = (w['maxAbsent'] as num).toInt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('${c['code']}  •  ${c['lecturerName'] ?? 'Chưa có GV'}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                WarningChip(level: w['level']),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _mini('Có mặt', '$attended/$held', Colors.green.shade700),
                _mini('Vắng', '$absences', style.color),
                _mini('Được vắng', '$maxAbsent', Colors.blueGrey),
                _mini('Tổng buổi', '$total', Colors.indigo),
              ],
            ),
            const SizedBox(height: 10),
            // thanh vắng: đầy = đã chạm ngưỡng cấm thi
            LinearProgressIndicator(
              value: maxAbsent == 0
                  ? (absences > 0 ? 1.0 : 0.0)
                  : (absences / (maxAbsent + 1)).clamp(0.0, 1.0),
              color: style.color,
              backgroundColor: style.color.withValues(alpha: 0.15),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(style.icon, size: 18, color: style.color),
                const SizedBox(width: 6),
                Expanded(child: Text('${w['message']}', style: TextStyle(color: style.color))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, String value, Color color) => Expanded(
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      );
}

// ================= LỊCH SỬ ĐIỂM DANH =================

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({super.key});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  List<Json>? _items;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final list = await DataService.myAttendance();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử điểm danh')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? EmptyView(icon: Icons.history, message: 'Chưa có buổi học nào', onRetry: load)
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 90),
                    children: items.map((s) {
                      final present = s['present'] == true;
                      final open = s['isOpen'] == true;
                      final color = present ? Colors.green : (open ? Colors.blue : Colors.red);
                      final status = present
                          ? 'Có mặt lúc ${fmtTime(s['checkInTime'])}${s['method'] == 'Manual' ? ' (GV điểm danh)' : ''}'
                          : (open ? 'Đang mở - chưa điểm danh' : 'Vắng');
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Icon(present ? Icons.check : (open ? Icons.qr_code_2 : Icons.close), color: color),
                          ),
                          title: Text('${s['courseName']} - ${s['title']}'),
                          subtitle: Text('${fmtDateTime(s['startTime'])}\n$status'),
                          isThreeLine: true,
                        ),
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}
