import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_template.dart';
import '../services/goal_controller.dart';
import '../services/profile_controller.dart';
import '../services/template_storage.dart';
import '../services/workout_events.dart';
import '../services/workout_storage.dart';
import '../theme/app_theme.dart';
import '../utils/workout_format.dart';
import 'ex_lib.dart';
import 'workout_details.dart';
import 'goal_sheet.dart';
import 'settings_screen.dart';
import 'workout_actions.dart';
import 'workout_history.dart';
import 'workout_screen.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

double _volume(Workout w) => workoutVolume(w);

String _formatVolume(double kg) => formatVolume(kg);

String _formatDate(DateTime d) {
  final diff = _day(DateTime.now()).difference(_day(d)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return '${diff}d ago';
  return '${_months[d.month - 1]} ${d.day}';
}

String _formatElapsed(Duration d) {
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes} min';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Workout? activeWorkout;
  bool isLoadingWorkout = true;

  List<Workout> workoutHistory = [];
  bool isLoadingHistory = true;

  List<WorkoutTemplate> templates = [];

  @override
  void initState() {
    super.initState();
    loadActiveWorkout();
    loadWorkoutHistory();
    loadTemplates();
    WorkoutEvents.changes.addListener(_onWorkoutsChanged);
  }

  void _onWorkoutsChanged() {
    loadActiveWorkout();
    loadWorkoutHistory();
    loadTemplates();
  }

  Future<void> loadTemplates() async {
    final saved = await TemplateStorage.getTemplates();
    if (!mounted) return;
    setState(() => templates = saved);
  }

  Future<void> _confirmDeleteTemplate(WorkoutTemplate template) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete routine?'),
        content: Text(
          '${template.name} will be removed from your routines. '
          'Your logged workouts are not affected.',
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

    await TemplateStorage.deleteTemplate(template.id);
    await loadTemplates();
  }

  @override
  void dispose() {
    WorkoutEvents.changes.removeListener(_onWorkoutsChanged);
    super.dispose();
  }

  Future<void> loadWorkoutHistory() async {
    final workouts = await WorkoutStorage.getWorkouts();
    if (!mounted) return;
    setState(() {
      workoutHistory = workouts.reversed.toList();
      isLoadingHistory = false;
    });
  }

  Future<void> loadActiveWorkout() async {
    final saved = await WorkoutStorage.getActiveWorkout();
    if (!mounted) return;
    setState(() {
      activeWorkout = saved;
      isLoadingWorkout = false;
    });
  }

  Future<void> _refresh() async {
    await loadActiveWorkout();
    await loadWorkoutHistory();
  }

  Future<void> _onPrimaryPressed() async {
    if (activeWorkout != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutScreen(workout: activeWorkout!),
        ),
      );
      await _refresh();
      return;
    }

    final result = await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()),
    );
    if (result == null || result.isEmpty || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkoutScreen(exercises: result)),
    );
    await _refresh();
  }

  // ---- derived stats ----

  DateTime get _weekStart {
    final today = _day(DateTime.now());
    return today.subtract(Duration(days: today.weekday - 1));
  }

  Set<DateTime> get _trainedDays =>
      workoutHistory.map((w) => _day(w.date)).toSet();

  List<Workout> get _thisWeek => workoutHistory
      .where((w) => !_day(w.date).isBefore(_weekStart))
      .toList();

  int get _streak {
    final days = _trainedDays;
    var cursor = _day(DateTime.now());
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: context.colors.ink,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildHeroCard(context),
              const SizedBox(height: 20),
              _buildWeekStrip(context),
              ValueListenableBuilder<int>(
                valueListenable: GoalController.weeklyGoal,
                builder: (context, goal, _) => goal > 0
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _buildGoalCard(context, goal),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              _buildStats(context),
              const SizedBox(height: 28),
              if (templates.isNotEmpty) ...[
                _buildRoutines(context),
                const SizedBox(height: 28),
              ],
              _buildRecent(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---- header ----

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final date =
        '${_weekdays[now.weekday - 1]}, ${_months[now.month - 1]} ${now.day}';
    final t = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: t.bodySmall),
              const SizedBox(height: 2),
              ValueListenableBuilder<String>(
                valueListenable: ProfileController.name,
                builder: (context, name, _) => Text(
                  name.isEmpty ? _greeting : '$_greeting, $name',
                  style: t.headlineMedium,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Settings',
          icon: Icon(
            Icons.settings_outlined,
            color: context.colors.muted,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  // ---- hero ----

  Widget _buildHeroCard(BuildContext context) {
    final active = activeWorkout;
    final t = Theme.of(context).textTheme;

    final total = active?.exercises.length ?? 0;
    final done = active == null
        ? 0
        : active.exercises
            .where((e) => e.sets.isNotEmpty && e.sets.every((s) => s.isDone))
            .length;

    final elapsed =
        active == null ? null : DateTime.now().difference(active.date);
    final showElapsed = elapsed != null && elapsed.inHours < 24;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.heroBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            active != null ? 'IN PROGRESS' : 'READY WHEN YOU ARE',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            active != null
                ? (hasName(active) ? active.name!.trim() : 'My Workout')
                : 'Start a workout',
            style: t.titleLarge?.copyWith(color: Colors.white, fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            active != null
                ? '$done of $total exercises done'
                    '${showElapsed ? ' · ${_formatElapsed(elapsed)}' : ''}'
                : 'Pick your exercises and start logging sets.',
            style: const TextStyle(fontSize: 14, color: Color(0xFFB5B5B0)),
          ),
          if (active != null && total > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: done / total,
                minHeight: 6,
                backgroundColor: const Color(0xFF2E2E2E),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isLoadingWorkout ? null : _onPrimaryPressed,
            child: Text(active != null ? 'Resume workout' : 'Start workout'),
          ),
        ],
      ),
    );
  }

  // ---- week strip ----

  Widget _buildWeekStrip(BuildContext context) {
    final trained = _trainedDays;
    final today = _day(DateTime.now());

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final date = _weekStart.add(Duration(days: i));
        final didTrain = trained.contains(date);
        final isToday = date == today;

        return Column(
          children: [
            Text(
              _weekdays[i][0],
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: didTrain ? AppColors.accent : Colors.transparent,
                border: Border.all(
                  color: didTrain
                      ? AppColors.accent
                      : isToday
                          ? context.colors.ink
                          : context.colors.border,
                  width: isToday && !didTrain ? 1.5 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: didTrain
                  ? const Icon(Icons.check, size: 18, color: AppColors.onAccent)
                  : Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday ? context.colors.ink : context.colors.muted,
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }

  // ---- weekly goal ----

  Widget _buildGoalCard(BuildContext context, int goal) {
    final t = Theme.of(context).textTheme;
    final done = _thisWeek.length;
    final reached = done >= goal;
    final remaining = goal - done;

    return InkWell(
      onTap: () => showWeeklyGoalSheet(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: (done / goal).clamp(0.0, 1.0),
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor: context.colors.border,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                  ),
                  reached
                      ? Icon(
                          Icons.check_rounded,
                          size: 26,
                          color: context.colors.ink,
                        )
                      : Text(
                          '$done/$goal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.ink,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly goal', style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    reached
                        ? 'Goal reached — nice work!'
                        : '$remaining more '
                            '${remaining == 1 ? 'workout' : 'workouts'} '
                            'to hit your goal',
                    style: t.bodySmall?.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: context.colors.muted,
            ),
          ],
        ),
      ),
    );
  }

  // ---- stats ----

  Widget _buildStats(BuildContext context) {
    final week = _thisWeek;
    final weekVolume = week.fold<double>(0, (sum, w) => sum + _volume(w));

    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
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
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          stat('${week.length}', 'This week'),
          divider(),
          stat(_formatVolume(weekVolume), 'Volume'),
          divider(),
          stat('$_streak', _streak == 1 ? 'Day streak' : 'Day streak'),
        ],
      ),
    );
  }

  // ---- routines ----

  Widget _buildRoutines(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Routines', style: t.titleMedium),
        ),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final template = templates[i];
              return _RoutineCard(
                template: template,
                onStart: () => startWorkoutFrom(
                  context,
                  exercises: template.exercises,
                  name: template.name,
                ),
                onDelete: () => _confirmDeleteTemplate(template),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- recent ----

  Widget _buildRecent(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent', style: t.titleMedium),
            if (workoutHistory.length > 4)
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          WorkoutHistoryScreen(workouts: workoutHistory),
                    ),
                  );
                  await loadWorkoutHistory();
                },
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.muted,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (isLoadingHistory)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (workoutHistory.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Your finished workouts will show up here.',
              style: t.bodySmall?.copyWith(fontSize: 14),
            ),
          )
        else
          ...workoutHistory.take(4).toList().asMap().entries.map((entry) {
            final workout = entry.value;
            final isLast = entry.key == workoutHistory.take(4).length - 1;
            return _RecentRow(
              workout: workout,
              showDivider: !isLast,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkoutDetailsScreen(workout: workout),
                  ),
                );
                await loadWorkoutHistory();
              },
            );
          }),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  final Workout workout;
  final bool showDivider;
  final VoidCallback onTap;

  const _RecentRow({
    required this.workout,
    required this.showDivider,
    required this.onTap,
  });

  String get _title => workoutTitle(workout);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final volume = _volume(workout);
    final count = doneExercises(workout).length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
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
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count ${count == 1 ? 'exercise' : 'exercises'}'
                    '${volume > 0 ? ' · ${_formatVolume(volume)}' : ''}',
                    style: t.bodySmall?.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(_formatDate(workout.date), style: t.bodySmall),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: context.colors.muted),
          ],
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final WorkoutTemplate template;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  const _RoutineCard({
    required this.template,
    required this.onStart,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final count = template.exercises.length;

    return SizedBox(
      width: 168,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onStart,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          template.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_horiz,
                          size: 20,
                          color: context.colors.muted,
                        ),
                        onSelected: (value) {
                          if (value == 'delete') onDelete();
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: context.colors.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete routine',
                                  style: TextStyle(
                                    color: context.colors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$count ${count == 1 ? 'exercise' : 'exercises'}',
                        style: t.bodySmall,
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: AppColors.onAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}