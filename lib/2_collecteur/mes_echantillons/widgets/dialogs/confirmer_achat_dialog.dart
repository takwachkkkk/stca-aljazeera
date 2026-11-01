// ═════════════════════════════════════════════════════════════════════════════
// FILE : collecteur/mes_echantillons/widgets/dialogs/confirmer_achat_dialog.dart
//
// Dialog shown when the collector confirms (or modifies) a purchase.
// Fields: prix convenu, N° citerne, remarque, date de livraison du stock.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../models/echantillon_collecteur.dart';
import 'date_livraison_section.dart'
    show DateLivraisonSection, ModePlanificationUI;
import '../../../widgets/col_colors.dart';
import '../../../../core/utils/montant_achat.dart';
import '../../../../core/widgets/champ_prix_kg.dart';
import '../../../../core/widgets/saisie_protegee.dart';

String? _dateStockStr(EchantillonCollecteur e) {
  final d = e.dateStockSouhaiteeDebut;
  final f = e.dateStockSouhaiteeFin;
  if (d == null) return null;
  if (f != null && !f.isAtSameMomentAs(d)) {
    return '${fmtDate(d)} - ${fmtDate(f)}';
  }
  return fmtDate(d);
}

Future<void> showConfirmerAchatDialog({
  required BuildContext context,
  required EchantillonCollecteur echantillon,
  required void Function(AchatSaisi achat) onConfirm,
  String titre = "Confirmer l'achat",
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _ConfirmerAchatDialog(
          echantillon: echantillon,
          onConfirm: onConfirm,
          titre: titre,
        ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmerAchatDialog extends StatefulWidget {
  final EchantillonCollecteur echantillon;
  final void Function(AchatSaisi achat) onConfirm;
  final String titre;

  const _ConfirmerAchatDialog({
    required this.echantillon,
    required this.onConfirm,
    required this.titre,
  });

  @override
  State<_ConfirmerAchatDialog> createState() => _ConfirmerAchatDialogState();
}

class _ConfirmerAchatDialogState extends State<_ConfirmerAchatDialog> {
  late final TextEditingController _prixCtrl;
  late final TextEditingController _numCiterneCtrl;
  late final TextEditingController _remarqueCtrl;

  ModePlanificationUI _mode = ModePlanificationUI.dateExacte;
  DateTime? _dateExacte;
  DateTime? _periodeDebut;
  DateTime? _periodeFin;

  @override
  void initState() {
    super.initState();
    final e = widget.echantillon;
    _prixCtrl = TextEditingController(text: e.prixFinal ?? '');
    _numCiterneCtrl = TextEditingController(text: e.numCiterne ?? '');
    _remarqueCtrl = TextEditingController(text: e.remarqueCollecteur ?? '');
    // Pre-fill delivery date if already set
    if (e.livraison?.dateExacte != null) {
      _dateExacte = e.livraison!.dateExacte;
    }
  }

  @override
  void dispose() {
    _prixCtrl.dispose();
    _numCiterneCtrl.dispose();
    _remarqueCtrl.dispose();
    super.dispose();
  }

  AchatSaisi _achat(String prix) {
    final exacte = _mode == ModePlanificationUI.dateExacte;
    final numCiterne = _numCiterneCtrl.text.trim();
    return AchatSaisi(
      prixFinal: prix,
      remarqueCollecteur: _remarqueCtrl.text.trim(),
      numCiterne: numCiterne.isEmpty ? null : numCiterne,
      livraisonDebut: exacte ? _dateExacte : _periodeDebut,
      livraisonFin: exacte ? null : _periodeFin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.echantillon;
    return SaisieProtegee(
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFE9F4EE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.handshake_outlined,
                    color: colDark,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.titre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colDark,
                          ),
                        ),
                        Text(
                          e.referenceBouteille,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B8E7A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Direction offer reminder
                    if (e.budgetNegociation != null || _dateStockStr(e) != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3E8),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: const Color(
                              0xFFD07B2F,
                            ).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Offre de la direction',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD07B2F),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (e.budgetNegociation != null)
                              Text(
                                'Prix proposé : ${MontantAchat.formaterPrixParKg(e.budgetNegociation)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colDark,
                                ),
                              ),
                            if (e.budgetNegociation != null)
                              Text(
                                'Prix par tonne : ${MontantAchat.formaterPrixParTonne(e.budgetNegociation)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colDark,
                                ),
                              ),
                            if (_dateStockStr(e) != null)
                              Text(
                                'Date souhaitée : ${_dateStockStr(e)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colDark,
                                ),
                              ),
                          ],
                        ),
                      ),

                    // Prix final
                    const _DialogLabel('Prix convenu par kg *'),
                    const SizedBox(height: 6),
                    ChampPrixKg(
                      controller: _prixCtrl,
                      decoration: _inputDeco(
                        'ex: 8.750',
                        Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Numero de citerne
                    const _DialogLabel('N° citerne'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _numCiterneCtrl,
                      decoration: _inputDeco('ex: Z1', Icons.verified_outlined),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 14),

                    // Remarque facultative du collecteur
                    const _DialogLabel('Remarque du collecteur'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _remarqueCtrl,
                      minLines: 3,
                      maxLines: 5,
                      decoration: _inputDecoNoIcon(
                        'Ajoutez une remarque (facultatif)',
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 14),

                    // Date de livraison du stock
                    const _DialogLabel('Date de livraison du stock'),
                    const SizedBox(height: 8),
                    DateLivraisonSection(
                      showLabel: false,
                      mode: _mode,
                      onModeChanged: (m) => setState(() => _mode = m),
                      dateExacte: _dateExacte,
                      periodeDebut: _periodeDebut,
                      periodeFin: _periodeFin,
                      onDateExacteChanged: (dt) =>
                          setState(() => _dateExacte = dt),
                      onPeriodeDebutChanged: (dt) =>
                          setState(() => _periodeDebut = dt),
                      onPeriodeFinChanged: (dt) =>
                          setState(() => _periodeFin = dt),
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6EF),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final prix = _prixCtrl.text.trim();
                        if (prix.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Veuillez saisir le prix'),
                            ),
                          );
                          return;
                        }
                        final achat = _achat(prix);
                        Navigator.pop(context);
                        widget.onConfirm(achat);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Confirmer',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
}

// ─────────────────────────────────────────────────────────────────────────────
class _DialogLabel extends StatelessWidget {
  final String text;
  const _DialogLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF6B8E7A),
    ),
  );
}

InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
  prefixIcon: Icon(icon, size: 18, color: const Color(0xFF6B8E7A)),
  filled: true,
  fillColor: const Color(0xFFF7F9F8),
  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: Colors.grey.shade200),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: Colors.grey.shade200),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: colGreen, width: 1.5),
  ),
);

InputDecoration _inputDecoNoIcon(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
  filled: true,
  fillColor: const Color(0xFFF7F9F8),
  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: Colors.grey.shade200),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: Colors.grey.shade200),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: colGreen, width: 1.5),
  ),
);
