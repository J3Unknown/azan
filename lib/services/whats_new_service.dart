import 'dart:convert';

import 'package:azan/data/app_updates.dart';
import 'package:azan/utils/helpers/app_language.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:flutter/material.dart';

class WhatsNewService {
  static const _seenKey = 'seen_app_updates';
  static bool _showing = false;

  static Future<void> showIfNeeded(
    BuildContext context, {
    List<String> updates = currentAppUpdates,
    bool force = false,
  }) async {
    if (_showing || updates.isEmpty || !context.mounted) return;
    _showing = true;
    try {
      final snapshot = jsonEncode(updates);
      if (!force && HiveManager.getMeta(_seenKey) == snapshot) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          icon: const Icon(Icons.campaign_outlined),
          title: Text(context.tr('What’s new')),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final update in updates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(context.tr(update))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Got it')),
            ),
          ],
        ),
      );
      await HiveManager.addUpdateMetaData(_seenKey, snapshot);
    } catch (error) {
      // Release notes must not prevent startup if local storage is unavailable.
      debugPrint('Unable to show app updates: $error');
    } finally {
      _showing = false;
    }
  }
}
