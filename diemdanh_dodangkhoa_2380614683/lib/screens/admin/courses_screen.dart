import 'package:diemdanh_dodangkhoa_2380614683/screens/lecturer/course_detail_screen.dart';
import 'package:diemdanh_dodangkhoa_2380614683/services/data_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:diemdanh_dodangkhoa_2380614683/widgets/common.dart';
import 'package:flutter/material.dart';

/// YÊU CẦU 4: CRUD MÔN HỌC (Admin) - phân công giảng viên, quy định % vắng
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<Json>? _courses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await DataService.courses();
      if (mounted) setState(() => _courses = list);
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  Future<void> _openForm([Json? course]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CourseForm(course: course),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Json c) async {
    if (!await confirmDialog(context, 'Xóa môn học',
        'Xóa "${c['name']}"? Toàn bộ buổi học, danh sách sinh viên và điểm danh của môn sẽ bị xóa.',
        ok: 'Xóa', danger: true)) {
      return;
    }
    try {
      await DataService.deleteCourse(c['id']);
      if (mounted) showSnack(context, 'Đã xóa môn học', success: true);
      _load();
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _courses;
    return Scaffold(
      appBar: AppBar(title: const Text('Môn học')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'courseAddFab',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm môn'),
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? EmptyView(icon: Icons.menu_book_outlined, message: 'Chưa có môn học', onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 90),
                    children: list.map((c) {
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: const Icon(Icons.menu_book),
                          ),
                          title: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${c['code']}  •  ${c['room'] ?? '-'}\n'
                              'GV: ${c['lecturerName'] ?? 'chưa phân công'}  •  ${c['studentCount']} SV  •  '
                              '${c['totalSessions']} buổi, vắng ≤ ${c['maxAbsentPercent']}%'),
                          isThreeLine: true,
                          onTap: () async {
                            await Navigator.push(context,
                                MaterialPageRoute(builder: (_) => CourseDetailScreen(course: c, isAdmin: true)));
                            _load();
                          },
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) => v == 'edit' ? _openForm(c) : _delete(c),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Sửa')),
                              PopupMenuItem(value: 'delete', child: Text('Xóa')),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}

class _CourseForm extends StatefulWidget {
  const _CourseForm({this.course});

  final Json? course;

  @override
  State<_CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends State<_CourseForm> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.course?['code'] ?? '');
  late final _name = TextEditingController(text: widget.course?['name'] ?? '');
  late final _room = TextEditingController(text: widget.course?['room'] ?? '');
  late final _total = TextEditingController(text: '${widget.course?['totalSessions'] ?? 15}');
  late final _percent = TextEditingController(text: '${widget.course?['maxAbsentPercent'] ?? 20}');
  late String? _lecturerId = widget.course?['lecturerId'];
  List<Json> _lecturers = [];
  bool _saving = false;

  bool get _isEdit => widget.course != null;

  @override
  void initState() {
    super.initState();
    DataService.users(role: 'Lecturer').then((l) {
      if (mounted) setState(() => _lecturers = l);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _room, _total, _percent]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'code': _code.text.trim(),
      'name': _name.text.trim(),
      'room': _room.text.trim(),
      'totalSessions': int.parse(_total.text.trim()),
      'maxAbsentPercent': int.parse(_percent.text.trim()),
      'lecturerId': _lecturerId,
    };
    try {
      _isEdit
          ? await DataService.updateCourse(widget.course!['id'], body)
          : await DataService.createCourse(body);
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Đã cập nhật môn học' : 'Đã thêm môn học', success: true);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _number(String? v, int min, int max) {
    final n = int.tryParse(v?.trim() ?? '');
    return (n == null || n < min || n > max) ? 'Nhập số từ $min đến $max' : null;
  }

  @override
  Widget build(BuildContext context) {
    // giữ lecturerId hợp lệ với danh sách
    final validLecturer = _lecturers.any((l) => l['id'] == _lecturerId) ? _lecturerId : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? 'Sửa môn học' : 'Thêm môn học',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Mã môn (VD: LTDD01)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập mã môn' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Tên môn học'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên môn' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(controller: _room, decoration: const InputDecoration(labelText: 'Phòng học')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _total,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tổng số buổi'),
                      validator: (v) => _number(v, 1, 100),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _percent,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '% vắng tối đa'),
                      validator: (v) => _number(v, 0, 100),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Giảng viên phụ trách'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    isDense: true,
                    value: validLecturer,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Chưa phân công')),
                      ..._lecturers.map((l) => DropdownMenuItem<String?>(
                            value: l['id'] as String,
                            child: Text('${l['fullName']} (${l['userName']})'),
                          )),
                    ],
                    onChanged: (v) => setState(() => _lecturerId = v),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_isEdit ? 'Lưu thay đổi' : 'Thêm môn học'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
