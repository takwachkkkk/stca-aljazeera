import 'package:flutter/material.dart';
import 'formulaire_decorations.dart';

enum ModePlanificationUI { dateExacte, periode }

class DateLivraisonSection extends StatelessWidget {
  final ModePlanificationUI mode;
  final ValueChanged<ModePlanificationUI> onModeChanged;
  final DateTime? dateExacte;
  final DateTime? periodeDebut;
  final DateTime? periodeFin;
  final ValueChanged<DateTime?> onDateExacteChanged;
  final ValueChanged<DateTime?> onPeriodeDebutChanged;
  final ValueChanged<DateTime?> onPeriodeFinChanged;

  /// Set to false to suppress the internal "Date de Livraison de L'échantillon" label.
  final bool showLabel;

  const DateLivraisonSection({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.dateExacte,
    required this.periodeDebut,
    required this.periodeFin,
    required this.onDateExacteChanged,
    required this.onPeriodeDebutChanged,
    required this.onPeriodeFinChanged,
    this.showLabel = true,
  });

  String _fmtDateTime(DateTime d) {
    final base =
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
    if (d.hour == 0 && d.minute == 0) return base;
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '$base  $hour:$minute $period';
  }

  /// Date only — keeps whatever time was already set on [initial], doesn't
  /// prompt for a time. The time is set separately, on demand, via the small
  /// clock button next to the date field (see [_TimeIconButton]).
  Future<DateTime?> _pickDate(BuildContext ctx, {DateTime? initial}) async {
    final initialDateOnly = initial != null
        ? DateTime(initial.year, initial.month, initial.day)
        : DateTime.now();

    final date = await showDatePicker(
      context: ctx,
      initialDate: initialDateOnly,
      firstDate: DateTime.now(),
      lastDate: DateTime(2130),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kGreen,
            onPrimary: Colors.white,
            onSurface: kDarkText,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null) return null;

    if (initial != null && (initial.hour != 0 || initial.minute != 0)) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        initial.hour,
        initial.minute,
      );
    }
    return DateTime(date.year, date.month, date.day);
  }

  /// Opens the time sheet on demand, for a date already chosen via
  /// [_pickDate]. Returns null if the user cancels or taps "Ignorer".
  Future<DateTime?> _pickTime(
    BuildContext ctx, {
    required DateTime dateBase,
  }) async {
    final time = await _showScrollTimeSheet(
      ctx,
      initial: dateBase.hour != 0 || dateBase.minute != 0
          ? TimeOfDay(hour: dateBase.hour, minute: dateBase.minute)
          : null,
    );
    if (time == null) return null;
    return DateTime(
      dateBase.year,
      dateBase.month,
      dateBase.day,
      time.hour,
      time.minute,
    );
  }

  bool get _isFilled {
    if (mode == ModePlanificationUI.dateExacte) return dateExacte != null;
    return periodeDebut != null && periodeFin != null;
  }

  /// « Date précise » : ouvre le calendrier. Annuler ne change rien.
  Future<void> _choisirDateExacte(BuildContext context) async {
    final dt = await _pickDate(context, initial: dateExacte);
    if (dt == null) return;
    onModeChanged(ModePlanificationUI.dateExacte);
    onDateExacteChanged(dt);
  }

  /// « Période estimée » : un seul calendrier, date de début puis de fin.
  Future<void> _choisirPeriode(BuildContext context) async {
    final maintenant = DateTime.now();
    final aujourdhui = DateTime(
      maintenant.year,
      maintenant.month,
      maintenant.day,
    );
    final debut = periodeDebut;
    final fin = periodeFin;
    final plage = await showDateRangePicker(
      context: context,
      firstDate: aujourdhui,
      lastDate: DateTime(2130),
      initialDateRange:
          debut != null && fin != null && !debut.isBefore(aujourdhui)
          ? DateTimeRange(start: debut, end: fin)
          : null,
      helpText: 'Période de livraison',
      saveText: 'Valider',
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kGreen,
            onPrimary: Colors.white,
            onSurface: kDarkText,
          ),
        ),
        child: child!,
      ),
    );
    if (plage == null) return;
    onModeChanged(ModePlanificationUI.periode);
    onPeriodeDebutChanged(plage.start);
    onPeriodeFinChanged(plage.end);
  }

  String get _summaryText {
    if (mode == ModePlanificationUI.dateExacte && dateExacte != null) {
      return 'Livraison prévue le ${_fmtDateTime(dateExacte!)}';
    }
    if (periodeDebut != null && periodeFin != null) {
      if (periodeDebut!.isAtSameMomentAs(periodeFin!)) {
        return 'Livraison prévue le ${_fmtDateTime(periodeDebut!)}';
      }
      return 'Livraison prévue du ${_fmtDateTime(periodeDebut!)} au ${_fmtDateTime(periodeFin!)}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            children: [
              const Text(
                "Date de Livraison de L'échantillon",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kOlive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _ModeTab(
                label: 'Date précise',
                icon: Icons.event_outlined,
                selected: mode == ModePlanificationUI.dateExacte,
                onTap: () => _choisirDateExacte(context),
              ),
              _ModeTab(
                label: 'Période estimée',
                icon: Icons.date_range_outlined,
                selected: mode == ModePlanificationUI.periode,
                onTap: () => _choisirPeriode(context),
              ),
            ],
          ),
        ),

        // Plus de cases « Date d'arrivage prévue » / « À partir du – Jusqu'au » :
        // toucher un des deux boutons ouvre directement le calendrier, et la
        // date choisie s'affiche ici (touchable pour la changer).
        const SizedBox(height: 10),
        if (_isFilled)
          Container(
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kGreen.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => mode == ModePlanificationUI.dateExacte
                        ? _choisirDateExacte(context)
                        : _choisirPeriode(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: kGreen,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _summaryText,
                              style: TextStyle(
                                fontSize: 11,
                                color: kGreen.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.edit_outlined,
                            color: kGreen,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (mode == ModePlanificationUI.dateExacte)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _TimeIconButton(
                      small: true,
                      hasTime: dateExacte!.hour != 0 || dateExacte!.minute != 0,
                      onTap: () async {
                        final dt = await _pickTime(
                          context,
                          dateBase: dateExacte!,
                        );
                        if (dt != null) onDateExacteChanged(dt);
                      },
                    ),
                  ),
              ],
            ),
          )
        else
          Text(
            'Touchez « Date précise » ou « Période estimée » pour choisir.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
      ],
    );
  }
}

Future<TimeOfDay?> _showScrollTimeSheet(
  BuildContext context, {
  TimeOfDay? initial,
}) async {
  int selectedHour = initial?.hourOfPeriod ?? 9;
  if (selectedHour == 0) selectedHour = 12;
  int selectedMinute = initial?.minute ?? 0;
  int selectedPeriod = (initial?.period == DayPeriod.pm) ? 1 : 0;

  const int hourRepeat = 200;
  const int minRepeat = 200;
  final hourCtrl = FixedExtentScrollController(
    initialItem: 12 * (hourRepeat ~/ 2) + (selectedHour - 1),
  );
  final minCtrl = FixedExtentScrollController(
    initialItem: 60 * (minRepeat ~/ 2) + selectedMinute,
  );
  final periodCtrl = FixedExtentScrollController(initialItem: selectedPeriod);

  final result = await showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.access_time_outlined, color: kGreen, size: 18),
                const SizedBox(width: 8),
                const Text(
                  "Heure d'arrivage (optionnel)",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kDarkText,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade500,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: const Text(
                    'Ignorer',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: kGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kGreen.withValues(alpha: 0.18)),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ListWheelScrollView.useDelegate(
                          controller: periodCtrl,
                          itemExtent: 44,
                          diameterRatio: 1.6,
                          perspective: 0.002,
                          overAndUnderCenterOpacity: 0.35,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (i) =>
                              setSheetState(() => selectedPeriod = i),
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 2,
                            builder: (_, i) => Center(
                              child: Text(
                                i == 0 ? 'AM' : 'PM',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: i == selectedPeriod
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: i == selectedPeriod
                                      ? kDarkText
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: ListWheelScrollView.useDelegate(
                          controller: hourCtrl,
                          itemExtent: 44,
                          diameterRatio: 1.6,
                          perspective: 0.002,
                          overAndUnderCenterOpacity: 0.35,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (i) =>
                              setSheetState(() => selectedHour = (i % 12) + 1),
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 12 * hourRepeat,
                            builder: (_, i) {
                              final h = (i % 12) + 1;
                              final sel = h == selectedHour;
                              return Center(
                                child: Text(
                                  h.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: sel
                                        ? kDarkText
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const Text(
                        ':',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: kDarkText,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: ListWheelScrollView.useDelegate(
                          controller: minCtrl,
                          itemExtent: 44,
                          diameterRatio: 1.6,
                          perspective: 0.002,
                          overAndUnderCenterOpacity: 0.35,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (i) =>
                              setSheetState(() => selectedMinute = i % 60),
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 60 * minRepeat,
                            builder: (_, i) {
                              final m = i % 60;
                              final sel = m == selectedMinute;
                              return Center(
                                child: Text(
                                  m.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: sel
                                        ? kDarkText
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  int hour24 = selectedHour % 12;
                  if (selectedPeriod == 1) hour24 += 12;
                  Navigator.pop(
                    ctx,
                    TimeOfDay(hour: hour24, minute: selectedMinute),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirmer',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  hourCtrl.dispose();
  minCtrl.dispose();
  periodCtrl.dispose();
  return result;
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? kGreen : Colors.grey.shade400,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? kGreen : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Small optional button (clock icon) that opens the time picker on demand,
/// once a date is already chosen. Replaces the old behaviour where the time
/// sheet popped up automatically after every date pick.
class _TimeIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasTime;
  final bool small;

  const _TimeIconButton({
    required this.onTap,
    this.hasTime = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 30.0 : 44.0;
    return Tooltip(
      message: hasTime ? "Modifier l'heure" : 'Préciser une heure (optionnel)',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasTime ? kGreen.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasTime
                  ? kGreen.withValues(alpha: 0.4)
                  : Colors.grey.shade200,
              width: hasTime ? 1.5 : 1.0,
            ),
          ),
          child: Icon(
            Icons.access_time_rounded,
            size: small ? 14 : 16,
            color: hasTime ? kGreen : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
