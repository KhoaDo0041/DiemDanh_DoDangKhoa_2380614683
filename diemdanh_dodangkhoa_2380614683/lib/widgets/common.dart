import 'package:flutter/material.dart';

/// Ô số liệu trên dashboard
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.icon, required this.label, required this.value, this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Màn hình trống / lỗi có nút thử lại
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.message, this.onRetry});

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44)),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Khung vàng hiện mã OTP khi chưa cấu hình Gmail (chế độ demo)
class DevCodeBanner extends StatelessWidget {
  const DevCodeBanner({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'DEMO - chưa cấu hình Gmail nên mã không gửi email.\nMã của bạn: '),
          TextSpan(text: code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 3)),
        ]),
      ),
    );
  }
}

/// Màu + nhãn của mức cảnh báo cấm thi
class WarningStyle {
  WarningStyle(this.color, this.label, this.icon);

  final Color color;
  final String label;
  final IconData icon;

  static WarningStyle of(String? level) => switch (level) {
        'BANNED' => WarningStyle(Colors.red.shade700, 'Cấm thi', Icons.block),
        'DANGER' => WarningStyle(Colors.deepOrange, 'Nguy cơ cấm thi', Icons.warning_amber_rounded),
        'WARNING' => WarningStyle(Colors.amber.shade800, 'Cảnh báo', Icons.error_outline),
        _ => WarningStyle(Colors.green.shade600, 'An toàn', Icons.check_circle_outline),
      };
}

class WarningChip extends StatelessWidget {
  const WarningChip({super.key, required this.level});

  final String? level;

  @override
  Widget build(BuildContext context) {
    final s = WarningStyle.of(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: s.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 16, color: s.color),
          const SizedBox(width: 4),
          Text(s.label, style: TextStyle(color: s.color, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// Tiêu đề nhóm
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 6),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Header gradient đầu trang chủ
class GradientHeader extends StatelessWidget {
  const GradientHeader({super.key, required this.title, required this.subtitle, this.trailing});

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.primary, c.tertiary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
