import 'package:diemdanh_dodangkhoa_2380614683/screens/common/profile_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/screens/lecturer/course_detail_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/auth_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/data_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:diemdanh_dodangkhoa_2380614683/widgets/common.dart';
import 'package:flutter/material.dart';

/// YÊU CẦU 3: GIẢNG VIÊN (vai trò "nhân viên") -> Dashboard của giảng viên
class LecturerHome extends StatefulWidget {
  const LecturerHome({super.key, required this.user});

  final CurrentUser user;

  @override
  State<LecturerHome> createState() => _LecturerHomeState();
}

class _LecturerHomeState extends State<LecturerHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _LecturerDashboard(user: widget.user),
          ProfileScreen(user: widget.user),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Lớp dạy'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }
}

class _LecturerDashboard extends StatefulWidget {
  const _LecturerDashboard({required this.user});

  final CurrentUser user;

  @override
  State<_LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<_LecturerDashboard> {
  Json? _stats;
  List<Json>? _courses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([DataService.lecturerDashboard(), DataService.courses()]);
      if (!mounted) return;
      setState(() {
        _stats = r[0] as Json;
        _courses = r[1] as List<Json>;
      });
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(subtitle: 'Giảng viên', title: widget.user.fullName),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                StatCard(icon: Icons.class_outlined, label: 'Lớp đang dạy', value: '${s?['courses'] ?? '-'}'),
                StatCard(icon: Icons.groups_outlined, label: 'Sinh viên', value: '${s?['students'] ?? '-'}', color: Colors.teal),
                StatCard(icon: Icons.event_note, label: 'Buổi học', value: '${s?['sessions'] ?? '-'}', color: Colors.deepPurple),
                StatCard(icon: Icons.qr_code_2, label: 'Đang điểm danh', value: '${s?['openSessions'] ?? '-'}', color: Colors.green),
              ],
            ),
          ),
          const SectionTitle('Lớp của tôi'),
          if (_courses == null)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_courses!.isEmpty)
            const EmptyView(icon: Icons.class_outlined, message: 'Bạn chưa được phân công lớp nào.\nLiên hệ Admin.')
          else
            ..._courses!.map((c) => Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.menu_book),
                    ),
                    title: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${c['code']}  •  ${c['room'] ?? ''}\n'
                        '${c['studentCount']} SV  •  ${c['sessionCount']}/${c['totalSessions']} buổi'),
                    isThreeLine: true,
                    trailing: c['hasOpenSession'] == true
                        ? const Chip(label: Text('Đang mở'), visualDensity: VisualDensity.compact)
                        : const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(course: c)));
                      _load();
                    },
                  ),
                )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
