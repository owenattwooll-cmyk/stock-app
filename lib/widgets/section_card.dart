import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.expandChild = false,
  });

  final String title;
  final Widget child;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    final isNativeDesktop = !kIsWeb &&
        (Theme.of(context).platform == TargetPlatform.macOS ||
            Theme.of(context).platform == TargetPlatform.windows ||
            Theme.of(context).platform == TargetPlatform.linux);
    final padding = compact
        ? 16.0
        : isNativeDesktop
            ? 18.0
            : 20.0;
    final spacing = compact
        ? 12.0
        : isNativeDesktop
            ? 14.0
            : 16.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF243247)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(1, 6, 20, 0.26),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: spacing),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}
