import 'package:flutter/material.dart';
import '../models/exercise.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  final List<Exercise> existingExercises;

  const ExerciseLibraryScreen({
    super.key, 
    this.existingExercises = const [],});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {

  @override
  void initState() {
    super.initState();
    
    selectedExercises = List.from(
      widget.existingExercises
    );
  }

  final List<Exercise> exercises = const [
    // Chest
    Exercise(
      name: 'Bench Press',
      muscleGroup: 'Chest',
    ),
    Exercise(
      name: 'Incline Bench Press',
      muscleGroup: 'Chest',
    ),
    Exercise(
      name: 'Dumbbell Press',
      muscleGroup: 'Chest',
    ),
    Exercise(
      name: 'Incline Dumbbell Press',
      muscleGroup: 'Chest',
    ),
    Exercise(
      name: 'Cable Fly',
      muscleGroup: 'Chest',
    ),
    Exercise(
      name: 'Pec Deck',
      muscleGroup: 'Chest',
    ),

    // Back
    Exercise(
      name: 'Lat Pulldown',
      muscleGroup: 'Back',
    ),
    Exercise(
      name: 'Pull-Up',
      muscleGroup: 'Back',
    ),
    Exercise(
      name: 'Seated Cable Row',
      muscleGroup: 'Back',
    ),
    Exercise(
      name: 'Barbell Row',
      muscleGroup: 'Back',
    ),
    Exercise(
      name: 'Dumbbell Row',
      muscleGroup: 'Back',
    ),

    // Shoulders
    Exercise(
      name: 'Overhead Press',
      muscleGroup: 'Shoulders',
    ),
    Exercise(
      name: 'Dumbbell Shoulder Press',
      muscleGroup: 'Shoulders',
    ),
    Exercise(
      name: 'Lateral Raise',
      muscleGroup: 'Shoulders',
    ),
    Exercise(
      name: 'Rear Delt Fly',
      muscleGroup: 'Shoulders',
    ),
    Exercise(
      name: 'Face Pull',
      muscleGroup: 'Shoulders',
    ),

    // Legs
    Exercise(
      name: 'Squat',
      muscleGroup: 'Legs',
    ),
    Exercise(
      name: 'Leg Press',
      muscleGroup: 'Legs',
    ),
    Exercise(
      name: 'Leg Extension',
      muscleGroup: 'Legs',
    ),
    Exercise(
      name: 'Leg Curl',
      muscleGroup: 'Legs',
    ),
    Exercise(
      name: 'Romanian Deadlift',
      muscleGroup: 'Legs',
    ),
    Exercise(
      name: 'Hip Thrust',
      muscleGroup: 'Legs',
    ),
    Exercise(
      name: 'Calf Raise',
      muscleGroup: 'Legs',
    ),

    // Arms
    Exercise(
      name: 'Barbell Curl',
      muscleGroup: 'Arms',
    ),
    Exercise(
      name: 'Dumbbell Curl',
      muscleGroup: 'Arms',
    ),
    Exercise(
      name: 'Hammer Curl',
      muscleGroup: 'Arms',
    ),
    Exercise(
      name: 'Tricep Pushdown',
      muscleGroup: 'Arms',
    ),
    Exercise(
      name: 'Skull Crusher',
      muscleGroup: 'Arms',
    ),
    Exercise(
      name: 'Overhead Tricep Extension',
      muscleGroup: 'Arms',
    ),
  ];

  // Exercises currently selected by the user.
  late List<Exercise> selectedExercises;

  List<Exercise> getExercisesFor(String muscleGroup) {
    return exercises
        .where((exercise) => exercise.muscleGroup == muscleGroup)
        .toList();
  }

  void toggleExercise(Exercise exercise) {
    setState(() {
      if (selectedExercises.contains(exercise)) {
        selectedExercises.remove(exercise);
      } else {
        selectedExercises.add(exercise);
      }
    });
  }

  Widget buildMuscleGroupCard(
    String muscleGroup,
    List<Exercise> groupExercises,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              muscleGroup,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            ...groupExercises.map(
              (exercise) {
                final isSelected = selectedExercises.any(
                  (selected) => selected.name == exercise.name,
                );
                final isExisting = widget.existingExercises.any(
                  (existing) => existing.name == exercise.name,
                );

                return Card(
                  elevation: 0,
                  color: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                      : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                    ),

                    leading: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.fitness_center,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),

                    title: Text(
                      exercise.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: isExisting
                          ? null
                          : (_) {
                              toggleExercise(exercise);
                            },
                    ),

                    onTap: isExisting
                        ? null
                        : () {
                            toggleExercise(exercise);
                          },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chestExercises = getExercisesFor('Chest');
    final backExercises = getExercisesFor('Back');
    final armsExercises = getExercisesFor('Arms');
    final shoulderExercises = getExercisesFor('Shoulders');
    final legExercises = getExercisesFor('Legs');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Exercise Library',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (selectedExercises.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '${selectedExercises.length} exercises selected',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          buildMuscleGroupCard(
            'Chest',
            chestExercises,
          ),

          buildMuscleGroupCard(
            'Back',
            backExercises,
          ),

          buildMuscleGroupCard(
            'Arms',
            armsExercises,
          ),

          buildMuscleGroupCard(
            'Shoulders',
            shoulderExercises,
          ),

          buildMuscleGroupCard(
            'Legs',
            legExercises,
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: selectedExercises.isEmpty
                  ? null
                  : () {
                      Navigator.pop(
                        context,
                        selectedExercises,
                      );
                    },
              child: const Text(
                'ADD TO WORKOUT',
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}