import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
}

class UpdateChecker {
  static const String releaseApiUrl = 'https://api.github.com/repos/RyanGAT/stock-app/releases/latest';
  static const String fallbackDownloadUrl = 'https://github.com/RyanGAT/stock-app/releases/latest';

  static Future<UpdateCheckResult?> checkForUpdate() async {
    if (kIsWeb) {
      return null;
    }

    try {
      final package = await PackageInfo.fromPlatform();
      final currentVersion = package.version.trim();
      if (currentVersion.isEmpty) {
        return null;
      }

      final response = await http.get(
        Uri.parse(releaseApiUrl),
        headers: const {
          'Accept': 'application/vnd.github+json',
        },
      );
      if (response.statusCode != 200) {
        return null;
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        return null;
      }

      final rawTag = (body['tag_name'] as String? ?? '').trim();
      final latestVersion = _normalizeVersion(rawTag);
      if (latestVersion.isEmpty || !_isNewerVersion(latestVersion, currentVersion)) {
        return null;
      }

      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        downloadUrl: (body['html_url'] as String?)?.trim().isNotEmpty == true
            ? body['html_url'] as String
            : fallbackDownloadUrl,
        releaseNotes: (body['body'] as String? ?? '').trim(),
      );
    } catch (_) {
      return null;
    }
  }

  static String _normalizeVersion(String raw) {
    final normalized = raw.startsWith('v') || raw.startsWith('V') ? raw.substring(1) : raw;
    return normalized.trim();
  }

  static bool _isNewerVersion(String latest, String current) {
    final latestParts = _numericParts(latest);
    final currentParts = _numericParts(current);
    final length = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;

    for (var i = 0; i < length; i++) {
      final latestPart = i < latestParts.length ? latestParts[i] : 0;
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      if (latestPart > currentPart) {
        return true;
      }
      if (latestPart < currentPart) {
        return false;
      }
    }

    return false;
  }

  static List<int> _numericParts(String version) {
    return version
        .split('.')
        .map((segment) => int.tryParse(segment.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
