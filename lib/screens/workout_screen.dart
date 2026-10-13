import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_ex.dart';
import '../models/workout_set.dart';
import '../services/rest_timer_controller.dart';
import '../services/workout_events.dart';
import '../services/workout_storage.dart';
import '../theme/app_theme.dart';
import '../utils/pr_utils.dart';
import '../utils/workout_format.dart';
import '../widgets/rest_timer_bar.dart';
import 'ex_lib.dart';
import 'rest_timer_screen.dart';
import 'workout_summary_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final List<Exercise>? exercises;
  final Workout? workout;

  /// Name for a brand-new workout (used when repeating or using a routine).
  final String? name;

  const WorkoutScreen({
    super.key,
    this.exercises,
    this.workout,
    this.name,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late final Workout workout;
  late final TextEditingController _nameController;

  // Rest timer bar: starts automatically when a set is ticked as done.
  final RestTimerController _restTimer = RestTimerController();

  // Heaviest weight ever lifted per exercise (before this workout).
  Map<String, double> _bestWeights = {};

  static const List<String> _nameSuggestions = [
    'Push Day',
    'Pull Day',
    'Leg Day',
    'Upper Body',
    'Lower Body',
    'Full Body',
  ];

  void _useName(String label) {
    _nameController.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );
    workout.name = label;
    saveActiveWorkout();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    if (widget.workout != null) {
      workout = widget.workout!;
    } else {
      workout = Workout(
        date: DateTime.now(),
        exercises: widget.exercises!
            .map((exercise) => WorkoutExercise(exercise: exercise))
            .toList(),
        name: widget.name,
      );

      saveActiveWorkout();
    }

    _nameController = TextEditingController(text: workout.name ?? '');
    _loadBestWeights();
  }

  Future<void> _loadBestWeights() async {
    final best = await WorkoutStorage.getBestWeights(
      excludeWorkoutId: workout.id,
    );
    if (!mounted) return;
    setState(() => _bestWeights = best);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _restTimer.dispose();
    super.dispose();
  }

  Future<void> saveActiveWorkout() async {
    await WorkoutStorage.saveActiveWorkout(workout);
  }

  Future<void> removeExercise(WorkoutExercise workoutExercise) async {
    setState(() {
      workout.exercises.remove(workoutExercise);
    });

    await saveActiveWorkout();
  }

  Future<void> addExercise() async {
    final result = await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseLibraryScreen(
          existingExercises: workout.exercises
              .map((workoutExercise) => workoutExercise.exercise)
              .toList(),
        ),
      ),
    );

    if (result == null || result.isEmpty) {
      return;
    }

    setState(() {
      for (final exercise in result) {
        if (!workout.exercises.any(
          (workoutExercise) => workoutExercise.exercise.name == exercise.name,
        )) {
          workout.exercises.add(WorkoutExercise(exercise: exercise));
        }
      }
    });

    await saveActiveWorkout();
  }

  Future<void> finishWorkout() async {
    // A set counts as soon as a weight or reps is entered, even if its
    // check wasn't ticked. Sets left completely empty are dropped.
    for (final e in workout.exercises) {
      e.sets.removeWhere((set) => set.weight == null && set.reps == null);
      for (final set in e.sets) {
        set.isDone = true;
      }
    }

    workout.endTime = DateTime.now();

    await WorkoutStorage.saveWorkout(workout);
    await WorkoutStorage.clearActiveWorkout();
    WorkoutEvents.notifyChanged();

    if (!mounted) return;

    // Nothing was logged: just go back. Otherwise show the summary.
    if (workoutSetCount(workout) == 0) {
      Navigator.pop(context, true);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(workout: workout),
      ),
    );
  }

  int get _totalSets {
    var count = 0;
    for (final e in workout.exercises) {
      count += e.sets.length;
    }
    return count;
  }

  int get _doneSets {
    var count = 0;
    for (final e in workout.exercises) {
      count += e.sets.where((s) => s.isDone).length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final exerciseCount = workout.exercises.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workout',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Rest timer',
            icon: const Icon(Icons.schedule, size: 22),
            onPressed: () {
              _restTimer.stop();
              RestTimerScreen.show(context);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            maxLength: 40,
            style: t.headlineMedium?.copyWith(fontSize: 26),
            decoration: InputDecoration(
              hintText: 'Name your workout',
              hintStyle: t.headlineMedium?.copyWith(
                fontSize: 26,
                color: context.colors.hint,
              ),
              filled: false,
              isDense: true,
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              suffixIcon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: context.colors.muted,
              ),
            ),
            onChanged: (value) {
              final trimmed = value.trim();
              workout.name = trimmed.isEmpty ? null : trimmed;
              saveActiveWorkout();
              setState(() {});
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16, top: 2),
            child: Text(
              '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}'
              ' · $_doneSets of $_totalSets sets done',
              style: t.bodySmall?.copyWith(fontSize: 14),
            ),
          ),
          if (_nameController.text.trim().isEmpty) ...[
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: _nameSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final label = _nameSuggestions[i];
                  return ActionChip(
                    label: Text(label),
                    onPressed: () => _useName(label),
                    backgroundColor: context.colors.surface,
                    shape: StadiumBorder(
                      side: BorderSide(color: context.colors.border),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.ink,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          ...workout.exercises.map(
            (workoutExercise) => ExerciseCard(
              key: ObjectKey(workoutExercise),
              workoutId: workout.id,
              previousBest: _bestWeights[workoutExercise.exercise.name],
              onSetDone: () => _restTimer.start(),
              workoutExercise: workoutExercise,
              onChanged: () {
                saveActiveWorkout();
                setState(() {});
              },
              onRemove: () => removeExercise(workoutExercise),
            ),
          ),
          OutlinedButton.icon(
            onPressed: addExercise,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add exercise'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RestTimerBar(controller: _restTimer),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: ElevatedButton(
                onPressed: finishWorkout,
                child: const Text('Finish workout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExerciseCard extends StatefulWidget {
  final String workoutId;
  final double? previousBest;
  final VoidCallback? onSetDone;
  final WorkoutExercise workoutExercise;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const ExerciseCard({
    super.key,
    required this.workoutId,
    this.previousBest,
    this.onSetDone,
    required this.workoutExercise,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  final Map<WorkoutSet, TextEditingController> weightControllers = {};
  final Map<WorkoutSet, TextEditingController> repsControllers = {};

  // Sets from the last time this exercise was done (used as hints only).
  List<WorkoutSet> _previousSets = [];
  DateTime? _previousDate;

  TextStyle get _hintStyle => TextStyle(
        color: context.colors.hint,
        fontWeight: FontWeight.w500,
      );

  @override
  void initState() {
    super.initState();
    _loadPrevious();
  }

  Future<void> _loadPrevious() async {
    final name = widget.workoutExercise.exercise.name;

    final previous = await WorkoutStorage.getPreviousWorkout(
      name,
      widget.workoutId,
    );

    if (previous == null || !mounted) return;

    final matches = previous.exercises.where((e) => e.exercise.name == name);
    if (matches.isEmpty) return;

    final sets = matches.first.sets
        .where((s) => s.isDone && (s.weight != null || s.reps != null))
        .toList();
    if (sets.isEmpty) return;

    setState(() {
      _previousSets = sets;
      _previousDate = previous.date;
    });
  }

  /// Same set number as last time; extra sets reuse last time's final set.
  WorkoutSet? _previousSetFor(int index) {
    if (_previousSets.isEmpty) return null;
    return index < _previousSets.length
        ? _previousSets[index]
        : _previousSets.last;
  }

  TextEditingController getWeightController(WorkoutSet set) {
    return weightControllers.putIfAbsent(
      set,
      () => TextEditingController(
        text: set.weight == null ? '' : formatWeight(set.weight),
      ),
    );
  }

  TextEditingController getRepsController(WorkoutSet set) {
    return repsControllers.putIfAbsent(
      set,
      () => TextEditingController(text: set.reps?.toString() ?? ''),
    );
  }

  void addSet() {
    setState(() {
      widget.workoutExercise.sets.add(WorkoutSet());
    });

    widget.onChanged();
  }

  void removeSet(WorkoutSet set) {
    setState(() {
      weightControllers.remove(set)?.dispose();
      repsControllers.remove(set)?.dispose();
      widget.workoutExercise.sets.remove(set);
    });

    widget.onChanged();
  }

  void confirmRemoveExercise() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Remove exercise?'),
        content: Text(
          '${widget.workoutExercise.exercise.name} will be removed '
          'from this workout.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: context.colors.muted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onRemove();
            },
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in weightControllers.values) {
      controller.dispose();
    }

    for (final controller in repsControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Widget _headerLabel(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: context.colors.muted,
        ),
      );

  Widget _buildSetRow(int index, WorkoutSet set) {
    final row = _buildSetRowCore(index, set);

    final prIndex = prSetIndex(
      widget.workoutExercise.sets,
      widget.previousBest,
    );
    if (prIndex != index) return row;

    // This set beats the heaviest weight ever lifted for this exercise.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.only(left: 40, bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  'New PR · previous best '
                  '${formatWeight(widget.previousBest)} kg',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.colors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSetRowCore(int index, WorkoutSet set) {
    final numberStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: context.colors.ink,
    );

    final prev = _previousSetFor(index);
    final weightHint =
        prev?.weight != null ? formatWeight(prev!.weight) : '0';
    final repsHint = prev?.reps?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Tooltip(
              message: set.isDone ? 'Mark as not done' : 'Mark set done',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  setState(() {
                    set.isDone = !set.isDone;
                  });
                  widget.onChanged();

                  // Ticking a set starts the rest timer.
                  if (set.isDone) widget.onSetDone?.call();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: set.isDone ? AppColors.accent : context.colors.bg,
                  ),
                  child: set.isDone
                      ? const Icon(
                          Icons.check,
                          size: 18,
                          color: AppColors.onAccent,
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.muted,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: getWeightController(set),
              textAlign: TextAlign.center,
              style: numberStyle,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: weightHint,
                hintStyle: _hintStyle,
                isDense: true,
              ),
              onChanged: (value) {
                set.weight = double.tryParse(value);
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: getRepsController(set),
              textAlign: TextAlign.center,
              style: numberStyle,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: repsHint,
                hintStyle: _hintStyle,
                isDense: true,
              ),
              onChanged: (value) {
                set.reps = int.tryParse(value);
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Tooltip(
                  message: 'Drop set',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        set.isDropSet = !set.isDropSet;
                      });
                      widget.onChanged();
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color:
                            set.isDropSet ? AppColors.accent : context.colors.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.arrow_downward,
                        size: 16,
                        color:
                            set.isDropSet ? AppColors.onAccent : context.colors.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => removeSet(set),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: context.colors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sets = widget.workoutExercise.sets;
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.workoutExercise.exercise.name,
                          style: t.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _previousDate == null
                              ? widget.workoutExercise.exercise.muscleGroup
                              : '${widget.workoutExercise.exercise.muscleGroup}'
                                  ' · Last time ${formatShortDate(_previousDate!)}',
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz,
                      color: context.colors.muted,
                    ),
                    color: context.colors.surface,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (value) {
                      if (value == 'remove') confirmRemoveExercise();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: context.colors.error,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Remove exercise',
                              style: TextStyle(color: context.colors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (sets.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 32, child: _headerLabel('SET')),
                      const SizedBox(width: 8),
                      Expanded(child: _headerLabel('KG')),
                      const SizedBox(width: 8),
                      Expanded(child: _headerLabel('REPS')),
                      const SizedBox(width: 8),
                      const SizedBox(width: 72),
                    ],
                  ),
                ),
                ...sets
                    .asMap()
                    .entries
                    .map((entry) => _buildSetRow(entry.key, entry.value)),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No sets yet',
                    style: t.bodySmall?.copyWith(fontSize: 14),
                  ),
                ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: addSet,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add set'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.ink,
                    backgroundColor: context.colors.bg,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}