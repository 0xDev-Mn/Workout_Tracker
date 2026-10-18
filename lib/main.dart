import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/workout.dart';
import 'screens/ex_lib.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/workout_history.dart';
import 'services/goal_controller.dart';
import 'services/onboarding_controller.dart';
import 'services/profile_controller.dart';
import 'services/theme_controller.dart';
import 'services/unit_controller.dart';
import 'services/workout_storage.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The saved settings are read in parallel (they share one file read).
  await Future.wait([
    ThemeController.load(),
    UnitController.load(),
    GoalController.load(),
    ProfileController.load(),
    OnboardingController.load(),
  ]);
  runApp(const WorkoutTrackerApp());
}

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'RepTracker',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          // Keeps the status bar icons readable on screens without an AppBar.
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: isDark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              child: child!,
            );
          },
          home: const _Root(),
        );
      },
    );
  }
}

/// Shows the welcome screens on a fresh install, then the main app.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _onboarding = OnboardingController.needsOnboarding;

  @override
  Widget build(BuildContext context) {
    if (_onboarding) {
      return OnboardingScreen(
        onFinished: () => setState(() => _onboarding = false),
      );
    }

    return const MainNavigationScreen();
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // Tabs are only built the first time they are opened, so startup only
  // has to build the Home screen.
  final Set<int> _visited = {0};

  List<Workout> _workouts = [];
  bool _isLoadingHistory = true;
  int _historyVersion = 0;

  Future<void> _loadHistory() async {
    final workouts = await WorkoutStorage.getWorkouts();

    if (!mounted) return;

    setState(() {
      _workouts = workouts.reversed.toList();
      _isLoadingHistory = false;
    });
  }

  Future<void> _onDestinationSelected(int index) async {
    setState(() {
      _selectedIndex = index;
      _visited.add(index);
    });

    if (index == 2) {
      setState(() {
        _isLoadingHistory = true;
        _historyVersion++;
      });

      await _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget tab(int index, Widget Function() build) =>
        _visited.contains(index) ? build() : const SizedBox.shrink();

    final screens = <Widget>[
      const HomeScreen(),
      tab(1, () => const ExerciseLibraryScreen(selectionMode: false)),
      tab(
        2,
        () => _isLoadingHistory
            ? const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              )
            : WorkoutHistoryScreen(
                key: ValueKey(_historyVersion),
                workouts: _workouts,
              ),
      ),
      tab(3, () => const ProgressScreen()),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Exercises',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Progress',
          ),
        ],
      ),
    );
  }
}