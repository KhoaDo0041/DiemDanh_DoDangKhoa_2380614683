import 'package:diemdanh_dodangkhoa_2380614683/screens/admin/courses_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/screens/admin/users_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/screens/common/profile_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/auth_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/data_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:diemdanh_dodangkhoa_2380614683/widgets/common.dart';
import 'package:flutter/material.dart';

/// YÊU CẦU 3: ADMIN -> TRANG QUẢN TRỊ
class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.user});

  final CurrentUser user;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _AdminDashboard(user: widget.user),
          const UsersScreen(),
          const CoursesScreen(),
          ProfileScreen(user: widget.user),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Người dùng'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Môn học'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }
}

class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard({required this.user});

  final CurrentUser user;

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  Json? _stats;
  List<Json>? _risk;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([DataService.adminDashboard(), DataService.atRisk()]);
      if (!mounted) return;
      setState(() {
        _stats = r[0] as Json;
        _risk = r[1] as List<Json>;
      });
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    String v(String k) => '${s?[k] ?? '-'}';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(subtitle: 'Trang quản trị', title: widget.user.fullName),
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
                StatCard(icon: Icons.school_outlined, label: 'Sinh viên', value: v('students'), color: Colors.teal),
                StatCard(icon: Icons.co_present_outlined, label: 'Giảng viên', value: v('lecturers'), color: Colors.deepPurple),
                StatCard(icon: Icons.menu_book_outlined, label: 'Môn học', value: v('courses')),
                StatCard(icon: Icons.event_note, label: 'Buổi học', value: v('sessions'), color: Colors.blueGrey),
                StatCard(icon: Icons.qr_code_2, label: 'Đang điểm danh', value: v('openSessions'), color: Colors.green),
                StatCard(icon: Icons.how_to_reg, label: 'Lượt điểm danh 7 ngày', value: v('attendancesLast7Days'), color: Colors.orange),
              ],
            ),
          ),
          SectionTitle('Sinh viên nguy cơ cấm thi', trailing: Text('${_risk?.length ?? 0}')),
          if (_risk == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_risk!.isEmpty)
            const EmptyView(icon: Icons.verified_outlined, message: 'Chưa có sinh viên nào có nguy cơ cấm thi')
          else
            ..._risk!.map((r) {
              final w = Map<String, dynamic>.from(r['warning'] as Map);
              return Card(
                child: ListTile(
                  leading: Icon(WarningStyle.of(w['level']).icon, color: WarningStyle.of(w['level']).color),
                  title: Text('${r['fullName']} (${r['code'] ?? ''})'),
                  subtitle: Text('${r['courseName']}\n${w['message']}'),
                  isThreeLine: true,
                  trailing: WarningChip(level: w['level']),
                ),
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
