import 'package:flutter/material.dart';
import 'models/exercise.dart';
import 'models/workout_set.dart';
import 'models/workout_ex.dart';
import 'models/workout.dart';
import 'screens/ex_lib.dart';
import 'screens/workout_history.dart';
import 'screens/workout_details.dart';
import 'services/workout_storage.dart';

void main() {
  runApp(const WorkoutTrackerApp());
}

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Workout Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Exercise> selectedExercises = [];

  Workout? activeWorkout;
  bool isLoadingWorkout = true;

  List<Workout> workoutHistory = [];
  bool isLoadingHistory = true;

  @override
  void initState() {
    super.initState();

    loadActiveWorkout();
    loadWorkoutHistory();
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
    final savedWorkout =
        await WorkoutStorage.getActiveWorkout();

    if (!mounted) return;

    setState(() {
      activeWorkout = savedWorkout;
      isLoadingWorkout = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workout Tracker',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Workout",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Workout',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      activeWorkout != null
                          ? '${activeWorkout!.exercises.length} exercises in progress'
                          : selectedExercises.isEmpty
                              ? 'No exercises selected'
                              : '${selectedExercises.length} exercises',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,

                      child: ElevatedButton(
                        onPressed: isLoadingWorkout
                            ? null
                            : () async {
                                if (activeWorkout != null) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          WorkoutScreen(
                                        workout: activeWorkout!,
                                      ),
                                    ),
                                  );

                                  await loadActiveWorkout();
                                  await loadWorkoutHistory();
                                } else {
                                  final result =
                                      await Navigator.push<
                                          List<Exercise>>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ExerciseLibraryScreen(),
                                    ),
                                  );

                                  if (result == null ||
                                      result.isEmpty) {
                                    return;
                                  }

                                  setState(() {
                                    selectedExercises = result;
                                  });

                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          WorkoutScreen(
                                        exercises:
                                            selectedExercises,
                                      ),
                                    ),
                                  );

                                  setState(() {
                                    selectedExercises = [];
                                  });

                                  await loadActiveWorkout();
                                  await loadWorkoutHistory();
                                }
                              },

                        child: Text(
                          activeWorkout != null
                              ? 'RESUME WORKOUT'
                              : 'START WORKOUT',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              'Recent Workouts',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (isLoadingHistory)
              const Center(
                child: CircularProgressIndicator(),
              )

            else if (workoutHistory.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No recent workouts',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )

            else
              ...workoutHistory.take(4).map(
                (workout) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.fitness_center,
                      ),

                      title: Text(
                        '${workout.exercises.length} exercises',
                      ),

                      subtitle: Text(
                        '${workout.date.day}/'
                        '${workout.date.month}/'
                        '${workout.date.year}',
                      ),

                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                WorkoutDetailsScreen(
                              workout: workout,
                            ),
                          ),
                        );

                        await loadWorkoutHistory();
                      },
                    ),
                  );
                },
              ),

            const SizedBox(height: 8),

            if (workoutHistory.length > 4)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            WorkoutHistoryScreen(
                          workouts: workoutHistory,
                        ),
                      ),
                    );

                    await loadWorkoutHistory();
                  },
                  child: const Text(
                    'VIEW ALL WORKOUTS',
                  ),
                ),
              ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,

              child: OutlinedButton.icon(
                onPressed: () async {
                  final result =
                      await Navigator.push<List<Exercise>>(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ExerciseLibraryScreen(),
                    ),
                  );

                  if (result != null) {
                    setState(() {
                      selectedExercises = result;
                    });
                  }
                },

                icon: const Icon(
                  Icons.fitness_center,
                ),

                label: const Text(
                  'Exercise Library',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkoutScreen extends StatefulWidget {
  final List<Exercise>? exercises;
  final Workout? workout;

  const WorkoutScreen({
    super.key,
    this.exercises,
    this.workout,
  });

  @override
  State<WorkoutScreen> createState() =>
      _WorkoutScreenState();
}

class _WorkoutScreenState
    extends State<WorkoutScreen> {
  late final Workout workout;

  @override
  void initState() {
    super.initState();

    if (widget.workout != null) {
      workout = widget.workout!;
    } else {
      workout = Workout(
        date: DateTime.now(),
        exercises: widget.exercises!
            .map(
              (exercise) => WorkoutExercise(
                exercise: exercise,
              ),
            )
            .toList(),
      );

      saveActiveWorkout();
    }
  }

  Future<void> saveActiveWorkout() async {
    await WorkoutStorage.saveActiveWorkout(workout);
  }

  Future<void> removeExercise(
    WorkoutExercise workoutExercise,
  ) async {
    setState(() {
      workout.exercises.remove(workoutExercise);
    });

    await saveActiveWorkout();
  }

  Future<void> addExercise() async {
    final result =
        await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ExerciseLibraryScreen(
          existingExercises:
              workout.exercises
                  .map(
                    (workoutExercise) =>
                        workoutExercise.exercise,
                  )
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
          (workoutExercise) =>
              workoutExercise.exercise.name ==
              exercise.name,
        )) {
          workout.exercises.add(
            WorkoutExercise(
              exercise: exercise,
            ),
          );
        }
      }
    });

    await saveActiveWorkout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Workout',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),

              children: [
                const Text(
                  'Exercises',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                ...workout.exercises.map(
                  (workoutExercise) =>
                      ExerciseCard(
                    workoutExercise:
                        workoutExercise,
                    onChanged:
                        saveActiveWorkout,
                    onRemove: () =>
                        removeExercise(
                      workoutExercise,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,

                  child: OutlinedButton.icon(
                    onPressed: addExercise,

                    icon: const Icon(
                      Icons.add,
                    ),

                    label: const Text(
                      'ADD EXERCISE',
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),

            child: SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: finishWorkout,

                child: const Text(
                  'FINISH WORKOUT',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> finishWorkout() async {
    await WorkoutStorage.saveWorkout(workout);
    await WorkoutStorage.clearActiveWorkout();

    if (!mounted) return;

    Navigator.pop(context, true);
  }
}

class ExerciseCard extends StatefulWidget {
  final WorkoutExercise workoutExercise;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const ExerciseCard({
    super.key,
    required this.workoutExercise,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<ExerciseCard> createState() =>
      _ExerciseCardState();
}

class _ExerciseCardState
    extends State<ExerciseCard> {
  final Map<WorkoutSet, TextEditingController>
      weightControllers = {};

  final Map<WorkoutSet, TextEditingController>
      repsControllers = {};

  TextEditingController getWeightController(
    WorkoutSet set,
  ) {
    return weightControllers.putIfAbsent(
      set,
      () => TextEditingController(
        text: set.weight?.toString() ?? '',
      ),
    );
  }

  TextEditingController getRepsController(
    WorkoutSet set,
  ) {
    return repsControllers.putIfAbsent(
      set,
      () => TextEditingController(
        text: set.reps?.toString() ?? '',
      ),
    );
  }

  void addSet() {
    setState(() {
      widget.workoutExercise.sets.add(
        WorkoutSet(),
      );
    });

    widget.onChanged();
  }

  @override
  void dispose() {
    for (final controller
        in weightControllers.values) {
      controller.dispose();
    }

    for (final controller
        in repsControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sets =
        widget.workoutExercise.sets;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.workoutExercise.exercise.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                  ),

                  onSelected: (value) {
                    if (value == 'remove') {
                      showDialog(
                        context: context,

                        builder: (context) =>
                            AlertDialog(
                          title: const Text(
                            'Remove Exercise?',
                          ),

                          content: Text(
                            'Are you sure you want to remove '
                            '${widget.workoutExercise.exercise.name}'
                            ' from this workout?',
                          ),

                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(
                                  context,
                                );
                              },

                              child: const Text(
                                'Cancel',
                              ),
                            ),

                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(
                                  context,
                                );

                                widget.onRemove();
                              },

                              child: const Text(
                                'Remove',
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },

                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'remove',

                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                          ),

                          SizedBox(width: 8),

                          Text(
                            'Remove Exercise',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (sets.isNotEmpty)
              Column(
                children: [
                  const Row(
                    children: [
                      SizedBox(
                        width: 40,

                        child: Text(
                          'Set',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),

                      Expanded(
                        child: Text(
                          'Weight',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),

                      SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          'Reps',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),

                      SizedBox(
                        width: 90,

                        child: Text(
                          'Drop',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(),

                  ...sets.asMap().entries.map(
                    (entry) {
                      final index =
                          entry.key;

                      final set =
                          entry.value;

                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 8,
                        ),

                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,

                              child: Text(
                                '${index + 1}',
                              ),
                            ),

                            Expanded(
                              child: TextField(
                                controller:
                                    getWeightController(
                                  set,
                                ),

                                keyboardType:
                                    const TextInputType
                                        .numberWithOptions(
                                  decimal: true,
                                ),

                                decoration:
                                    const InputDecoration(
                                  hintText: 'kg',

                                  border:
                                      OutlineInputBorder(),

                                  contentPadding:
                                      EdgeInsets
                                          .symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),

                                onChanged:
                                    (value) {
                                  set.weight =
                                      double.tryParse(
                                    value,
                                  );

                                  widget.onChanged();
                                },
                              ),
                            ),

                            const SizedBox(
                              width: 8,
                            ),

                            Expanded(
                              child: TextField(
                                controller:
                                    getRepsController(
                                  set,
                                ),

                                keyboardType:
                                    TextInputType
                                        .number,

                                decoration:
                                    const InputDecoration(
                                  hintText: 'reps',

                                  border:
                                      OutlineInputBorder(),

                                  contentPadding:
                                      EdgeInsets
                                          .symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),

                                onChanged:
                                    (value) {
                                  set.reps =
                                      int.tryParse(
                                    value,
                                  );

                                  widget.onChanged();
                                },
                              ),
                            ),

                            Row(
                              mainAxisSize:
                                  MainAxisSize.min,

                              children: [
                                Checkbox(
                                  value:
                                      set.isDropSet,

                                  onChanged:
                                      (value) {
                                    setState(() {
                                      set.isDropSet =
                                          value ??
                                              false;
                                    });

                                    widget.onChanged();
                                  },
                                ),

                                IconButton(
                                  icon:
                                      const Icon(
                                    Icons
                                        .delete_outline,
                                    size: 20,
                                  ),

                                  onPressed: () {
                                    setState(() {
                                      final weightController =
                                          weightControllers
                                              .remove(
                                        set,
                                      );

                                      final repsController =
                                          repsControllers
                                              .remove(
                                        set,
                                      );

                                      weightController
                                          ?.dispose();

                                      repsController
                                          ?.dispose();

                                      widget
                                          .workoutExercise
                                          .sets
                                          .remove(
                                        set,
                                      );
                                    });

                                    widget.onChanged();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              )

            else
              const Text(
                'No sets recorded',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,

              child: OutlinedButton(
                onPressed: addSet,

                child: const Text(
                  '+ ADD SET',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}