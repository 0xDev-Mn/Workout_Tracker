import 'package:flutter/material.dart';

import '../models/body_weight_entry.dart';
import '../services/body_weight_storage.dart';
import '../services/workout_events.dart';
import '../theme/app_theme.dart';
import '../utils/workout_format.dart';
import '../widgets/body_weight_sheet.dart';
import '../widgets/trend_line_chart.dart';

enum _Range { days30, days90, all }

class BodyWeightScreen extends StatefulWidget {
  const BodyWeightScreen({super.key});

  @override
  State<BodyWeightScreen> createState() => _BodyWeightScreenState();
}

class _BodyWeightScreenState extends State<BodyWeightScreen> {
  List<BodyWeightEntry> _entries = []; // oldest first
  bool _loading = true;
  _Range _range = _Range.days90;

  @override
  void initState() {
    super.initState();
    _load();
    WorkoutEvents.changes.addListener(_load);
  }

  @override
  void dispose() {
    WorkoutEvents.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await BodyWeightStorage.getEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  DateTime? get _since {
    final now = DateTime.now();
    switch (_range) {
      case _Range.days30:
        return DateTime(now.year, now.month, now.day - 29);
      case _Range.days90:
        return DateTime(now.year, now.month, now.day - 89);
      case _Range.all:
        return null;
    }
  }

  Future<void> _confirmDelete(BodyWeightEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete this entry?'),
        content: Text(
          '${formatWeight(entry.kg)} $unitLabel on '
          '${formatLongDate(entry.date)} will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: context.colors.muted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await BodyWeightStorage.delete(entry.id);
    WorkoutEvents.notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Body weight',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmpty(context)
              : _buildContent(context),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ElevatedButton.icon(
            onPressed: () => showBodyWeightSheet(context),
            icon: const Icon(Icons.add_rounded, size: 22),
            label: const Text('Log weight'),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monitor_weight_outlined,
                size: 44, color: context.colors.muted),
            const SizedBox(height: 14),
            Text('No weigh-ins yet', style: t.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Log your weight to see how it changes over time.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final since = _since;

    final inRange = since == null
        ? _entries
        : _entries.where((e) => !e.date.isBefore(since)).toList();

    final latest = _entries.last;
    final change = inRange.length >= 2 ? latest.kg - inRange.first.kg : null;
    final newestFirst = _entries.reversed.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _SummaryRow(
          current: '${formatWeight(latest.kg)} $unitLabel',
          change: change == null
              ? '—'
              : '${change >= 0 ? '+' : '−'}'
                  '${formatWeight(change.abs())} $unitLabel',
          entries: '${inRange.length}',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final range in _Range.values)
                      ChoiceChip(
                        label: Text(_rangeLabel(range)),
                        selected: _range == range,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _range = range),
                        selectedColor: AppColors.accent,
                        backgroundColor: context.colors.bg,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: _range == range
                                ? AppColors.accent
                                : context.colors.border,
                          ),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _range == range
                              ? AppColors.onAccent
                              : context.colors.ink,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (inRange.length < 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Log at least two weigh-ins in this period to see a trend.',
                        textAlign: TextAlign.center,
                        style: t.bodySmall?.copyWith(fontSize: 14),
                      ),
                    ),
                  )
                else ...[
                  TrendLineChart(values: inRange.map((e) => e.kg).toList()),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatShortDate(inRange.first.date),
                          style: t.bodySmall),
                      Text(formatShortDate(inRange.last.date),
                          style: t.bodySmall),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('History', style: t.titleMedium),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < newestFirst.length; i++)
                _EntryRow(
                  entry: newestFirst[i],
                  showDivider: i < newestFirst.length - 1,
                  onEdit: () =>
                      showBodyWeightSheet(context, existing: newestFirst[i]),
                  onDelete: () => _confirmDelete(newestFirst[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _rangeLabel(_Range range) {
    switch (range) {
      case _Range.days30:
        return '30 days';
      case _Range.days90:
        return '90 days';
      case _Range.all:
        return 'All time';
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String current;
  final String change;
  final String entries;

  const _SummaryRow({
    required this.current,
    required this.change,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.colors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );

    Widget divider() =>
        Container(width: 1, height: 32, color: context.colors.border);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          stat(current, 'Current'),
          divider(),
          stat(change, 'Change'),
          divider(),
          stat(entries, 'Weigh-ins'),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final BodyWeightEntry entry;
  final bool showDivider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntryRow({
    required this.entry,
    required this.showDivider,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return InkWell(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 4, top: 6, bottom: 6),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: context.colors.border))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(formatLongDate(entry.date), style: t.bodyMedium),
            ),
            Text(
              '${formatWeight(entry.kg)} $unitLabel',
              style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: context.colors.muted,
              ),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 20, color: context.colors.ink),
                      const SizedBox(width: 8),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 20, color: context.colors.error),
                      const SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: TextStyle(color: context.colors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}