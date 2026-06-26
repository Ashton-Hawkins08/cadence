import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/presentation/providers/calendar_provider.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:intl/intl.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final CalendarEvent? editingEvent;

  const CreateEventScreen({super.key, this.initialDate, this.editingEvent});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _startDate;
  late DateTime _endDate;
  Color? _selectedColor;
  final List<_ReminderEntry> _reminders = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.editingEvent;
    _titleCtrl = TextEditingController(text: ev?.title ?? '');
    _notesCtrl = TextEditingController(text: ev?.notes ?? '');

    final base = widget.initialDate ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    _startDate = ev != null ? _toLocalMidnight(ev.startDate) : today;
    _endDate = ev != null ? _toLocalMidnight(ev.endDate) : today;
    _selectedColor =
        ev != null ? EventColors.fromValue(ev.colorValue) : null;

    if (ev != null) _loadExistingReminders(ev.id);
  }

  DateTime _toLocalMidnight(DateTime dt) {
    final l = dt.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  Future<void> _loadExistingReminders(int eventId) async {
    final reminders = await ref
        .read(calendarRepositoryProvider)
        .getRemindersForEvent(eventId);
    if (!mounted) return;
    setState(() {
      for (final r in reminders) {
        _reminders.add(_ReminderEntry(
          daysBefore: r.daysBefore,
          customDate:
              r.customDate != null ? _toLocalMidnight(r.customDate!) : null,
        ));
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final first = DateTime(2000);
    final last = DateTime(2050, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_startDate.isAfter(_endDate)) _startDate = _endDate;
      }
    });
  }

  void _addReminder() async {
    final result = await _showReminderPicker();
    if (result != null) {
      setState(() => _reminders.add(result));
    }
  }

  Future<_ReminderEntry?> _showReminderPicker() async {
    _ReminderEntry? saved;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, __) => _ReminderPickerDialog(
        onSave: (entry) {
          saved = entry;
          Navigator.pop(ctx);
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );

    return saved;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _saving = true);

    final title = _titleCtrl.text.trim();
    final notes = _notesCtrl.text.trim();
    final startUtc =
        DateTime.utc(_startDate.year, _startDate.month, _startDate.day);
    final endUtc =
        DateTime.utc(_endDate.year, _endDate.month, _endDate.day);
    final colorVal = _selectedColor != null
        ? EventColors.toValue(_selectedColor!)
        : null;

    final repo = ref.read(calendarRepositoryProvider);

    try {
      int eventId;
      if (widget.editingEvent != null) {
        eventId = widget.editingEvent!.id;
        await repo.updateEvent(
          eventId,
          CalendarEventsCompanion(
            title: Value(title),
            notes: Value(notes),
            startDate: Value(startUtc),
            endDate: Value(endUtc),
            colorValue: Value(colorVal),
          ),
        );
        // Replace all old reminders with new ones (single bulk delete)
        await repo.deleteRemindersForEvent(eventId);
      } else {
        eventId = await repo.createEvent(
          title: title,
          notes: notes,
          startDate: startUtc,
          endDate: endUtc,
          colorValue: colorVal,
        );
      }

      for (final r in _reminders) {
        await repo.addReminder(
          eventId,
          r.daysBefore,
          customDate: r.customDate != null
              ? DateTime.utc(r.customDate!.year, r.customDate!.month,
                  r.customDate!.day)
              : null,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.editingEvent != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Event' : 'New Event'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Title ────────────────────────────────────────────────────────
            TextFormField(
              controller: _titleCtrl,
              autofocus: !isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Event Title *',
                hintText: 'Band camp, Competition, Rehearsal...',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Title is required';
                if (v.trim().length > 80) return 'Max 80 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Notes ────────────────────────────────────────────────────────
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Details, location, what to prepare...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // ── Dates ────────────────────────────────────────────────────────
            _SectionLabel('Dates'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Start',
                    date: _startDate,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTile(
                    label: 'End',
                    date: _endDate,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Color ────────────────────────────────────────────────────────
            _SectionLabel('Color (optional)'),
            const SizedBox(height: 10),
            _ColorPicker(
              selected: _selectedColor,
              onChanged: (c) => setState(() => _selectedColor = c),
            ),
            const SizedBox(height: 20),

            // ── Reminders ────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel('Reminders'),
                TextButton.icon(
                  onPressed: _addReminder,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_reminders.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No reminders set',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              )
            else
              ...List.generate(_reminders.length, (i) {
                final r = _reminders[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.notifications_outlined,
                        color: theme.colorScheme.primary, size: 20),
                    title: Text(_reminderLabel(r),
                        style: theme.textTheme.bodyMedium),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          setState(() => _reminders.removeAt(i)),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _reminderLabel(_ReminderEntry r) {
    if (r.daysBefore == -1 && r.customDate != null) {
      return 'Custom: ${DateFormat('MMM d, yyyy').format(r.customDate!)}';
    }
    return switch (r.daysBefore) {
      0 => 'Same day',
      1 => '1 day before',
      2 => '2 days before',
      3 => '3 days before',
      7 => '1 week before',
      _ => '${r.daysBefore} days before',
    };
  }
}

// ─── Reminder entry model ─────────────────────────────────────────────────────

class _ReminderEntry {
  final int daysBefore; // -1 = custom date
  final DateTime? customDate;
  const _ReminderEntry({required this.daysBefore, this.customDate});
}

// ─── Reminder picker dialog ───────────────────────────────────────────────────

class _ReminderPickerDialog extends StatefulWidget {
  final void Function(_ReminderEntry) onSave;
  final VoidCallback onCancel;
  const _ReminderPickerDialog(
      {required this.onSave, required this.onCancel});

  @override
  State<_ReminderPickerDialog> createState() => _ReminderPickerDialogState();
}

class _ReminderPickerDialogState extends State<_ReminderPickerDialog> {
  static const _options = [
    (label: 'Same day', days: 0),
    (label: '1 day before', days: 1),
    (label: '2 days before', days: 2),
    (label: '3 days before', days: 3),
    (label: '1 week before', days: 7),
    (label: 'Custom date', days: -1),
  ];
  int _selectedDays = 1;
  DateTime? _customDate;

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2050, 12, 31),
    );
    if (picked != null && mounted) setState(() => _customDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add Reminder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._options.map((opt) => RadioListTile<int>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(opt.label, style: theme.textTheme.bodyMedium),
                value: opt.days,
                groupValue: _selectedDays,
                onChanged: (v) => setState(() => _selectedDays = v!),
                activeColor: theme.colorScheme.primary,
              )),
          if (_selectedDays == -1) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickCustomDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      _customDate != null
                          ? DateFormat('MMM d, yyyy').format(_customDate!)
                          : 'Tap to pick date',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: widget.onCancel, child: const Text('Cancel')),
        ElevatedButton(
          onPressed: (_selectedDays == -1 && _customDate == null)
              ? null
              : () => widget
                  .onSave(_ReminderEntry(
                    daysBefore: _selectedDays,
                    customDate: _customDate,
                  )),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateTile(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 4),
            Text(DateFormat('MMM d, yyyy').format(date),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final Color? selected;
  final void Function(Color?) onChanged;
  const _ColorPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // "No color" chip
        GestureDetector(
          onTap: () => onChanged(null),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected == null
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                width: selected == null ? 3 : 1,
              ),
            ),
            child: const Icon(Icons.block, size: 18, color: Colors.grey),
          ),
        ),
        ...EventColors.palette.map((color) {
          final isSelected = selected?.value == color.value;
          return GestureDetector(
            onTap: () => onChanged(color),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          );
        }),
      ],
    );
  }
}
