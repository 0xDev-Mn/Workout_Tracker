import 'package:flutter/material.dart';

import '../app_info.dart';
import '../theme/app_theme.dart';

/// The privacy policy, readable inside the app. The same text is published
/// on the web page the app stores link to (web/privacy-policy.html).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  List<_PolicySection> _sections() => [
      _PolicySection(
        "Summary",
        [
        "RepTracker keeps your workout data on your phone. The app has no accounts, no ads and no analytics, and it does not send your data to us or to anyone else.",
        ],
      ),
      _PolicySection(
        "Who we are",
        [
        "RepTracker is developed by ${AppInfo.developerName}. If you have any question about this policy, you can contact us at ${AppInfo.supportEmail}.",
        ],
      ),
      _PolicySection(
        "What the app stores on your phone",
        [
        "To work, RepTracker saves the following on your device:",
        "• Your workouts: exercises, sets, weights, reps, notes, workout names, dates and durations",
        "• Routines and custom exercises that you create",
        "• Body-weight entries that you log",
        "• Your settings: your name (optional), weight unit, weekly goal and appearance",
        "All of this is stored only in the app's private storage on your device.",
        ],
      ),
      _PolicySection(
        "What we do not collect",
        [
        "We do not collect, receive or have access to your personal data. RepTracker has no user accounts, does not use advertising or analytics services, does not track you, and does not send your data to any server.",
        ],
      ),
      _PolicySection(
        "Notifications",
        [
        "If you allow notifications, the app shows a rest-timer alert when your rest time is over. These alerts are created on your device. No data is sent to a server, and the app does not use push notification services. You can turn notifications off at any time in your phone's settings.",
        ],
      ),
      _PolicySection(
        "Backups and exports",
        [
        "You can export a backup file from the app's Settings. The file is created on your device and handed to the sharing option you choose, for example Google Drive, email or Files. From that moment, it is handled by the app you chose, under that app's own privacy policy. The app can also import a backup file that you select.",
        "Separately, your phone's own backup service (for example Android Auto Backup or iCloud) may copy the app's data to your Google or Apple account if you have device backup turned on. That is controlled by your device settings, not by RepTracker.",
        ],
      ),
      _PolicySection(
        "Children",
        [
        "RepTracker is not directed at children under 13, and we do not knowingly collect any information from children.",
        ],
      ),
      _PolicySection(
        "Your choices and deleting your data",
        [
        "You can delete individual workouts, routines, custom exercises and body-weight entries inside the app. Removing the app, or clearing its storage in your phone's settings, deletes all of its data from your device. Backup files that you exported stay wherever you saved them until you delete them yourself.",
        ],
      ),
      _PolicySection(
        "Security",
        [
        "Your data stays in the app's private storage on your device, protected by your phone's own security, such as your screen lock. Because we do not have your data, we cannot recover it if you lose your phone, so we recommend exporting a backup from time to time.",
        ],
      ),
      _PolicySection(
        "Changes to this policy",
        [
        "If this policy changes, we will update the date at the top of it and the version inside the app.",
        ],
      ),
      _PolicySection(
        "Contact",
        [
        "Questions about privacy? Email ${AppInfo.supportEmail}.",
        ],
      ),
      ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy policy',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('Privacy Policy', style: t.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Last updated: ${AppInfo.policyDate}',
            style: t.bodySmall?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 24),
          for (final section in _sections()) ...[
            Text(section.title, style: t.titleMedium),
            const SizedBox(height: 8),
            for (final paragraph in section.paragraphs)
              _Paragraph(paragraph),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _PolicySection {
  final String title;
  final List<String> paragraphs;

  const _PolicySection(this.title, this.paragraphs);
}

class _Paragraph extends StatelessWidget {
  final String text;

  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          height: 1.5,
          color: context.colors.ink,
        );

    final isBullet = text.startsWith('• ');

    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: isBullet ? 8 : 0),
      child: isBullet
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: style),
                Expanded(child: Text(text.substring(2), style: style)),
              ],
            )
          : Text(text, style: style),
    );
  }
}