import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../services/rest_timer_controller.dart';
import '../theme/app_theme.dart';

/// Compact countdown shown above the "Finish workout" button.
/// It slides in when the timer starts and disappears when it ends.
class RestTimerBar extends StatelessWidget {
  final RestTimerController controller;

  const RestTimerBar({super.key, required this.controller});

  String _format(int ms) {
    final totalSeconds = (ms / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: controller.isActive
              ? _buildBar(context)
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }

  Widget _buildBar(BuildContext context) {
    final finished = controller.isFinished;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
        decoration: BoxDecoration(
          color: context.colors.heroBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _format(controller.remainingMs),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        finished ? 'Rest over' : 'Resting',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: finished
                              ? AppColors.accent
                              : const Color(0xFFB5B5B0),
                        ),
                      ),
                    ],
                  ),
                ),
                _BarButton(
                  label: '+30s',
                  filled: false,
                  onTap: finished ? null : controller.addTime,
                ),
                const SizedBox(width: 8),
                _BarButton(
                  label: 'Skip',
                  filled: true,
                  onTap: controller.stop,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: finished ? 1.0 : controller.progress,
                minHeight: 5,
                backgroundColor: const Color(0xFF3A3A37),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _BarButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: filled
                ? null
                : Border.all(color: const Color(0x4DFFFFFF)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: filled ? AppColors.onAccent : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}