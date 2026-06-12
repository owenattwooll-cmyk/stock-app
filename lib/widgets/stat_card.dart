import 'package:flutter/foundation.dart';
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
    final isNativeDesktop = !kIsWeb &&
        (theme.platform == TargetPlatform.macOS ||
            theme.platform == TargetPlatform.windows ||
            theme.platform == TargetPlatform.linux);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tightHeight = constraints.hasBoundedHeight && constraints.maxHeight < 110;
        final veryTightHeight = constraints.hasBoundedHeight && constraints.maxHeight < 96;
        final hasSubtitle = subtitle != null;
        final padding = compact
            ? veryTightHeight
                ? 10.0
                : 12.0
            : isNativeDesktop && !tightHeight
                ? 12.0
                : veryTightHeight
                ? 10.0
                : tightHeight
                    ? 12.0
                    : 14.0;
        final labelStyle = theme.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF94A3B8),
          fontSize: veryTightHeight ? 11 : 12,
        );
        final valueStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF8FAFC),
              fontSize: compact
                  ? veryTightHeight
                      ? 16
                      : 18
                  : !hasSubtitle
                      ? veryTightHeight
                          ? 16
                          : tightHeight
                              ? 18
                              : 20
                      : isNativeDesktop && !tightHeight
                      ? 18
                      : veryTightHeight
                          ? 16
                          : tightHeight
                              ? 18
                              : 20,
            );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF243247)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(1, 6, 20, 0.22),
                blurRadius: 24,
                offset: Offset(0, 12),
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
              SizedBox(height: veryTightHeight ? 2 : 4),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: valueStyle),
                  ),
                ),
              ),
              if (hasSubtitle) ...[
                SizedBox(height: veryTightHeight ? 2 : 3),
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
