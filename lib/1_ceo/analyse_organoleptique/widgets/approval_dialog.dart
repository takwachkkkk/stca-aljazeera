import 'package:flutter/material.dart';
import 'package:project3/core/widgets/champ_prix_kg.dart';
import 'package:project3/core/widgets/saisie_protegee.dart';
import '../../../../2_collecteur/mes_echantillons/widgets/dialogs/date_livraison_section.dart'
    show DateLivraisonSection, ModePlanificationUI;

const Color _green = Color(0xFF38835A);
const Color _dark = Color(0xFF1A2E1F);

/// Approval / edit-negotiation dialog.
/// Handles its own form state (budget, date picker, note).
/// Calls [onApprove] with the collected values; the page owns the state mutation.
class ApprovalDialog extends StatefulWidget {
  final String reference;
  final bool isEdit;
  final String? initialBudget;
  final String? initialQuantite;
  final String? initialNote;
  final void Function(
    String budget,
    String? quantiteCibleT,
    String? dateSouhaitee,
    String? note,
  ) onApprove;

  const ApprovalDialog({
    super.key,
    required this.reference,
    required this.isEdit,
    this.initialBudget,
    this.initialQuantite,
    this.initialNote,
    required this.onApprove,
  });

  @override
  State<ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<ApprovalDialog> {
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _quantiteCtrl;
  late final TextEditingController _noteCtrl;
  ModePlanificationUI _dateMode = ModePlanificationUI.dateExacte;
  DateTime? _dateExacte;
  DateTime? _periodeDebut;
  DateTime? _periodeFin;

  @override
  void initState() {
    super.initState();
    _budgetCtrl = TextEditingController(text: widget.initialBudget ?? '');
    _quantiteCtrl = TextEditingController(text: widget.initialQuantite ?? '');
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _quantiteCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String? _buildDateSouhaitee() {
    if (_dateMode == ModePlanificationUI.dateExacte && _dateExacte != null) {
      final d = _dateExacte!;
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    if (_dateMode == ModePlanificationUI.periode &&
        _periodeDebut != null &&
        _periodeFin != null) {
      String fmt(DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      return _periodeDebut!.isAtSameMomentAs(_periodeFin!)
          ? fmt(_periodeDebut!)
          : '${fmt(_periodeDebut!)} - ${fmt(_periodeFin!)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SaisieProtegee(
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFE9F4EE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.handshake_outlined, color: _dark, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEdit ? 'Modifier la négociation' : 'Approuver pour négociation',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _dark),
                        ),
                        Text(widget.reference, style: const TextStyle(fontSize: 12, color: Color(0xFF6B8E7A))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Prix proposé par kg *'),
                    const SizedBox(height: 6),
                    ChampPrixKg(
                      controller: _budgetCtrl,
                      decoration: _deco('ex: 8.750', Icons.payments_outlined),
                      afficherPrixTonne: false,
                    ),
                    const SizedBox(height: 16),
                    // La quantite existait deja en base (quantite_cible_t) et
                    // l'API l'acceptait ; elle n'etait simplement pas saisissable
                    // ici, si bien que la direction negociait un prix sans dire
                    // sur combien de tonnes.
                    _label('Quantité souhaitée'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _quantiteCtrl,
                      decoration: _deco('ex: 28', Icons.scale_outlined)
                          .copyWith(suffixText: 'T'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    _label('Date souhaitée de livraison du stock'),
                    const SizedBox(height: 8),
                    DateLivraisonSection(
                      mode: _dateMode,
                      onModeChanged: (m) => setState(() => _dateMode = m),
                      dateExacte: _dateExacte,
                      periodeDebut: _periodeDebut,
                      periodeFin: _periodeFin,
                      onDateExacteChanged: (dt) => setState(() => _dateExacte = dt),
                      onPeriodeDebutChanged: (dt) => setState(() => _periodeDebut = dt),
                      onPeriodeFinChanged: (dt) => setState(() => _periodeFin = dt),
                    ),
                    const SizedBox(height: 16),
                    _label('Note interne (optionnelle)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _noteCtrl,
                      decoration: _deco('Remarques pour votre équipe…', Icons.notes_outlined),
                      maxLines: 2,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6EF),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final budget = _budgetCtrl.text.trim();
                        if (budget.isEmpty) return;
                        final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
                        final quantite = _quantiteCtrl.text.trim().isEmpty
                            ? null
                            : _quantiteCtrl.text.trim();
                        Navigator.pop(context);
                        widget.onApprove(budget, quantite, _buildDateSouhaitee(), note);
                      },
                      child: Text(
                        widget.isEdit ? 'Modifier' : 'Approuver',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  static Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B8E7A)),
  );

  static InputDecoration _deco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
    prefixIcon: Icon(icon, size: 18, color: const Color(0xFF6B8E7A)),
    filled: true,
    fillColor: const Color(0xFFF7F9F8),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: _green, width: 1.5),
    ),
  );
}
