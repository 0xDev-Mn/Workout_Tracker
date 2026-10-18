import 'package:flutter/material.dart';

import '../models/workout_set.dart';
import '../theme/app_theme.dart';

class SetTypeStyle {
  final Color background;
  final Color foreground;
  final String short;

  const SetTypeStyle(this.background, this.foreground, this.short);
}

SetTypeStyle setTypeStyle(BuildContext context, SetType type) {
  final dark = Theme.of(context).brightness == Brightness.dark;

  switch (type) {
    case SetType.normal:
      return SetTypeStyle(context.colors.bg, context.colors.muted, '');
    case SetType.warmup:
      return SetTypeStyle(
        const Color(0x33FFB300),
        dark ? const Color(0xFFFFC857) : const Color(0xFF9A5B00),
        'W',
      );
    case SetType.drop:
      return const SetTypeStyle(AppColors.accent, AppColors.onAccent, 'D');
    case SetType.failure:
      return SetTypeStyle(
        const Color(0x26E53935),
        dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828),
        'F',
      );
  }
}

/// Small square showing a set's type: W (warm-up), D (drop), F (failure),
/// or a selector icon for a normal set.
class SetTypeBadge extends StatelessWidget {
  final SetType type;
  final double size;

  const SetTypeBadge({super.key, required this.type, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final style = setTypeStyle(context, type);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: type == SetType.normal
          ? Icon(
              Icons.unfold_more_rounded,
              size: size * 0.56,
              color: style.foreground,
            )
          : Text(
              style.short,
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w700,
                color: style.foreground,
              ),
            ),
    );
  }
}

/// Small text pill such as "Warm-up", used where sets are listed.
class SetTypeTag extends StatelessWidget {
  final SetType type;

  const SetTypeTag({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final style = setTypeStyle(context, type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: style.foreground,
        ),
      ),
    );
  }
}