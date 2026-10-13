import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Countdown used by the rest-timer bar on the workout screen.
/// It starts automatically when a set is ticked as done.
class RestTimerController extends ChangeNotifier {
  /// Length of the rest timer when it starts by itself.
  static const Duration defaultDuration = Duration(seconds: 90);

  /// How much "+30s" adds.
  static const Duration step = Duration(seconds: 30);

  Timer? _ticker;
  DateTime? _endTime;
  int _totalMs = 0;
  int _remainingMs = 0;
  bool _finished = false;
  bool _disposed = false;
  int _runId = 0;

  /// True while counting down and for a moment after it reaches zero.
  bool get isActive => _endTime != null;
  bool get isFinished => _finished;
  int get remainingMs => _remainingMs;

  double get progress =>
      _totalMs == 0 ? 0.0 : (_remainingMs / _totalMs).clamp(0.0, 1.0);

  /// Starts (or restarts) the countdown.
  void start([Duration duration = defaultDuration]) {
    _ticker?.cancel();
    _runId++;

    _totalMs = duration.inMilliseconds;
    _remainingMs = _totalMs;
    _finished = false;
    _endTime = DateTime.now().add(duration);

    // The end time is absolute, so the countdown stays correct even if the
    // UI is briefly busy.
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    notifyListeners();
  }

  void addTime() {
    if (_endTime == null || _finished) return;

    _endTime = _endTime!.add(step);
    _totalMs += step.inMilliseconds;
    _remainingMs += step.inMilliseconds;
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _runId++;

    _endTime = null;
    _finished = false;
    _remainingMs = 0;
    _totalMs = 0;

    if (!_disposed) notifyListeners();
  }

  void _tick() {
    final end = _endTime;
    if (end == null || _finished || _disposed) return;

    final remaining = end.difference(DateTime.now()).inMilliseconds;

    if (remaining <= 0) {
      _onFinished();
      return;
    }

    _remainingMs = remaining;
    notifyListeners();
  }

  Future<void> _onFinished() async {
    _ticker?.cancel();
    final run = _runId;

    _remainingMs = 0;
    _finished = true;
    notifyListeners();

    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 250));
    HapticFeedback.heavyImpact();

    // Leave "Rest over" visible for a moment, then hide the bar —
    // unless a new timer was started or this one was skipped meanwhile.
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!_disposed && run == _runId) stop();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}