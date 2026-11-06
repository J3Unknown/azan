import 'dart:convert';

import 'package:azan/utils/helpers/app_language.dart';
import 'package:azan/utils/helpers/colors_manager.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  static final Uri _latestReleaseUri = Uri.parse(
    'https://api.github.com/repos/J3Unknown/azan/releases/latest',
  );

  static Future<void> checkAndPrompt(BuildContext context) async {
    final update = await _checkForUpdate();
    if (update == null || !context.mounted) return;

    final skippedVersion = HiveManager.getMeta('skipped_update_version');
    if (skippedVersion == update.version) return;

    final shouldOpenRelease = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF242422),
        title: Text(
          context.tr('Update available'),
          style: const TextStyle(color: ColorsManager.primaryGoldLight),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 340),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr('A new version of Azan is available')}: ${update.version}',
                  style: const TextStyle(color: ColorsManager.textPrimary),
                ),
                if (update.notes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    update.notes,
                    style: const TextStyle(
                      color: ColorsManager.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Later')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsManager.primaryGoldDark,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('View update')),
          ),
        ],
      ),
    );

    if (shouldOpenRelease == true) {
      await launchUrl(update.url, mode: LaunchMode.externalApplication);
    } else {
      await HiveManager.addUpdateMetaData(
        'skipped_update_version',
        update.version,
      );
    }
  }

  static Future<_AppUpdate?> _checkForUpdate() async {
    try {
      final response = await http
          .get(
            _latestReleaseUri,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Azan-App-Update-Check',
            },
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;

      final release = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = release['tag_name'] as String?;
      final url = release['html_url'] as String?;
      if (tag == null || url == null) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final latestVersion = _numericVersion(tag);
      final installedVersion = _numericVersion(
        '${packageInfo.version}+${packageInfo.buildNumber}',
      );
      if (latestVersion == null ||
          installedVersion == null ||
          _compareVersions(latestVersion, installedVersion) <= 0) {
        return null;
      }

      return _AppUpdate(
        version: tag,
        notes: (release['body'] as String? ?? '').trim(),
        url: Uri.tryParse(url) ?? _latestReleaseUri,
      );
    } catch (_) {
      // An update check should never prevent the user from opening the app.
      return null;
    }
  }

  static List<int>? _numericVersion(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final match = RegExp(
      r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?',
    ).firstMatch(normalized);
    if (match == null) return null;
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4) ?? '0'),
    ];
  }

  static int _compareVersions(List<int> left, List<int> right) {
    for (var index = 0; index < 4; index++) {
      final comparison = left[index].compareTo(right[index]);
      if (comparison != 0) return comparison;
    }
    return 0;
  }
}

class _AppUpdate {
  final String version;
  final String notes;
  final Uri url;

  const _AppUpdate({
    required this.version,
    required this.notes,
    required this.url,
  });
}
