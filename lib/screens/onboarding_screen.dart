import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/goal_controller.dart';
import '../services/onboarding_controller.dart';
import '../services/profile_controller.dart';
import '../services/unit_controller.dart';
import '../theme/app_theme.dart';

/// First-launch welcome: intro, name, weight unit and weekly goal.
/// [onFinished] is called after the choices are saved.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _pageCount = 4;

  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();

  int _page = 0;
  WeightUnit _unit = UnitController.unit.value;
  int _goal = GoalController.weeklyGoal.value;

  @override
  void initState() {
    super.initState();
    _nameController.text = ProfileController.name.value;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();

    if (_page == _pageCount - 1) {
      _finish();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    FocusScope.of(context).unfocus();

    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    FocusScope.of(context).unfocus();

    await UnitController.set(_unit);
    await GoalController.set(_goal);
    await ProfileController.set(_nameController.text);
    await OnboardingController.markDone();

    if (mounted) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    _Dots(count: _pageCount, current: _page),
                    const Spacer(),
                    if (!isLast)
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: context.colors.muted,
                        ),
                        child: const Text('Skip'),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _buildWelcome(context),
                  _buildName(context),
                  _buildUnit(context),
                  _buildGoal(context),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _next,
                    child: Text(
                      _page == 0
                          ? 'Get started'
                          : isLast
                              ? "Let's go"
                              : 'Continue',
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: _page > 0
                        ? TextButton(
                            onPressed: _back,
                            style: TextButton.styleFrom(
                              foregroundColor: context.colors.muted,
                            ),
                            child: const Text('Back'),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- pages ----

  Widget _frame({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final t = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(subtitle, style: t.bodySmall?.copyWith(fontSize: 15)),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final t = Theme.of(context).textTheme;

    Widget feature(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: context.colors.ink),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(text, style: t.bodyLarge)),
            ],
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
            ),
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: const Icon(
                Icons.fitness_center,
                size: 52,
                color: AppColors.onAccent,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Welcome to RepTracker',
            textAlign: TextAlign.center,
            style: t.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Log your workouts, watch your progress and beat your records.',
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 32),
          feature(Icons.bolt_rounded, 'Log sets in seconds'),
          feature(Icons.show_chart_rounded, 'See your progress over time'),
          feature(Icons.lock_outline_rounded, 'Everything stays on your phone'),
        ],
      ),
    );
  }

  Widget _buildName(BuildContext context) {
    return _frame(
      title: 'What should we call you?',
      subtitle: "Optional. We'll use it to greet you on the home screen.",
      child: TextField(
        controller: _nameController,
        maxLength: 24,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Your first name',
          hintStyle: TextStyle(color: context.colors.hint),
          counterText: '',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onSubmitted: (_) => _next(),
      ),
    );
  }

  Widget _buildUnit(BuildContext context) {
    return _frame(
      title: 'Which unit do you use?',
      subtitle: 'You can change this any time in Settings.',
      child: Column(
        children: [
          _ChoiceCard(
            title: 'Kilograms (kg)',
            subtitle: 'Metric',
            selected: _unit == WeightUnit.kg,
            onTap: () => setState(() => _unit = WeightUnit.kg),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            title: 'Pounds (lb)',
            subtitle: 'Imperial',
            selected: _unit == WeightUnit.lb,
            onTap: () => setState(() => _unit = WeightUnit.lb),
          ),
        ],
      ),
    );
  }

  Widget _buildGoal(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return _frame(
      title: 'Set a weekly goal',
      subtitle: 'How many workouts a week do you want to do?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final n in const [1, 2, 3, 4, 5, 6, 7, 0])
                ChoiceChip(
                  label: Text(n == 0 ? 'No goal' : '$n'),
                  selected: _goal == n,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _goal = n),
                  selectedColor: AppColors.accent,
                  backgroundColor: context.colors.surface,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color:
                          _goal == n ? AppColors.accent : context.colors.border,
                    ),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color:
                        _goal == n ? AppColors.onAccent : context.colors.ink,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _goal == 0
                ? 'No problem. You can set one later in Settings.'
                : _goal <= 3
                    ? 'A great place to start. You can change it any time.'
                    : 'Ambitious! You can change it any time.',
            style: t.bodySmall?.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int current;

  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 6),
            width: i == current ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? AppColors.accent : context.colors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : context.colors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: t.bodySmall),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}