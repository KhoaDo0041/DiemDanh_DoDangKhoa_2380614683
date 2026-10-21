import 'package:diemdanh_dodangkhoa_2380614683/services/data_service.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/format.dart';
import 'package:diemdanh_dodangkhoa_2380614683/utils/session.dart';
import 'package:diemdanh_dodangkhoa_2380614683/widgets/common.dart';
import 'package:flutter/material.dart';

const roleLabels = {'Student': 'Sinh viên', 'Lecturer': 'Giảng viên', 'Admin': 'Quản trị'};

/// YÊU CẦU 4: CRUD NGƯỜI DÙNG (Admin)
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Json>? _users;
  String? _role; // null = tất cả
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await DataService.users(role: _role, search: _search.text.trim());
      if (mounted) setState(() => _users = list);
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  Future<void> _openForm([Json? user]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UserForm(user: user),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Json u) async {
    if (!await confirmDialog(context, 'Xóa tài khoản',
        'Xóa ${u['fullName']} (${u['userName']})? Toàn bộ điểm danh của tài khoản này cũng bị xóa.',
        ok: 'Xóa', danger: true)) {
      return;
    }
    try {
      await DataService.deleteUser(u['id']);
      if (mounted) showSnack(context, 'Đã xóa', success: true);
      _load();
    } catch (e) {
      if (mounted) await handleError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    return Scaffold(
      appBar: AppBar(title: const Text('Người dùng')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'userFab',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Thêm'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, MSSV, email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _load),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [null, 'Student', 'Lecturer', 'Admin'].map((r) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(r == null ? 'Tất cả' : roleLabels[r]!),
                    selected: _role == r,
                    onSelected: (_) {
                      setState(() => _role = r);
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: users == null
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? EmptyView(icon: Icons.people_outline, message: 'Không có người dùng', onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 90),
                          children: users.map((u) {
                            final role = '${u['role']}';
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: switch (role) {
                                    'Admin' => Colors.red.shade100,
                                    'Lecturer' => Colors.deepPurple.shade100,
                                    _ => Colors.teal.shade100,
                                  },
                                  child: Text(initials('${u['fullName']}')),
                                ),
                                title: Text('${u['fullName']}'),
                                subtitle: Text('${roleLabels[role] ?? role}  •  ${u['userName']}'
                                    '${(u['code'] ?? '').toString().isNotEmpty ? '  •  ${u['code']}' : ''}'
                                    '\n${u['email']}${u['emailConfirmed'] == true ? '' : '  (chưa xác nhận)'}'),
                                isThreeLine: true,
                                onTap: () => _openForm(u),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) => v == 'edit' ? _openForm(u) : _delete(u),
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
          ),
        ],
      ),
    );
  }
}

/// Form thêm / sửa người dùng
class _UserForm extends StatefulWidget {
  const _UserForm({this.user});

  final Json? user;

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _formKey = GlobalKey<FormState>();
  late final _username = TextEditingController(text: widget.user?['userName'] ?? '');
  late final _email = TextEditingController(text: widget.user?['email'] ?? '');
  late final _fullName = TextEditingController(text: widget.user?['fullName'] ?? '');
  late final _code = TextEditingController(text: widget.user?['code'] ?? '');
  final _password = TextEditingController();
  late String _role = widget.user?['role'] ?? 'Student';
  bool _saving = false;

  bool get _isEdit => widget.user != null;

  @override
  void dispose() {
    for (final c in [_username, _email, _fullName, _code, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await DataService.updateUser(widget.user!['id'], {
          'email': _email.text.trim(),
          'fullName': _fullName.text.trim(),
          'code': _code.text.trim(),
          'role': _role,
          'newPassword': _password.text.isEmpty ? null : _password.text,
        });
      } else {
        await DataService.createUser({
          'username': _username.text.trim(),
          'email': _email.text.trim(),
          'password': _password.text,
          'fullName': _fullName.text.trim(),
          'code': _code.text.trim(),
          'role': _role,
        });
      }
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Đã cập nhật' : 'Đã thêm tài khoản', success: true);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? 'Sửa tài khoản' : 'Thêm tài khoản',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: roleLabels.entries
                    .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
                    .toList(),
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                enabled: !_isEdit,
                decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
                validator: (v) => (v == null || v.trim().length < 3) ? 'Ít nhất 3 ký tự' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập họ tên' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _code,
                decoration: InputDecoration(labelText: _role == 'Student' ? 'MSSV' : 'Mã giảng viên / mã'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: _isEdit ? 'Mật khẩu mới (bỏ trống = giữ nguyên)' : 'Mật khẩu (VD: Abc@123)'),
                validator: (v) {
                  if (_isEdit && (v == null || v.isEmpty)) return null;
                  return (v == null || v.length < 6) ? 'Ít nhất 6 ký tự, có hoa, thường, số, ký tự đặc biệt' : null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_isEdit ? 'Lưu thay đổi' : 'Thêm tài khoản'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
