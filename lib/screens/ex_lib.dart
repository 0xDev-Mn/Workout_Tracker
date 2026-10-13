import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../services/exercise_storage.dart';
import '../theme/app_theme.dart';

String _titleCase(String input) {
  return input
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

class ExerciseLibraryScreen extends StatefulWidget {
  final List<Exercise> existingExercises;
  final bool selectionMode;

  const ExerciseLibraryScreen({
    super.key,
    this.existingExercises = const [],
    this.selectionMode = true,
  });

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  static const _groups = [
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Legs',
    'Core',
    'Other',
  ];

  static const List<Exercise> _all = [
    // Chest
    Exercise(name: 'Bench Press', muscleGroup: 'Chest'),
    Exercise(name: 'Incline Bench Press', muscleGroup: 'Chest'),
    Exercise(name: 'Dumbbell Press', muscleGroup: 'Chest'),
    Exercise(name: 'Incline Dumbbell Press', muscleGroup: 'Chest'),
    Exercise(name: 'Cable Fly', muscleGroup: 'Chest'),
    Exercise(name: 'Pec Deck', muscleGroup: 'Chest'),

    // Back
    Exercise(name: 'Lat Pulldown', muscleGroup: 'Back'),
    Exercise(name: 'Pull-Up', muscleGroup: 'Back'),
    Exercise(name: 'Seated Cable Row', muscleGroup: 'Back'),
    Exercise(name: 'Barbell Row', muscleGroup: 'Back'),
    Exercise(name: 'Dumbbell Row', muscleGroup: 'Back'),

    // Shoulders
    Exercise(name: 'Overhead Press', muscleGroup: 'Shoulders'),
    Exercise(name: 'Dumbbell Shoulder Press', muscleGroup: 'Shoulders'),
    Exercise(name: 'Lateral Raise', muscleGroup: 'Shoulders'),
    Exercise(name: 'Rear Delt Fly', muscleGroup: 'Shoulders'),
    Exercise(name: 'Face Pull', muscleGroup: 'Shoulders'),

    // Legs
    Exercise(name: 'Squat', muscleGroup: 'Legs'),
    Exercise(name: 'Leg Press', muscleGroup: 'Legs'),
    Exercise(name: 'Leg Extension', muscleGroup: 'Legs'),
    Exercise(name: 'Leg Curl', muscleGroup: 'Legs'),
    Exercise(name: 'Romanian Deadlift', muscleGroup: 'Legs'),
    Exercise(name: 'Hip Thrust', muscleGroup: 'Legs'),
    Exercise(name: 'Calf Raise', muscleGroup: 'Legs'),

    // Arms
    Exercise(name: 'Barbell Curl', muscleGroup: 'Arms'),
    Exercise(name: 'Dumbbell Curl', muscleGroup: 'Arms'),
    Exercise(name: 'Hammer Curl', muscleGroup: 'Arms'),
    Exercise(name: 'Tricep Pushdown', muscleGroup: 'Arms'),
    Exercise(name: 'Skull Crusher', muscleGroup: 'Arms'),
    Exercise(name: 'Overhead Tricep Extension', muscleGroup: 'Arms'),

    // Core
    Exercise(name: 'Plank', muscleGroup: 'Core'),
    Exercise(name: 'Crunch', muscleGroup: 'Core'),
    Exercise(name: 'Hanging Leg Raise', muscleGroup: 'Core'),
    Exercise(name: 'Cable Crunch', muscleGroup: 'Core'),
    Exercise(name: 'Ab Wheel Rollout', muscleGroup: 'Core'),
  ];

  // Exercises currently selected by the user.
  late List<Exercise> selectedExercises;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  // Exercises created by the user (saved on the device).
  List<Exercise> _custom = [];

  @override
  void initState() {
    super.initState();
    selectedExercises = List.from(widget.existingExercises);
    _loadCustom();
  }

  Future<void> _loadCustom() async {
    final custom = await ExerciseStorage.getCustomExercises();
    if (!mounted) return;
    setState(() => _custom = custom);
  }

  Future<void> _openAddExercise({String initialName = ''}) async {
    final taken = [..._all, ..._custom]
        .map((e) => e.name.trim().toLowerCase())
        .toSet();

    final created = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddExerciseSheet(
        groups: _groups,
        takenNames: taken,
        initialName: _titleCase(initialName),
      ),
    );

    if (created == null) return;

    await ExerciseStorage.addCustomExercise(created);
    if (!mounted) return;

    setState(() => _custom = [..._custom, created]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isSelected(Exercise exercise) =>
      selectedExercises.any((e) => e.name == exercise.name);

  bool _isExisting(Exercise exercise) =>
      widget.existingExercises.any((e) => e.name == exercise.name);

  int get _newCount =>
      selectedExercises.where((e) => !_isExisting(e)).length;

  Future<void> _confirmDeleteCustom(Exercise exercise) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete exercise?'),
        content: Text(
          '${exercise.name} will be removed from your library. '
          'Workouts you already logged keep it.',
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

    await ExerciseStorage.deleteCustomExercise(exercise.name);
    if (!mounted) return;

    setState(() {
      _custom = _custom.where((c) => c.name != exercise.name).toList();
      if (!_isExisting(exercise)) {
        selectedExercises.removeWhere((e) => e.name == exercise.name);
      }
    });
  }

  List<Exercise> getExercisesFor(String muscleGroup) {
    final query = _query.trim().toLowerCase();

    return [..._all, ..._custom]
        .where((e) => e.muscleGroup == muscleGroup)
        .where((e) => query.isEmpty || e.name.toLowerCase().contains(query))
        .toList();
  }

  void toggleExercise(Exercise exercise) {
    setState(() {
      if (_isSelected(exercise)) {
        selectedExercises.removeWhere((e) => e.name == exercise.name);
      } else {
        selectedExercises.add(exercise);
      }
    });
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search exercises',
        hintStyle: TextStyle(color: context.colors.muted),
        prefixIcon: Icon(Icons.search, color: context.colors.muted),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: context.colors.muted,
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: context.colors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.ink, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildRow(Exercise exercise, {required bool showDivider}) {
    final isSelected = _isSelected(exercise);
    final isExisting = _isExisting(exercise);
    final isCustom = _custom.any((c) => c.name == exercise.name);
    final t = Theme.of(context).textTheme;

    return InkWell(
      onTap: widget.selectionMode && !isExisting
          ? () => toggleExercise(exercise)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected && !isExisting
              ? context.colors.accentSoft.withAlpha(140)
              : null,
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
                    exercise.name,
                    style: t.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isExisting
                          ? context.colors.muted
                          : context.colors.ink,
                    ),
                  ),
                  if (isCustom) Text('Custom', style: t.bodySmall),
                ],
              ),
            ),
            if (isCustom)
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_horiz,
                  size: 20,
                  color: context.colors.muted,
                ),
                onSelected: (value) {
                  if (value == 'delete') _confirmDeleteCustom(exercise);
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
                          'Delete exercise',
                          style: TextStyle(color: context.colors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (isExisting)
              Text('Added', style: t.bodySmall)
            else if (widget.selectionMode)
              _CheckDot(selected: isSelected),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(String group, List<Exercise> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              group.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: context.colors.muted,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  _buildRow(items[i], showDivider: i < items.length - 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];

    for (final group in _groups) {
      final items = getExercisesFor(group);
      if (items.isNotEmpty) sections.add(_buildGroup(group, items));
    }

    final newCount = _newCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectionMode ? 'Select exercises' : 'Exercises',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _buildSearch(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openAddExercise(),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add new exercise'),
          ),
          const SizedBox(height: 20),
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Text(
                    'No exercises match "$_query"',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _openAddExercise(initialName: _query.trim()),
                    icon: const Icon(Icons.add, size: 20),
                    label: Text('Add "${_query.trim()}" as a new exercise'),
                  ),
                ],
              ),
            )
          else
            ...sections,
        ],
      ),
      bottomNavigationBar: widget.selectionMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: ElevatedButton(
                  onPressed: newCount == 0
                      ? null
                      : () => Navigator.pop(context, selectedExercises),
                  child: Text(
                    newCount == 0
                        ? 'Select exercises'
                        : 'Add $newCount ${newCount == 1 ? 'exercise' : 'exercises'}',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _CheckDot extends StatelessWidget {
  final bool selected;

  const _CheckDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.accent : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.accent : context.colors.border,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 16, color: AppColors.onAccent)
          : null,
    );
  }
}

class _AddExerciseSheet extends StatefulWidget {
  final List<String> groups;
  final Set<String> takenNames;
  final String initialName;

  const _AddExerciseSheet({
    required this.groups,
    required this.takenNames,
    this.initialName = '',
  });

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  late final TextEditingController _controller;
  String? _group;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Enter an exercise name');
      return;
    }

    if (widget.takenNames.contains(name.toLowerCase())) {
      setState(() => _error = 'That exercise already exists');
      return;
    }

    if (_group == null) {
      setState(() => _error = 'Pick a muscle group');
      return;
    }

    Navigator.pop(context, Exercise(name: name, muscleGroup: _group!));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New exercise', style: t.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Exercise name',
                  hintStyle: TextStyle(color: context.colors.hint),
                  counterText: '',
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              Text(
                'MUSCLE GROUP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: context.colors.muted,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final group in widget.groups)
                    ChoiceChip(
                      label: Text(group),
                      selected: _group == group,
                      showCheckmark: false,
                      onSelected: (_) => setState(() {
                        _group = group;
                        _error = null;
                      }),
                      selectedColor: AppColors.accent,
                      backgroundColor: context.colors.bg,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: _group == group
                              ? AppColors.accent
                              : context.colors.border,
                        ),
                      ),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _group == group
                            ? AppColors.onAccent
                            : context.colors.ink,
                      ),
                    ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Save exercise'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}