import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/rest_timer_controller.dart';
import '../services/notification_service.dart';

import '../theme/app_theme.dart';

enum _TimerPhase { setup, running, finished }

/// Full-screen translucent rest timer shown on top of the workout screen.
/// Because it is a modal route, nothing underneath can be touched
/// until the timer is closed.
///
/// Flow: set the time -> tap the timer to start -> countdown -> auto close
/// (or "Stop timer" to close early).
class RestTimerScreen extends StatefulWidget {
  /// Time shown when the overlay opens.
  static const Duration defaultDuration =
      RestTimerController.defaultDuration;

  /// Step used by the +/- buttons.
  static const Duration step = Duration(seconds: 30);

  /// Limits while setting the time.
  static const Duration minDuration = Duration(seconds: 30);
  static const Duration maxDuration = Duration(minutes: 30);

  const RestTimerScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => const RestTimerScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<RestTimerScreen> createState() => _RestTimerScreenState();
}

class _RestTimerScreenState extends State<RestTimerScreen> {
  _TimerPhase _phase = _TimerPhase.setup;

  // Time chosen during setup.
  int _setupMs = RestTimerScreen.defaultDuration.inMilliseconds;

  // Running state.
  late DateTime _endTime;
  int _totalMs = 0;
  int _remainingMs = 0;
  Timer? _ticker;

  bool _closed = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ---- setup ----

  void _adjustSetup(int deltaMs) {
    setState(() {
      _setupMs = (_setupMs + deltaMs).clamp(
        RestTimerScreen.minDuration.inMilliseconds,
        RestTimerScreen.maxDuration.inMilliseconds,
      );
    });
  }

  // ---- running ----

  void _start() {
    setState(() {
      _phase = _TimerPhase.running;
      _totalMs = _setupMs;
      _remainingMs = _setupMs;
      _endTime = DateTime.now().add(Duration(milliseconds: _setupMs));
    });

    // The end time is absolute, so the countdown stays correct even if
    // the UI was briefly busy.
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    if (!mounted || _phase != _TimerPhase.running) return;

    final remaining = _endTime.difference(DateTime.now()).inMilliseconds;

    if (remaining <= 0) {
      _onFinished();
      return;
    }

    setState(() {
      _remainingMs = remaining;
    });
  }

  void _addTimeWhileRunning() {
    if (_phase != _TimerPhase.running) return;

    final extra = RestTimerScreen.step.inMilliseconds;

    setState(() {
      _endTime = _endTime.add(RestTimerScreen.step);
      _totalMs += extra;
      _remainingMs += extra;
    });
  }

  Future<void> _onFinished() async {
    _ticker?.cancel();

    setState(() {
      _remainingMs = 0;
      _phase = _TimerPhase.finished;
    });

    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 250));
    HapticFeedback.heavyImpact();

    // Leave "Rest over" on screen for a moment, then close.
    await Future.delayed(const Duration(milliseconds: 1200));
    _close();
  }

  void _close() {
    if (!mounted || _closed) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  // ---- display helpers ----

  int get _displayMs =>
      _phase == _TimerPhase.setup ? _setupMs : _remainingMs;

  String get _timeText {
    final totalSeconds = (_displayMs / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get _statusText {
    switch (_phase) {
      case _TimerPhase.setup:
        return 'Tap to start';
      case _TimerPhase.running:
        return 'Resting';
      case _TimerPhase.finished:
        return 'Rest over';
    }
  }

  double get _progress {
    if (_phase == _TimerPhase.setup) return 1.0;
    if (_totalMs == 0) return 0.0;
    return (_remainingMs / _totalMs).clamp(0.0, 1.0);
  }

  ButtonStyle get _outlinedStyle => OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: const Color(0x66FFFFFF),
        side: const BorderSide(color: Color(0x4DFFFFFF)),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      );

  // ---- bottom buttons per phase ----

  Widget _buildSetupButtons() {
    final atMin =
        _setupMs <= RestTimerScreen.minDuration.inMilliseconds;
    final atMax =
        _setupMs >= RestTimerScreen.maxDuration.inMilliseconds;
    final stepMs = RestTimerScreen.step.inMilliseconds;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: atMin ? null : () => _adjustSetup(-stepMs),
                icon: const Icon(Icons.remove, size: 20),
                label: const Text('30 sec'),
                style: _outlinedStyle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: atMax ? null : () => _adjustSetup(stepMs),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('30 sec'),
                style: _outlinedStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _close,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xB3FFFFFF),
            minimumSize: const Size.fromHeight(44),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildRunningButtons() {
    final finished = _phase == _TimerPhase.finished;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: finished ? null : _addTimeWhileRunning,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('30 seconds'),
            style: _outlinedStyle,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _close,
            icon: const Icon(Icons.stop_rounded, size: 22),
            label: const Text('Stop timer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.onAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ringSize =
        (MediaQuery.of(context).size.width * 0.7).clamp(200.0, 300.0);

    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: const Color(0xD9111111),
          width: double.infinity,
          height: double.infinity,
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 32),
                const Text(
                  'REST TIMER',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: AppColors.accent,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _phase == _TimerPhase.setup ? _start : null,
                  child: SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          backgroundColor: const Color(0x26FFFFFF),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _timeText,
                            style: const TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _statusText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _phase == _TimerPhase.running
                                  ? const Color(0xFFB5B5B0)
                                  : AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: _phase == _TimerPhase.setup
                      ? _buildSetupButtons()
                      : _buildRunningButtons(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}