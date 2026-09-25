import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/workout_storage.dart';
import 'workout_details.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  final List<Workout> workouts;

  const WorkoutHistoryScreen({
    super.key,
    required this.workouts,
  });

  @override
  State<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState
    extends State<WorkoutHistoryScreen> {
  late List<Workout> workouts;

  @override
  void initState() {
    super.initState();

    workouts = List.from(widget.workouts);
  }

  Future<void> confirmDelete(
    BuildContext context,
    Workout workout,
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

    if (!mounted) return;

    setState(() {
      workouts.remove(workout);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workout History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: workouts.isEmpty
          ? const Center(
              child: Text(
                'No completed workouts yet.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: workouts.length,
              itemBuilder: (context, index) {
                final workout = workouts[index];

                return Card(
                  margin: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              WorkoutDetailsScreen(
                            workout: workout,
                          ),
                        ),
                      );
                    },

                    title: Text(
                      '${workout.exercises.length} exercises',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    subtitle: Text(
                      '${workout.date.day}/'
                      '${workout.date.month}/'
                      '${workout.date.year}',
                    ),

                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                      ),
                      onPressed: () {
                        confirmDelete(
                          context,
                          workout,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}