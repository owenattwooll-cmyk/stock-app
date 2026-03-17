import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 700;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tightHeight = constraints.hasBoundedHeight && constraints.maxHeight < 110;
        final veryTightHeight = constraints.hasBoundedHeight && constraints.maxHeight < 90;
        final padding = compact
            ? 14.0
            : veryTightHeight
                ? 10.0
                : tightHeight
                    ? 12.0
                    : 16.0;
        final labelStyle = theme.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF6B7280),
          fontSize: veryTightHeight ? 12 : null,
        );
        final valueStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              fontSize: compact
                  ? 18
                  : veryTightHeight
                      ? 18
                      : tightHeight
                          ? 20
                          : null,
            );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.8),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(22, 30, 58, 0.06),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
              SizedBox(height: veryTightHeight ? 2 : tightHeight ? 4 : 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: valueStyle),
              ),
              if (subtitle != null) ...[
                SizedBox(height: veryTightHeight ? 2 : 4),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
