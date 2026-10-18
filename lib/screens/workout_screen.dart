import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_ex.dart';
import '../models/workout_set.dart';
import '../services/rest_timer_controller.dart';
import '../services/unit_controller.dart';
import '../services/workout_events.dart';
import '../services/workout_storage.dart';
import '../theme/app_theme.dart';
import '../utils/pr_utils.dart';
import '../utils/workout_format.dart';
import '../widgets/reorder_exercises_sheet.dart';
import '../widgets/rest_timer_bar.dart';
import '../widgets/set_type_badge.dart';
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
  late final TextEditingController _workoutNoteController;

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
    _workoutNoteController = TextEditingController(text: workout.notes ?? '');
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
    _workoutNoteController.dispose();
    _restTimer.dispose();
    super.dispose();
  }

  Future<void> saveActiveWorkout() async {
    await WorkoutStorage.saveActiveWorkout(workout);
  }

  Future<void> removeExercise(WorkoutExercise workoutExercise) async {
    setState(() {
      workout.exercises.remove(workoutExercise);
      _normalizeSupersets();
    });

    await saveActiveWorkout();
  }

  // ---- reordering and supersets ----

  /// A superset must be 2+ exercises sitting next to each other. Anything
  /// else (a lone exercise, or members split apart) is unlinked.
  void _normalizeSupersets() {
    final byId = <String, List<int>>{};

    for (var i = 0; i < workout.exercises.length; i++) {
      final id = workout.exercises[i].supersetId;
      if (id != null) byId.putIfAbsent(id, () => []).add(i);
    }

    byId.forEach((id, indexes) {
      final contiguous = indexes.last - indexes.first + 1 == indexes.length;
      if (indexes.length < 2 || !contiguous) {
        for (final i in indexes) {
          workout.exercises[i].supersetId = null;
        }
      }
    });
  }

  void _reorderExercises(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;

    setState(() {
      final item = workout.exercises.removeAt(oldIndex);
      workout.exercises.insert(newIndex, item);
      _normalizeSupersets();
    });

    saveActiveWorkout();
  }

  void _showReorderSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ReorderExercisesSheet(
        exercises: workout.exercises,
        onReorder: _reorderExercises,
      ),
    );
  }

  void _linkWithNext(int index) {
    final list = workout.exercises;
    if (index >= list.length - 1) return;

    final current = list[index];
    final next = list[index + 1];

    final id = current.supersetId ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final nextOldId = next.supersetId;

    setState(() {
      // If the next exercise already led a superset, merge it in.
      if (nextOldId != null) {
        for (final e in list) {
          if (e.supersetId == nextOldId) e.supersetId = id;
        }
      }
      current.supersetId = id;
      next.supersetId = id;
      _normalizeSupersets();
    });

    saveActiveWorkout();
  }

  void _unlink(int index) {
    setState(() {
      workout.exercises[index].supersetId = null;
      _normalizeSupersets();
    });

    saveActiveWorkout();
  }

  List<Widget> _buildExerciseCards() {
    final list = workout.exercises;
    final widgets = <Widget>[];

    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      final id = e.supersetId;

      final startsGroup = id != null && (i == 0 || list[i - 1].supersetId != id);
      final linkedToNext =
          id != null && i < list.length - 1 && list[i + 1].supersetId == id;

      if (startsGroup) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 13, bottom: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.link_rounded,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  'SUPERSET',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: context.colors.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // The frame is always the same widget type, so an exercise keeps its
      // state (focus, notes field...) when it joins or leaves a superset.
      widgets.add(
        _SupersetFrame(
          key: ObjectKey(e),
          grouped: id != null,
          child: ExerciseCard(
            workoutId: workout.id,
            previousBest: _bestWeights[e.exercise.name],
            onSetDone: () => _restTimer.start(),
            workoutExercise: e,
            isSuperset: id != null,
            canLinkNext: i < list.length - 1 && !linkedToNext,
            onLinkNext: () => _linkWithNext(i),
            onUnlink: () => _unlink(i),
            onChanged: () {
              saveActiveWorkout();
              setState(() {});
            },
            onRemove: () => removeExercise(e),
          ),
        ),
      );
    }

    return widgets;
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
          if (workout.exercises.length > 1)
            IconButton(
              tooltip: 'Reorder exercises',
              icon: const Icon(Icons.swap_vert_rounded, size: 22),
              onPressed: _showReorderSheet,
            ),
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
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}'
                    ' · $_doneSets of $_totalSets sets done',
                    style: t.bodySmall?.copyWith(fontSize: 14),
                  ),
                ),
                _ElapsedClock(
                  start: workout.date,
                  style: t.bodySmall?.copyWith(fontSize: 14),
                ),
              ],
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
          TextField(
            controller: _workoutNoteController,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: t.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Add a note about this workout',
              hintStyle: TextStyle(color: context.colors.muted),
              prefixIcon: Icon(
                Icons.notes_rounded,
                size: 20,
                color: context.colors.muted,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              filled: false,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 8,
              ),
            ),
            onChanged: (value) {
              final trimmed = value.trim();
              workout.notes = trimmed.isEmpty ? null : trimmed;
              saveActiveWorkout();
            },
          ),
          const SizedBox(height: 8),
          ..._buildExerciseCards(),
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
  final bool isSuperset;
  final bool canLinkNext;
  final VoidCallback? onLinkNext;
  final VoidCallback? onUnlink;
  final WorkoutExercise workoutExercise;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const ExerciseCard({
    super.key,
    required this.workoutId,
    this.previousBest,
    this.onSetDone,
    this.isSuperset = false,
    this.canLinkNext = false,
    this.onLinkNext,
    this.onUnlink,
    required this.workoutExercise,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  final Map<WorkoutSet, TextEditingController> weightControllers = {};
  final Map<WorkoutSet, FocusNode> _weightFocus = {};

  // The set whose weight field is being edited (shows the stepper chips).
  WorkoutSet? _focusedWeightSet;

  /// Quick weight adjustments shown under the set being edited (kg).
  /// Quick adjustments, in the unit shown on screen.
  static List<double> get _weightSteps => UnitController.isLb
      ? const [-10.0, -5.0, 5.0, 10.0]
      : const [-5.0, -2.5, 2.5, 5.0];

  FocusNode getWeightFocus(WorkoutSet set) {
    return _weightFocus.putIfAbsent(set, () {
      final node = FocusNode();
      node.addListener(() {
        if (!mounted) return;
        setState(() {
          if (node.hasFocus) {
            _focusedWeightSet = set;
          } else if (_focusedWeightSet == set) {
            _focusedWeightSet = null;
          }
        });
      });
      return node;
    });
  }

  /// Changes the weight by [delta]. An empty field starts from last time's
  /// weight (the hint), or 0.
  void _nudgeWeight(int index, WorkoutSet set, double delta) {
    // Work in the unit shown on screen, then store the result in kg.
    final baseKg = set.weight ?? _previousSetFor(index)?.weight ?? 0.0;
    final shown = double.parse(
      UnitController.toDisplay(baseKg)
          .toStringAsFixed(UnitController.isLb ? 1 : 2),
    );
    final next = math.max(0.0, double.parse((shown + delta).toStringAsFixed(2)));
    final nextKg = next == 0 ? null : UnitController.fromDisplay(next);

    final controller = getWeightController(set);
    controller.text = nextKg == null ? '' : formatWeight(nextKg);
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);

    setState(() {
      set.weight = nextKg;
    });
    widget.onChanged();
  }
  final Map<WorkoutSet, TextEditingController> repsControllers = {};

  // Sets from the last time this exercise was done (used as hints only).
  late final TextEditingController _noteController;
  final FocusNode _noteFocus = FocusNode();
  bool _showNote = false;

  List<WorkoutSet> _previousSets = []; // last time's working sets
  List<WorkoutSet> _previousWarmups = [];
  DateTime? _previousDate;

  TextStyle get _hintStyle => TextStyle(
        color: context.colors.hint,
        fontWeight: FontWeight.w500,
      );

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: widget.workoutExercise.notes ?? '',
    );
    _showNote = _noteController.text.isNotEmpty;
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

    final done = matches.first.sets
        .where((s) => s.isDone && (s.weight != null || s.reps != null))
        .toList();

    final working = done.where((s) => !s.isWarmup).toList();
    final warmups = done.where((s) => s.isWarmup).toList();
    if (working.isEmpty && warmups.isEmpty) return;

    setState(() {
      _previousSets = working;
      _previousWarmups = warmups;
      _previousDate = previous.date;
    });
  }

  /// Matches warm-ups with last time's warm-ups and working sets with last
  /// time's working sets, by position. Extra sets reuse the final one.
  WorkoutSet? _previousSetFor(int index) {
    final sets = widget.workoutExercise.sets;
    if (index < 0 || index >= sets.length) return null;

    final isWarmup = sets[index].isWarmup;
    final pool = isWarmup ? _previousWarmups : _previousSets;
    if (pool.isEmpty) return null;

    var position = 0;
    for (var i = 0; i < index; i++) {
      if (sets[i].isWarmup == isWarmup) position++;
    }

    return position < pool.length ? pool[position] : pool.last;
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
      _weightFocus.remove(set)?.dispose();
      if (_focusedWeightSet == set) _focusedWeightSet = null;
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

    for (final node in _weightFocus.values) {
      node.dispose();
    }

    _noteController.dispose();
    _noteFocus.dispose();

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

    final isPr = prSetIndex(
          widget.workoutExercise.sets,
          widget.previousBest,
        ) ==
        index;
    final showStepper = _focusedWeightSet == set;

    if (!isPr && !showStepper) return row;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        if (showStepper) _buildStepper(index, set),
        if (isPr) _buildPrPill(),
      ],
    );
  }

  Widget _buildStepper(int index, WorkoutSet set) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 8),
      child: Row(
        children: [
          for (final step in _weightSteps) ...[
            _StepChip(
              label: '${step > 0 ? '+' : '−'}${formatWeight(step.abs())}',
              onTap: () => _nudgeWeight(index, set, step),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  // This set beats the heaviest weight ever lifted for this exercise.
  Widget _buildPrPill() {
    return Padding(
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
              '${formatWeight(widget.previousBest)} $unitLabel',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.colors.ink,
              ),
            ),
          ],
        ),
      ),
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
              focusNode: getWeightFocus(set),
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
                final typed = double.tryParse(value);
                set.weight =
                    typed == null ? null : UnitController.fromDisplay(typed);
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
                PopupMenuButton<SetType>(
                  tooltip: 'Set type',
                  padding: EdgeInsets.zero,
                  onSelected: (type) {
                    setState(() {
                      set.type = type;
                    });
                    widget.onChanged();
                  },
                  itemBuilder: (context) => [
                    for (final type in SetType.values)
                      PopupMenuItem<SetType>(
                        value: type,
                        child: _SetTypeMenuItem(
                          type: type,
                          selected: set.type == type,
                        ),
                      ),
                  ],
                  child: SetTypeBadge(type: set.type),
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
                      if (value == 'note') {
                        setState(() => _showNote = true);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _noteFocus.requestFocus();
                        });
                      }
                      if (value == 'link') widget.onLinkNext?.call();
                      if (value == 'unlink') widget.onUnlink?.call();
                      if (value == 'remove') confirmRemoveExercise();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'note',
                        child: Row(
                          children: [
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 20,
                              color: context.colors.ink,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _noteController.text.trim().isEmpty
                                  ? 'Add note'
                                  : 'Edit note',
                            ),
                          ],
                        ),
                      ),
                      if (widget.canLinkNext)
                        PopupMenuItem<String>(
                          value: 'link',
                          child: Row(
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: 20,
                                color: context.colors.ink,
                              ),
                              const SizedBox(width: 8),
                              const Text('Superset with next'),
                            ],
                          ),
                        ),
                      if (widget.isSuperset)
                        PopupMenuItem<String>(
                          value: 'unlink',
                          child: Row(
                            children: [
                              Icon(
                                Icons.link_off_rounded,
                                size: 20,
                                color: context.colors.ink,
                              ),
                              const SizedBox(width: 8),
                              const Text('Remove from superset'),
                            ],
                          ),
                        ),
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
              if (_showNote) ...[
                TextField(
                  controller: _noteController,
                  focusNode: _noteFocus,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 14, color: context.colors.ink),
                  decoration: InputDecoration(
                    hintText: 'Add a note…',
                    hintStyle: TextStyle(color: context.colors.hint),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final trimmed = value.trim();
                    widget.workoutExercise.notes =
                        trimmed.isEmpty ? null : trimmed;
                    widget.onChanged();
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (sets.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 32, child: _headerLabel('SET')),
                      const SizedBox(width: 8),
                      Expanded(child: _headerLabel(unitLabel.toUpperCase())),
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

class _SetTypeMenuItem extends StatelessWidget {
  final SetType type;
  final bool selected;

  const _SetTypeMenuItem({required this.type, required this.selected});

  String? get _hint {
    switch (type) {
      case SetType.normal:
        return null;
      case SetType.warmup:
        return 'Not counted in volume or records';
      case SetType.drop:
        return 'Lighter weight right after a set';
      case SetType.failure:
        return "Until you couldn't do another rep";
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hint = _hint;

    return Row(
      children: [
        SetTypeBadge(type: type, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                type.label,
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (hint != null) Text(hint, style: t.bodySmall),
            ],
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 12),
          const Icon(Icons.check, size: 18, color: AppColors.accent),
        ],
      ],
    );
  }
}

/// Small "+2.5" / "−5" button. It never takes focus, so the keyboard
/// stays open while you tap it.
class _StepChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StepChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      canRequestFocus: false,
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.ink,
          ),
        ),
      ),
    );
  }
}

/// " · 23:41" — time since the workout started. Ticks every second but only
/// rebuilds itself, not the whole screen.
class _ElapsedClock extends StatefulWidget {
  final DateTime start;
  final TextStyle? style;

  const _ElapsedClock({required this.start, this.style});

  @override
  State<_ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<_ElapsedClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');

    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    return hours > 0
        ? '$hours:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.start);

    // Hide it for a workout left open for a day or more.
    if (elapsed.isNegative || elapsed.inHours >= 24) {
      return const SizedBox.shrink();
    }

    return Text(
      ' · ${_format(elapsed)}',
      style: (widget.style ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Draws a green bar on the left of exercises that belong to a superset.
class _SupersetFrame extends StatelessWidget {
  final bool grouped;
  final Widget child;

  const _SupersetFrame({super.key, required this.grouped, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: grouped ? 10 : 0),
      decoration: grouped
          ? const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.accent, width: 3),
              ),
            )
          : null,
      child: child,
    );
  }
}