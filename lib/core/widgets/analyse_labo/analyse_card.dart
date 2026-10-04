import 'package:project3/core/widgets/details_echantillon.dart';
import 'package:flutter/material.dart';

import 'package:project3/core/analyses/ligne_analyse_labo.dart';
import 'package:project3/core/analyses/widgets/tableau_rapport_labo.dart';
import 'package:project3/core/utils/date_utils.dart';
import 'package:project3/core/widgets/grille_details.dart';
import 'package:project3/core/widgets/quantity_pill.dart';

const Color _dark = Color(0xFF1A2E1F);
const Color _green = Color(0xFF38835A);

Color _accentColor(StatutAnalyse statut) =>
    statut == StatutAnalyse.soumise ? _green : const Color(0xFFD07B2F);

class AnalyseCard extends StatefulWidget {
  final LigneAnalyseLabo analyse;
  final VoidCallback? onUrgentLabo;
  final bool isUrgentLabo;

  const AnalyseCard({
    super.key,
    required this.analyse,
    this.onUrgentLabo,
    this.isUrgentLabo = false,
  });

  @override
  State<AnalyseCard> createState() => _AnalyseCardState();
}

class _AnalyseCardState extends State<AnalyseCard> {
  bool _expanded = false;
  bool _rapportExpanded = false;

  @override
  Widget build(BuildContext context) {
    final analyse = widget.analyse;
    final accent = analyse.recuPhysiquement
        ? _accentColor(analyse.statut)
        : Colors.grey.shade500;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  analyse.referenceBouteille.isNotEmpty
                                      ? analyse.referenceBouteille
                                      : analyse.echantillonNom,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _dark,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (analyse.quantiteEstimee != null &&
                                  analyse.quantiteEstimee!.isNotEmpty) ...[
                                QuantityPill(
                                  quantite: analyse.quantiteEstimee!,
                                ),
                                const SizedBox(width: 6),
                              ],
                              AnimatedRotation(
                                turns: _expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 20,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  analyse.numero,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.onUrgentLabo != null) ...[
                                const SizedBox(width: 8),
                                _UrgentLaboBtn(
                                  isUrgent: widget.isUrgentLabo,
                                  // The lab only sees received samples.
                                  onTap:
                                      !analyse.recuPhysiquement ||
                                          widget.isUrgentLabo
                                      ? null
                                      : widget.onUrgentLabo,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _DetailPanel(
              analyse: analyse,
              rapportExpanded: _rapportExpanded,
              onRapportToggle: () =>
                  setState(() => _rapportExpanded = !_rapportExpanded),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _UrgentLaboBtn extends StatelessWidget {
  final bool isUrgent;
  final VoidCallback? onTap;

  const _UrgentLaboBtn({required this.isUrgent, this.onTap});

  static const urgent = Color(0xFFC62828);
  static const urgentBg = Color(0xFFFFEBEE);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isUrgent ? urgentBg : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isUrgent ? urgent : const Color(0xFFE0E0E0),
          width: 1.2,
        ),
      ),
      child: Icon(
        isUrgent ? Icons.notifications_active : Icons.notifications_outlined,
        size: 15,
        color: isUrgent ? urgent : Colors.grey.shade400,
      ),
    ),
  );
}

class _DetailPanel extends StatelessWidget {
  final LigneAnalyseLabo analyse;
  final bool rapportExpanded;
  final VoidCallback onRapportToggle;

  const _DetailPanel({
    required this.analyse,
    required this.rapportExpanded,
    required this.onRapportToggle,
  });

  @override
  Widget build(BuildContext context) {
    final rapport = analyse.rapport;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Colors.grey.shade100, height: 1),
        if (_aDesInformationsEchantillon)
          _InformationsEchantillon(analyse: analyse),
        if (rapport != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 13,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      children: [
                        const TextSpan(text: 'Analyse soumise par '),
                        TextSpan(
                          text: analyse.technicienNom,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                        if (rapport.dateAnalyse != null)
                          TextSpan(
                            text:
                                ' le ${DegDateUtils.formaterDateHeureOuTiret(rapport.dateAnalyse)}',
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        GestureDetector(
          onTap: rapport == null ? null : onRapportToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  Icons.biotech_outlined,
                  size: 13,
                  color: rapport == null ? Colors.grey.shade300 : _green,
                ),
                const SizedBox(width: 6),
                Text(
                  'Rapport',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: rapport == null ? Colors.grey.shade300 : _green,
                  ),
                ),
                const Spacer(),
                if (rapport?.dateAnalyse != null)
                  Text(
                    'Soumis le ${DegDateUtils.formaterDateHeureOuTiret(rapport!.dateAnalyse)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: rapportExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: rapport == null ? Colors.grey.shade300 : _green,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: rapport == null
              ? const _EnAttenteHint()
              : _RapportBody(analyse: analyse),
          crossFadeState: rapport == null || rapportExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  bool get _aDesInformationsEchantillon => true;
}

class _InformationsEchantillon extends StatelessWidget {
  final LigneAnalyseLabo analyse;

  const _InformationsEchantillon({required this.analyse});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAF8),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade100),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 12,
              color: Colors.grey.shade400,
            ),
            const SizedBox(width: 5),
            Text(
              "Informations de l'échantillon",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GrilleDetails(
          items: detailsEchantillon(
            numero: analyse.numero,
            referenceBouteille: analyse.referenceBouteille,
            fournisseur: analyse.fournisseurNom,
            variete: analyse.variete,
            gouvernorat: analyse.gouvernorat,
            delegation: analyse.delegation,
            collecteur: analyse.collecteurNom,
            numCiterne: analyse.numCiterne,
            dateAjout: analyse.dateAjout,
            recuPhysiquement: analyse.recuPhysiquement,
            dateArrivee: analyse.dateArriveeEchantillon,
            dateReception: analyse.dateReceptionEchantillon,
            dateLivraisonStock: analyse.dateLivraisonStock,
          ),
        ),
      ],
    ),
  );
}

class _RapportBody extends StatelessWidget {
  final LigneAnalyseLabo analyse;

  const _RapportBody({required this.analyse});

  @override
  Widget build(BuildContext context) {
    final rapport = analyse.rapport!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: BandeauClassification(
            classification: rapport.classificationAuto,
          ),
        ),
        if (rapport.horsNormes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: AlerteHorsNormes(parametres: rapport.horsNormes),
          ),
        TableauRapportLabo(rapport: rapport, groupeParTableau: true),
        if (rapport.notes != null && rapport.notes!.isNotEmpty)
          _NotesTechnicien(notes: rapport.notes!),
      ],
    );
  }
}

class _NotesTechnicien extends StatelessWidget {
  final String notes;

  const _NotesTechnicien({required this.notes});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAF8),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade100),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.notes_outlined, size: 13, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            notes,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ],
    ),
  );
}

class _EnAttenteHint extends StatelessWidget {
  const _EnAttenteHint();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.orange.shade100),
    ),
    child: Row(
      children: [
        Icon(
          Icons.hourglass_top_outlined,
          size: 13,
          color: Colors.orange.shade700,
        ),
        const SizedBox(width: 6),
        Text(
          'Analyse non encore soumise',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
        ),
      ],
    ),
  );
}
