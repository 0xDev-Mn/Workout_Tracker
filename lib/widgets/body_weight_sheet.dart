import 'package:flutter/material.dart';

import '../models/body_weight_entry.dart';
import '../services/body_weight_storage.dart';
import '../services/unit_controller.dart';
import '../services/workout_events.dart';
import '../theme/app_theme.dart';
import '../utils/workout_format.dart';

/// Bottom sheet to log (or edit) a body weight. Returns true when saved.
Future<bool?> showBodyWeightSheet(
  BuildContext context, {
  BodyWeightEntry? existing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BodyWeightSheet(existing: existing),
  );
}

class _BodyWeightSheet extends StatefulWidget {
  final BodyWeightEntry? existing;

  const _BodyWeightSheet({this.existing});

  @override
  State<_BodyWeightSheet> createState() => _BodyWeightSheetState();
}

class _BodyWeightSheetState extends State<_BodyWeightSheet> {
  late final TextEditingController _controller;
  late DateTime _date;
  String _hint = '0';
  String? _error;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    _controller = TextEditingController(
      text: existing == null ? '' : formatWeight(existing.kg),
    );
    _date = existing?.date ?? DateTime.now();

    _loadHint();
  }

  /// Shows your latest weight as faded placeholder text.
  Future<void> _loadHint() async {
    final entries = await BodyWeightStorage.getEntries();
    if (!mounted || entries.isEmpty) return;
    setState(() => _hint = formatWeight(entries.last.kg));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final value = double.tryParse(_controller.text.trim().replaceAll(',', '.'));

    if (value == null || value <= 0 || value > 1000) {
      setState(() => _error = 'Enter your weight in ${UnitController.label}');
      return;
    }

    await BodyWeightStorage.save(
      BodyWeightEntry(
        id: widget.existing?.id,
        date: _date,
        kg: UnitController.fromDisplay(value),
      ),
    );
    WorkoutEvents.notifyChanged();

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final isToday = _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'Log body weight' : 'Edit weight',
                style: t.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: _hint,
                  hintStyle: TextStyle(color: context.colors.hint),
                  suffixText: unitLabel,
                  suffixStyle: TextStyle(
                    fontSize: 16,
                    color: context.colors.muted,
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: context.colors.muted,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isToday ? 'Today' : formatLongDate(_date),
                        style: t.bodyLarge,
                      ),
                      const Spacer(),
                      Text('Change', style: t.bodySmall),
                    ],
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}