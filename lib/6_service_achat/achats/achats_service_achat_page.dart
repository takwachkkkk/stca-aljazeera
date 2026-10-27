// ═════════════════════════════════════════════════════════════════════════════
// FILE    : 6_service_achat/achats/achats_service_achat_page.dart
// PURPOSE : Page d'accueil du Service achat : les achats confirmés, la date de
//           livraison prévue de chaque stock et le détail du produit. Lecture
//           seule ; rien de la dégustation ni du laboratoire.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../1_ceo/widgets/base_sample_card.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/grille_details.dart';
import '../../core/widgets/statut_chip.dart';
import '../service_achat_drawer.dart';
import 'models/achat_service_achat.dart';
import 'services/achats_service_achat_service.dart';

class AchatsServiceAchatPage extends StatefulWidget {
  final AchatsServiceAchatService? service;

  const AchatsServiceAchatPage({super.key, this.service});

  @override
  State<AchatsServiceAchatPage> createState() => _AchatsServiceAchatPageState();
}

class _AchatsServiceAchatPageState extends State<AchatsServiceAchatPage> {
  late final AchatsServiceAchatService _service =
      widget.service ?? AchatsServiceAchatService();
  final _recherche = TextEditingController();

  List<AchatServiceAchat> _achats = const [];
  bool _chargement = true;
  bool _erreur = false;
  EtatLivraison? _filtre;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = _achats.isEmpty;
      _erreur = false;
    });
    try {
      final achats = await _service.fetchAchats();
      if (!mounted) return;
      setState(() {
        _achats = achats;
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erreur = true;
        _chargement = false;
      });
    }
  }

  List<AchatServiceAchat> get _filtres {
    final q = _recherche.text.trim().toLowerCase();
    final maintenant = DateTime.now();
    final liste = _achats.where((a) {
      final etatOk = _filtre == null || a.etatLivraison(maintenant) == _filtre;
      final rechercheOk =
          q.isEmpty ||
          [
            a.numero,
            a.referenceBouteille,
            a.fournisseurAffichage,
            a.gouvernorat,
            a.delegation ?? '',
            a.variete ?? '',
            a.collecteurNom ?? '',
          ].any((champ) => champ.toLowerCase().contains(q));
      return etatOk && rechercheOk;
    }).toList();
    // Les livraisons les plus proches d'abord ; sans date à la fin.
    liste.sort((a, b) {
      final da = a.dateLivraisonPrevue;
      final db = b.dateLivraisonPrevue;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return liste;
  }

  @override
  Widget build(BuildContext context) {
    final achats = _filtres;
    return Scaffold(
      backgroundColor: kBg,
      drawer: const ServiceAchatDrawer(),
      appBar: AppBar(
        backgroundColor: kHeaderBg,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 65,
        title: Text(
          'Achats confirmés',
          style: GoogleFonts.domine(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDark,
          ),
        ),
        iconTheme: const IconThemeData(color: kDark),
      ),
      body: Column(
        children: [
          _entete(),
          Container(height: 1, color: Colors.black.withValues(alpha: 0.06)),
          Container(
            color: kBg,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              _chargement
                  ? ''
                  : '${achats.length} achat${achats.length > 1 ? 's' : ''} confirmé${achats.length > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(child: _liste(achats)),
        ],
      ),
    );
  }

  Widget _entete() {
    Widget puce(
      String libelle,
      EtatLivraison? etat,
      Color actif,
      Color inactif,
    ) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: StatutChip(
        label: libelle,
        activeColor: actif,
        inactiveColor: inactif,
        inactiveTextColor: actif,
        selected: _filtre == etat,
        onTap: () => setState(() => _filtre = etat),
      ),
    );

    return Container(
      color: kHeaderBg,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _recherche,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Numéro, référence, fournisseur, gouvernorat…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                puce('Tous', null, kStatusGrey, kChipBgGrey),
                puce(
                  'Livraison à venir',
                  EtatLivraison.aVenir,
                  kStatusBlue,
                  kChipBgBlue,
                ),
                puce(
                  'En retard',
                  EtatLivraison.enRetard,
                  kStatusOrange,
                  kChipBgOrange,
                ),
                puce(
                  'Stock livré',
                  EtatLivraison.livre,
                  kStatusGreen,
                  kChipBgGreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _liste(List<AchatServiceAchat> achats) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator(color: kGreen));
    }
    if (_erreur) {
      return _vide(
        Icons.cloud_off_outlined,
        'Impossible de charger les achats. Vérifiez la connexion puis tirez '
        'vers le bas pour réessayer.',
      );
    }
    if (achats.isEmpty) {
      return _vide(
        Icons.inventory_2_outlined,
        _achats.isEmpty
            ? 'Aucun achat confirmé pour le moment.'
            : 'Aucun achat ne correspond à ce filtre.',
      );
    }
    final maintenant = DateTime.now();
    return RefreshIndicator(
      color: kGreen,
      onRefresh: _charger,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
        itemCount: achats.length,
        itemBuilder: (_, i) => _carte(achats[i], maintenant),
      ),
    );
  }

  Widget _vide(IconData icone, String texte) => RefreshIndicator(
    color: kGreen,
    onRefresh: _charger,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    texte,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _carte(AchatServiceAchat a, DateTime maintenant) {
    final etat = a.etatLivraison(maintenant);
    final (couleur, fond) = switch (etat) {
      EtatLivraison.aVenir => (kStatusBlue, kCardBgBlue),
      EtatLivraison.enRetard => (kStatusOrange, kCardBgOrange),
      EtatLivraison.livre => (kStatusGreen, kCardBgGreen),
      EtatLivraison.sansDate => (kStatusGrey, const Color(0xFFF4F4F4)),
    };
    String? quantite(double? t) => t == null
        ? null
        : '${t == t.roundToDouble() ? t.toStringAsFixed(0) : t.toStringAsFixed(2)} T';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BaseSampleCard(
        referenceBouteille: a.referenceBouteille,
        numero: a.numero,
        tintColor: Colors.white,
        accentColor: couleur,
        badge: CardBadgeRow(
          badges: [
            if (a.quantiteCibleT != null)
              CardBadge(label: quantite(a.quantiteCibleT)!, color: kOlive),
          ],
        ),
        detailItems: [
          DetailItem('N° échantillon', a.numero),
          DetailItem('Réf. bouteille', a.referenceBouteille),
          DetailItem('Fournisseur', a.fournisseurAffichage),
          DetailItem(
            'Gouvernorat',
            a.delegation == null
                ? a.gouvernorat
                : '${a.gouvernorat} — ${a.delegation}',
          ),
          if (a.variete != null) DetailItem('Variété', a.variete!),
          if (a.quantiteCibleT != null)
            DetailItem('Quantité achetée', quantite(a.quantiteCibleT)!),
          if (a.prix != null)
            DetailItem('Prix', '${a.prix!.toStringAsFixed(3)} TND/L'),
          if (a.numCiterne != null) DetailItem('N° citerne', a.numCiterne!),
          if (a.camionReserve != null)
            DetailItem('Camion réservé', a.camionReserve!),
          if (a.collecteurNom != null)
            DetailItem('Collecteur', a.collecteurNom!),
          if (a.remarqueCollecteur != null)
            DetailItem('Remarque du collecteur', a.remarqueCollecteur!),
        ],
        bottomSection: _livraison(a, etat, couleur, fond),
      ),
    );
  }

  /// La date de livraison est l'information principale de la carte.
  Widget _livraison(
    AchatServiceAchat a,
    EtatLivraison etat,
    Color couleur,
    Color fond,
  ) {
    final debut = a.dateLivraisonPrevue;
    final fin = a.dateLivraisonPrevueFin;
    String date(DateTime d) =>
        DegDateUtils.formaterAffichage(d.toIso8601String());

    final texte = switch (etat) {
      EtatLivraison.livre => 'Stock livré',
      EtatLivraison.sansDate => 'Date de livraison pas encore fixée',
      _ =>
        fin != null && debut != null && date(fin) != date(debut)
            ? 'Livraison prévue du ${date(debut)} au ${date(fin)}'
            : 'Livraison prévue le ${date(debut ?? fin!)}',
    };
    final precision = switch (etat) {
      EtatLivraison.enRetard => 'La date prévue est dépassée.',
      _ => null,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: couleur.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, color: couleur, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texte,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: couleur,
                  ),
                ),
                if (precision != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    precision,
                    style: TextStyle(fontSize: 11, color: couleur),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
