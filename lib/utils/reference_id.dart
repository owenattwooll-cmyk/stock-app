String formatReferenceId(
  Object? raw, {
  String prefix = '',
  int length = 8,
}) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) {
    return '-';
  }

  final normalized = value.replaceAll('-', '').toUpperCase();
  final shortValue = normalized.length <= length ? normalized : normalized.substring(0, length);
  return prefix.isEmpty ? shortValue : '$prefix-$shortValue';
}
