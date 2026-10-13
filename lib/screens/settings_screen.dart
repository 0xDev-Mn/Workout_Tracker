import 'package:file_selector/file_selector.dart' show openFile;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/backup_service.dart';
import '../services/theme_controller.dart';
import '../services/workout_events.dart';
import '../theme/app_theme.dart';
import 'appearance_sheet.dart';

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

  Future<void> _showMessage(String title, String message) {
    return showDialog<void>(
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
      final path = await BackupService.createBackupFile();

      if (path == null) {
        _toast('Nothing to back up yet.');
        return;
      }

      // Opens the phone's share sheet: save to Drive / Files, send to
      // yourself, and so on.
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'application/json')],
          subject: 'RepTracker backup',
        ),
      );
    } catch (_) {
      _toast('Could not create the backup.');
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
            '${data.customExercises.length == 1 ? 'exercise' : 'exercises'}.\n\n'
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
    } catch (_) {
      _toast('Could not import that file.');
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