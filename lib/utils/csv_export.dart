import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'file_export_helper.dart';

Future<void> exportCsvWithFeedback({
  required BuildContext context,
  required String baseName,
  required List<String> headers,
  required List<List<Object?>> rows,
}) async {
  final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
  final filename = '${baseName}_$stamp.csv';
  final csv = buildCsv(
    headers: headers,
    rows: rows,
  );

  try {
    final saved = await saveTextFile(
      filename: filename,
      content: csv,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved ? 'Export saved: $filename' : 'Export cancelled.'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export failed: $error'),
      ),
    );
  }
}

String buildCsv({
  required List<String> headers,
  required List<List<Object?>> rows,
}) {
  final lines = <String>[
    headers.map(_escapeCsvValue).join(','),
    ...rows.map((row) => row.map(_escapeCsvValue).join(',')),
  ];
  return lines.join('\r\n');
}

String _escapeCsvValue(Object? value) {
  final text = value?.toString() ?? '';
  final escaped = text.replaceAll('"', '""');
  if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n') || escaped.contains('\r')) {
    return '"$escaped"';
  }
  return escaped;
}
