import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/workout_events.dart';
import '../services/workout_storage.dart';
import '../theme/app_theme.dart';
import '../utils/workout_format.dart';
import 'rename_workout_dialog.dart';
import 'workout_actions.dart';
import 'workout_details.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  final List<Workout> workouts;

  const WorkoutHistoryScreen({
    super.key,
    required this.workouts,
  });

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  late List<Workout> workouts;

  // Calendar view.
  bool _calendarView = false;
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    workouts = List.from(widget.workouts);

    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  Future<void> confirmDelete(
    BuildContext context,
    Workout workout,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete workout?'),
        content: const Text(
          'This workout will be removed from your history.',
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

    if (shouldDelete != true) {
      return;
    }

    await WorkoutStorage.deleteWorkout(workout);
    WorkoutEvents.notifyChanged();

    if (!mounted) return;

    setState(() {
      workouts.remove(workout);
    });
  }

  Future<void> _openDetails(Workout workout) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutDetailsScreen(workout: workout),
      ),
    );

    // If it was deleted on the details screen it is already gone from
    // storage; either way rebuild so renamed workouts show their new name.
    if (!mounted) return;
    setState(() {
      if (deleted == true) workouts.remove(workout);
    });
  }

  Future<void> _repeat(Workout workout) => repeatWorkout(context, workout);

  Future<void> _rename(Workout workout) async {
    final changed = await renameWorkoutFlow(context, workout);
    if (changed && mounted) setState(() {});
  }

  int _monthKey(DateTime d) => d.year * 12 + d.month;

  List<Widget> _buildItems(BuildContext context) {
    final items = <Widget>[];

    for (var i = 0; i < workouts.length; i++) {
      final workout = workouts[i];
      final isFirstOfMonth =
          i == 0 || _monthKey(workouts[i - 1].date) != _monthKey(workout.date);
      final nextSameMonth = i + 1 < workouts.length &&
          _monthKey(workouts[i + 1].date) == _monthKey(workout.date);

      if (isFirstOfMonth) {
        items.add(
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 24, bottom: 4),
            child: Text(
              formatMonthHeader(workout.date),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
      }

      items.add(
        _HistoryRow(
          workout: workout,
          showDivider: nextSameMonth,
          onTap: () => _openDetails(workout),
          onRepeat: () => _repeat(workout),
          onRename: () => _rename(workout),
          onDelete: () => confirmDelete(context, workout),
        ),
      );
    }

    return items;
  }

  void _changeMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    final now = DateTime.now();

    DateTime selected;
    if (next.year == now.year && next.month == now.month) {
      selected = DateTime(now.year, now.month, now.day);
    } else {
      final dates = workouts
          .where((w) => w.date.year == next.year && w.date.month == next.month)
          .map((w) => w.date)
          .toList();

      if (dates.isEmpty) {
        selected = DateTime(next.year, next.month, 1);
      } else {
        final latest = dates.reduce((a, b) => a.isAfter(b) ? a : b);
        selected = DateTime(latest.year, latest.month, latest.day);
      }
    }

    setState(() {
      _visibleMonth = next;
      _selectedDay = selected;
    });
  }

  Widget _buildCalendar(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Workouts grouped by calendar day.
    final byDay = <DateTime, List<Workout>>{};
    for (final w in workouts) {
      final day = DateTime(w.date.year, w.date.month, w.date.day);
      byDay.putIfAbsent(day, () => []).add(w);
    }

    final first = _visibleMonth;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final blanks = first.weekday - 1; // weeks start on Monday
    final isCurrentMonth = first.year == now.year && first.month == now.month;

    final monthCount = workouts
        .where((w) => w.date.year == first.year && w.date.month == first.month)
        .length;

    final selectedWorkouts = [...(byDay[_selectedDay] ?? <Workout>[])]
      ..sort((a, b) => b.date.compareTo(a.date));

    return GestureDetector(
      // Swipe left/right to change month.
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 300) {
          _changeMonth(-1);
        } else if (velocity < -300 && !isCurrentMonth) {
          _changeMonth(1);
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _changeMonth(-1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(formatMonthHeader(first), style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '$monthCount ${monthCount == 1 ? 'workout' : 'workouts'}',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: isCurrentMonth ? null : () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(child: Text(label, style: t.labelSmall)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            children: [
              for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
              for (var day = 1; day <= daysInMonth; day++)
                _DayCell(
                  day: day,
                  hasWorkout:
                      byDay.containsKey(DateTime(first.year, first.month, day)),
                  isToday: DateTime(first.year, first.month, day) == today,
                  isSelected:
                      DateTime(first.year, first.month, day) == _selectedDay,
                  onTap: () => setState(() {
                    _selectedDay = DateTime(first.year, first.month, day);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(formatLongDate(_selectedDay), style: t.titleMedium),
          ),
          if (selectedWorkouts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                'No workouts on this day.',
                style: t.bodySmall?.copyWith(fontSize: 14),
              ),
            )
          else
            for (var i = 0; i < selectedWorkouts.length; i++)
              _HistoryRow(
                workout: selectedWorkouts[i],
                showDivider: i < selectedWorkouts.length - 1,
                onTap: () => _openDetails(selectedWorkouts[i]),
                onRepeat: () => _repeat(selectedWorkouts[i]),
                onRename: () => _rename(selectedWorkouts[i]),
                onDelete: () => confirmDelete(context, selectedWorkouts[i]),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (workouts.isNotEmpty)
            IconButton(
              tooltip: _calendarView ? 'List view' : 'Calendar view',
              icon: Icon(
                _calendarView
                    ? Icons.view_list_rounded
                    : Icons.calendar_month_outlined,
              ),
              onPressed: () => setState(() => _calendarView = !_calendarView),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: workouts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history,
                      size: 40,
                      color: context.colors.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No workouts yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Finished workouts will show up here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          : _calendarView
              ? _buildCalendar(context)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: _buildItems(context),
                ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Workout workout;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onRepeat;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _HistoryRow({
    required this.workout,
    required this.showDivider,
    required this.onTap,
    required this.onRepeat,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final volume = workoutVolume(workout);
    final count = doneExercises(workout).length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.only(top: 12, bottom: 12, left: 0),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: context.colors.border))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workoutTitle(workout),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count ${count == 1 ? 'exercise' : 'exercises'}'
                    '${volume > 0 ? ' · ${formatVolume(volume)}' : ''}',
                    style: t.bodySmall?.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(formatRelativeDate(workout.date), style: t.bodySmall),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: context.colors.muted,
              ),
              padding: EdgeInsets.zero,
              color: context.colors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) {
                if (value == 'repeat') onRepeat();
                if (value == 'rename') onRename();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'repeat',
                  child: Row(
                    children: [
                      Icon(
                        Icons.replay_rounded,
                        size: 20,
                        color: context.colors.ink,
                      ),
                      const SizedBox(width: 8),
                      const Text('Repeat'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: context.colors.ink,
                      ),
                      const SizedBox(width: 8),
                      const Text('Rename'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: context.colors.error,
                      ),
                      SizedBox(width: 8),
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

class _DayCell extends StatelessWidget {
  final int day;
  final bool hasWorkout;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.hasWorkout,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasWorkout ? AppColors.accent : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? context.colors.ink
                  : isToday
                      ? context.colors.muted
                      : Colors.transparent,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: hasWorkout || isToday
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: hasWorkout ? AppColors.onAccent : context.colors.ink,
            ),
          ),
        ),
      ),
    );
  }
}