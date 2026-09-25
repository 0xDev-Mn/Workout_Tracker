import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/workout_storage.dart';

class WorkoutDetailsScreen extends StatelessWidget {
  final Workout workout;

  const WorkoutDetailsScreen({
    super.key,
    required this.workout,
  });

  Future<void> confirmDelete(
    BuildContext context,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Workout?',
        ),
        content: const Text(
          'Are you sure you want to delete this workout '
          'from your history?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    await WorkoutStorage.deleteWorkout(workout);

    if (!context.mounted) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workout Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${workout.date.day}/'
            '${workout.date.month}/'
            '${workout.date.year}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 24),

          ...workout.exercises.map(
            (workoutExercise) {
              final recordedSets = workoutExercise.sets
                  .where(
                    (set) =>
                        set.weight != null ||
                        set.reps != null,
                  )
                  .toList();

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
                      Text(
                        workoutExercise.exercise.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (recordedSets.isEmpty)
                        const Text(
                          'No sets recorded',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        )
                      else
                        ...recordedSets
                            .asMap()
                            .entries
                            .map(
                          (entry) {
                            final setNumber =
                                entry.key + 1;
                            final set = entry.value;

                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom: 8,
                              ),

                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      'Set $setNumber',
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: Text(
                                      '${set.weight ?? 0} kg × '
                                      '${set.reps ?? 0} reps',
                                    ),
                                  ),

                                  if (set.isDropSet)
                                    const Text(
                                      'DROP SET',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                confirmDelete(context);
              },
              icon: const Icon(
                Icons.delete_outline,
              ),
              label: const Text(
                'DELETE WORKOUT',
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}