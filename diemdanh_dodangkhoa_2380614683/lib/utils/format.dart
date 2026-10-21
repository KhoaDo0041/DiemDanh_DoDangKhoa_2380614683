/// Định dạng ngày giờ kiểu Việt Nam (không cần thư viện intl)
String _two(int n) => n.toString().padLeft(2, '0');

DateTime? parseDate(dynamic iso) {
  if (iso == null) return null;
  return DateTime.tryParse('$iso')?.toLocal();
}

String fmtDateTime(dynamic iso) {
  final d = parseDate(iso);
  if (d == null) return '';
  return '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
}

String fmtDate(dynamic iso) {
  final d = parseDate(iso);
  if (d == null) return '';
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

String fmtTime(dynamic iso) {
  final d = parseDate(iso);
  if (d == null) return '';
  return '${_two(d.hour)}:${_two(d.minute)}';
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts[parts.length - 2][0] + parts.last[0]).toUpperCase();
}
