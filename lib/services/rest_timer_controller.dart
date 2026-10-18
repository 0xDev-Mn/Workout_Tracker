
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'notification_service.dart';

class RestTimerController extends ChangeNotifier {
  static const Duration defaultDuration = Duration(seconds: 90);
  static const Duration step = Duration(seconds: 30);

  Timer? _ticker;
  DateTime? _endTime;

  int _totalMs = 0;
  int _remainingMs = 0;
  bool _finished = false;
  bool _disposed = false;
  bool _backgroundAlertScheduled = false;

  int _runId = 0;

  late final AppLifecycleListener _lifecycle;

  RestTimerController() {
    _lifecycle = AppLifecycleListener(
      onStateChange: _onAppState,
    );
  }

  bool get isActive => _endTime != null;
  bool get isFinished => _finished;
  int get remainingMs => _remainingMs;

  double get progress => _totalMs == 0
      ? 0.0
      : (_remainingMs / _totalMs).clamp(0.0, 1.0);

  void start([Duration duration = defaultDuration]) {
    _ticker?.cancel();
    _cancelBackgroundAlert();

    // Invalidate any pending finish operation from an older timer.
    _runId++;

    _totalMs = duration.inMilliseconds;
    _remainingMs = _totalMs;
    _finished = false;
    _endTime = DateTime.now().add(duration);

    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _tick(),
    );

    notifyListeners();

    // Request notification permission after the user starts a timer.
    unawaited(NotificationService.requestPermissionIfNeeded());

    debugPrint('Rest timer started. Ends at $_endTime');
  }

  void addTime() {
    final end = _endTime;

    if (end == null || _finished) return;

    _endTime = end.add(step);
    _totalMs += step.inMilliseconds;
    _remainingMs += step.inMilliseconds;

    if (_backgroundAlertScheduled) {
      unawaited(NotificationService.scheduleRestOver(_endTime!));
    }

    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _runId++;

    _cancelBackgroundAlert();

    _endTime = null;
    _finished = false;
    _remainingMs = 0;
    _totalMs = 0;

    debugPrint('Rest timer stopped.');

    if (!_disposed) {
      notifyListeners();
    }
  }

  void _tick() {
    final end = _endTime;

    if (end == null || _finished || _disposed) return;

    final remaining =
        end.difference(DateTime.now()).inMilliseconds;

    if (remaining <= 0) {
      unawaited(_onFinished());
      return;
    }

    _remainingMs = remaining;
    notifyListeners();
  }

  Future<void> _onFinished() async {
    if (_finished || _disposed) return;

    _ticker?.cancel();

    final run = _runId;

    // IMPORTANT:
    // If the app has a background notification scheduled, do not
    // cancel it when the Dart timer expires in the background.
    // Android must be allowed to deliver the scheduled notification.
    if (_backgroundAlertScheduled) {
      debugPrint(
        'Timer expired in background. '
        'Preserving the scheduled OS notification.',
      );

      _backgroundAlertScheduled = false;
      _endTime = null;
      _remainingMs = 0;
      _totalMs = 0;

      if (!_disposed) {
        notifyListeners();
      }

      return;
    }

    // Normal completion while the app is active.
    debugPrint('Rest timer finished while app is active.');

    _remainingMs = 0;
    _finished = true;
    notifyListeners();

    HapticFeedback.heavyImpact();

    await Future.delayed(const Duration(milliseconds: 250));

    if (_disposed || run != _runId) return;

    HapticFeedback.heavyImpact();

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!_disposed && run == _runId) {
      stop();
    }
  }

  void _onAppState(AppLifecycleState state) {
    if (_disposed) return;

    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Android can emit both states during the same transition.
        // Schedule the alert only once.
        if (!_backgroundAlertScheduled) {
          unawaited(_scheduleBackgroundAlert());
        }
        break;

      case AppLifecycleState.resumed:
        _onResumed();
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _scheduleBackgroundAlert() async {
    final end = _endTime;

    if (end == null || _finished || _disposed) {
      debugPrint('Rest alert skipped: no active timer.');
      return;
    }

    _backgroundAlertScheduled = true;
    final run = _runId;

    debugPrint('App backgrounded. Rest timer ends at $end.');

    await NotificationService.scheduleRestOver(end);

    if (_disposed) return;

    // If the timer was explicitly stopped or replaced while the
    // notification was being scheduled, cancel the stale request.
    if (run != _runId) {
      debugPrint('Rest alert belongs to an older timer.');
      return;
    }

    // Do not cancel just because _endTime was cleared after expiry.
    final pending =
        await NotificationService.pendingRestNotifications();

    debugPrint('Rest alert pending: $pending');
  }

  void _cancelBackgroundAlert() {
    if (!_backgroundAlertScheduled) return;

    _backgroundAlertScheduled = false;
    unawaited(NotificationService.cancelRestOver());
  }

  void _onResumed() {
    final end = _endTime;

    if (end == null || _finished) {
      // Do not cancel an already scheduled OS notification here.
      // It may be the only alert for a timer that expired in the
      // background.
      return;
    }

    if (!DateTime.now().isBefore(end)) {
      debugPrint(
        'Rest timer expired while away. '
        'Preserving the scheduled OS notification.',
      );

      _ticker?.cancel();

      // Clear the countdown state without cancelling the OS alert.
      _backgroundAlertScheduled = false;
      _endTime = null;
      _finished = false;
      _remainingMs = 0;
      _totalMs = 0;

      if (!_disposed) {
        notifyListeners();
      }

      return;
    }

    // The timer still has time remaining. Return to the live
    // countdown and cancel the now-unneeded background alert.
    _cancelBackgroundAlert();
    _tick();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _lifecycle.dispose();
    _cancelBackgroundAlert();
    super.dispose();
  }
}
