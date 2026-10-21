import 'package:diemdanh_dodangkhoa_2380614683/screens/lecturer/session_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/data_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/location_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/format.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:diemdanh_dodangkhoa_2380614683/widgets/common.dart';
import 'package:flutter/material.dart';

/// Chi tiết môn học (Giảng viên + Admin):
///  Tab 1: CRUD buổi học
///  Tab 2: Cảnh báo cấm thi từng sinh viên (tính năng mới)
///  Tab 3 (Admin): thêm / xóa sinh viên của lớp
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.course, this.isAdmin = false});

  final Json course;
  final bool isAdmin;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  int get _id => widget.course['id'] as int;
  String get _name => '${widget.course['name']}';

  List<Json>? _sessions;
  List<Json>? _warnings;
  List<Json>? _students;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        DataService.sessions(_id),
        DataService.courseWarnings(_id),
        if (widget.isAdmin) DataService.courseStudents(_id),
      ]);
      if (!mounted) return;
      setState(() {
        _sessions = r[0];
        _warnings = r[1];
        if (widget.isAdmin) _students = r[2];
      });
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  // ---------- Buổi học ----------

  Future<void> _openSession() async {
    final title = TextEditingController(text: 'Buổi ${(_sessions?.length ?? 0) + 1}');
    final radius = TextEditingController(text: '100');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mở buổi điểm danh'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Tên buổi học')),
            const SizedBox(height: 12),
            TextField(
              controller: radius,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Bán kính lớp học (mét)'),
            ),
            const SizedBox(height: 8),
            Text('Vị trí lớp = vị trí GPS hiện tại của bạn', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mở buổi'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // 5b: lấy vị trí giảng viên làm vị trí lớp học
    final pos = await LocationService.tryCurrent();
    if (pos == null && mounted) {
      showSnack(context, 'Không lấy được GPS - buổi học sẽ không kiểm tra khoảng cách');
    }
    try {
      final res = await DataService.openSession(
        courseId: _id,
        title: title.text.trim().isEmpty ? 'Buổi học' : title.text.trim(),
        lat: pos?.latitude,
        lng: pos?.longitude,
        radius: int.tryParse(radius.text) ?? 100,
      );
      await _load();
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => SessionScreen(sessionId: res['id'] as int, courseName: _name)));
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  Future<void> _editSession(Json s) async {
    final title = TextEditingController(text: s['title']);
    final radius = TextEditingController(text: '${s['radiusMeters']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa buổi học'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Tên buổi học')),
            const SizedBox(height: 12),
            TextField(
              controller: radius,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Bán kính (mét)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DataService.updateSession(s['id'], title.text.trim(), int.tryParse(radius.text) ?? 100);
      await _load();
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  Future<void> _deleteSession(Json s) async {
    if (!await confirmDialog(context, 'Xóa buổi học', 'Xóa "${s['title']}" và toàn bộ điểm danh của buổi này?',
        ok: 'Xóa', danger: true)) {
      return;
    }
    try {
      await DataService.deleteSession(s['id']);
      await _load();
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  // ---------- Sinh viên (Admin) ----------

  Future<void> _addStudent() async {
    final ctrl = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm sinh viên vào lớp'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'MSSV hoặc tên đăng nhập'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    if (key == null || key.isEmpty) return;
    try {
      final res = await DataService.addStudent(_id, key);
      if (mounted) showSnack(context, res['message'] ?? 'Đã thêm', success: true);
      await _load();
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  Future<void> _removeStudent(Json st) async {
    if (!await confirmDialog(context, 'Xóa khỏi lớp', 'Xóa ${st['fullName']} khỏi lớp $_name?', ok: 'Xóa', danger: true)) {
      return;
    }
    try {
      await DataService.removeStudent(_id, st['studentId']);
      await _load();
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  // ---------- Giao diện ----------

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const Tab(text: 'Buổi học', icon: Icon(Icons.event_note)),
      const Tab(text: 'Cảnh báo', icon: Icon(Icons.warning_amber_rounded)),
      if (widget.isAdmin) const Tab(text: 'Sinh viên', icon: Icon(Icons.groups)),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_name),
              Text('${widget.course['code']}  •  ${widget.course['room'] ?? ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
          bottom: TabBar(tabs: tabs),
        ),
        body: TabBarView(
          children: [
            _sessionsTab(),
            _warningsTab(),
            if (widget.isAdmin) _studentsTab(),
          ],
        ),
        floatingActionButton: Builder(
          builder: (ctx) {
            return FloatingActionButton.extended(
              heroTag: 'courseFab',
              onPressed: () {
                final tab = DefaultTabController.of(ctx).index;
                if (widget.isAdmin && tab == 2) {
                  _addStudent();
                } else {
                  _openSession();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm'),
            );
          },
        ),
      ),
    );
  }

  Widget _sessionsTab() {
    final list = _sessions;
    if (list == null) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) {
      return EmptyView(icon: Icons.event_busy, message: 'Chưa có buổi học.\nBấm "Thêm" để mở buổi điểm danh.', onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 90),
        children: list.map((s) {
          final open = s['isOpen'] == true;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: open ? Colors.green.shade100 : Colors.grey.shade200,
                child: Icon(open ? Icons.qr_code_2 : Icons.event_available,
                    color: open ? Colors.green.shade700 : Colors.grey.shade700),
              ),
              title: Text(s['title'] ?? ''),
              subtitle: Text('${fmtDateTime(s['startTime'])}  •  Có mặt ${s['presentCount']}/${s['totalStudents']}'
                  '${open ? '  •  ĐANG MỞ' : ''}'),
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => SessionScreen(sessionId: s['id'] as int, courseName: _name)));
                _load();
              },
              trailing: PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? _editSession(s) : _deleteSession(s),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _warningsTab() {
    final list = _warnings;
    if (list == null) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) return EmptyView(icon: Icons.groups_outlined, message: 'Lớp chưa có sinh viên', onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 90),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Vắng quá ${widget.course['maxAbsentPercent']}% số buổi (${widget.course['totalSessions']} buổi) sẽ bị cấm thi. '
              'Chỉ tính các buổi đã kết thúc.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ...list.map((s) {
            final w = Map<String, dynamic>.from(s['warning'] as Map);
            final style = WarningStyle.of(w['level']);
            final maxAbsent = (w['maxAbsent'] as num).toInt();
            final absences = (w['absences'] as num).toInt();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${s['fullName']}  (${s['code'] ?? ''})',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        WarningChip(level: w['level']),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: maxAbsent == 0
                          ? (absences > 0 ? 1.0 : 0.0)
                          : (absences / (maxAbsent + 1)).clamp(0.0, 1.0),
                      color: style.color,
                      backgroundColor: style.color.withValues(alpha: 0.15),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 6),
                    Text(w['message'] ?? '', style: TextStyle(color: style.color)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _studentsTab() {
    final list = _students;
    if (list == null) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) {
      return EmptyView(icon: Icons.person_add_alt, message: 'Chưa có sinh viên.\nBấm "Thêm" để thêm theo MSSV.', onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 90),
        children: list
            .map((st) => Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(initials('${st['fullName']}'))),
                    title: Text('${st['fullName']}'),
                    subtitle: Text('MSSV ${st['code'] ?? '-'}  •  ${st['userName']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () => _removeStudent(st),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
