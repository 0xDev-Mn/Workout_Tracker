import 'package:file_selector/file_selector.dart' show openFile;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/backup_service.dart';
import '../services/goal_controller.dart';
import '../services/notification_service.dart';
import '../services/profile_controller.dart';
import '../services/theme_controller.dart';
import '../services/unit_controller.dart';
import '../services/workout_events.dart';
import '../theme/app_theme.dart';
import 'appearance_sheet.dart';
import 'goal_sheet.dart';
import 'onboarding_screen.dart';
import 'text_prompt_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showMessage(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: context.colors.ink),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _busy = true);

    try {
      // Step 1: write the backup file.
      String? path;
      try {
        path = await BackupService.createBackupFile();
      } catch (e) {
        await _showMessage('Could not create the backup file', '$e');
        return;
      }

      if (path == null) {
        _toast('Nothing to back up yet.');
        return;
      }

      // Step 2: open the phone's share sheet (save to Drive / Files, etc).
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path, mimeType: 'application/json')],
            subject: 'RepTracker backup',
          ),
        );
      } catch (e) {
        await _showMessage('Could not open the share sheet', '$e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);

    try {
      final file = await openFile();
      if (file == null) return;

      final data = BackupService.tryParse(await file.readAsString());

      if (data == null) {
        if (!mounted) return;
        await _showMessage(
          'Not a valid backup',
          "That file isn't a RepTracker backup, or it is damaged.",
        );
        return;
      }

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Import backup?'),
          content: Text(
            'This backup has ${data.workouts.length} '
            '${data.workouts.length == 1 ? 'workout' : 'workouts'}, '
            '${data.templates.length} '
            '${data.templates.length == 1 ? 'routine' : 'routines'} and '
            '${data.customExercises.length} custom '
            '${data.customExercises.length == 1 ? 'exercise' : 'exercises'}'
            '${data.bodyWeights.isEmpty ? '' : ', plus ${data.bodyWeights.length} body-weight entries'}.\n\n'
            "They'll be added to what you already have. Nothing is deleted, "
            'and anything you already have is skipped.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.muted,
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.ink,
              ),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final result = await BackupService.restore(data);
      WorkoutEvents.notifyChanged();
      _toast(result.message);
    } catch (e) {
      await _showMessage('Could not import that file', '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testNotification() async {
    setState(() => _busy = true);

    try {
      final report = await NotificationService.runTest();
      await _showMessage('Notification test', report);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        bottom: _busy
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _SectionLabel('Profile'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ValueListenableBuilder<String>(
              valueListenable: ProfileController.name,
              builder: (context, name, _) => _SettingsRow(
                icon: Icons.person_outline,
                title: 'Name',
                subtitle: name.isEmpty ? 'Not set' : name,
                onTap: () async {
                  final result = await showTextPrompt(
                    context,
                    title: 'Your name',
                    hint: 'First name',
                    initial: name,
                    maxLength: 24,
                  );
                  if (result != null) await ProfileController.set(result);
                },
              ),
            ),
          ),
          const SizedBox(height: 28),
          _SectionLabel('Appearance'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeController.mode,
              builder: (context, mode, _) => _SettingsRow(
                icon: Icons.brightness_6_outlined,
                title: 'Theme',
                subtitle: _themeLabel(mode),
                onTap: () => showAppearanceSheet(context),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _SectionLabel('Units'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 22,
                    color: context.colors.muted,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weight', style: t.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Your data is always saved in kg',
                          style: t.bodySmall?.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<WeightUnit>(
                    valueListenable: UnitController.unit,
                    builder: (context, unit, _) => SegmentedButton<WeightUnit>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                        ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                      ],
                      selected: {unit},
                      onSelectionChanged: (selection) async {
                        await UnitController.set(selection.first);
                        // Make Home, History and Progress redraw their numbers.
                        WorkoutEvents.notifyChanged();
                      },
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppColors.accent,
                        selectedForegroundColor: AppColors.onAccent,
                        foregroundColor: context.colors.ink,
                        side: BorderSide(color: context.colors.border),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          _SectionLabel('Training'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ValueListenableBuilder<int>(
              valueListenable: GoalController.weeklyGoal,
              builder: (context, goal, _) => _SettingsRow(
                icon: Icons.flag_outlined,
                title: 'Weekly goal',
                subtitle: goal == 0
                    ? 'Off'
                    : '$goal ${goal == 1 ? 'workout' : 'workouts'} a week',
                onTap: () => showWeeklyGoalSheet(context),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _SectionLabel('Notifications'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Send test notification',
                  subtitle: 'Check that rest timer alerts work on this phone',
                  onTap: _busy ? null : _testNotification,
                  showDivider: true,
                ),
                _SettingsRow(
                  icon: Icons.settings_outlined,
                  title: 'Open notification settings',
                  subtitle: 'Turn alerts on or off in your phone settings',
                  onTap: NotificationService.openSystemSettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _SectionLabel('Data'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.ios_share_rounded,
                  title: 'Export backup',
                  subtitle:
                      'Save your workouts, routines and custom exercises to a file',
                  onTap: _busy ? null : _export,
                  showDivider: true,
                ),
                _SettingsRow(
                  icon: Icons.file_open_outlined,
                  title: 'Import backup',
                  subtitle: 'Add data from a backup file. Nothing is deleted.',
                  onTap: _busy ? null : _import,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              'Your data lives only on this phone. Export a backup now and '
              'then, and keep the file somewhere safe like Google Drive.',
              style: t.bodySmall?.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(height: 28),
          _SectionLabel('Help'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: _SettingsRow(
              icon: Icons.waving_hand_outlined,
              title: 'Welcome tour',
              subtitle: 'Replay the intro screens',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OnboardingScreen(
                    onFinished: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: context.colors.muted,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showDivider;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: context.colors.border))
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: context.colors.muted),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: t.bodySmall?.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}