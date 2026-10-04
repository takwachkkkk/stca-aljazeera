import 'package:flutter/material.dart';

import '../utils/date_utils.dart';
import 'grille_details.dart';

/// The one list of sample details shown on every sample card of the tasters
/// and the head taster (same fields, same order, same date format as the
/// "Gestion des échantillons" card). Empty optional fields are left out.
List<Widget> detailsEchantillon({
  required String? numero,
  required String referenceBouteille,
  String? fournisseur,
  String? variete,
  String? gouvernorat,
  String? delegation,
  String? collecteur,
  String? numCiterne,
  String? dateAjout,
  required bool recuPhysiquement,
  String? dateArrivee,
  String? dateReception,
  String? dateLivraisonStock,
}) {
  bool rempli(String? v) => v != null && v.trim().isNotEmpty;
  final zone = rempli(delegation)
      ? '${gouvernorat ?? ''} — $delegation'
      : (gouvernorat ?? '');

  return [
    if (rempli(numero)) DetailItem('N° échantillon', numero!),
    DetailItem('Réf. bouteille', referenceBouteille),
    if (rempli(fournisseur)) DetailItem('Fournisseur', fournisseur!),
    if (rempli(variete)) DetailItem('Variété', variete!),
    if (zone.trim().isNotEmpty) DetailItem('Gouvernorat', zone),
    if (rempli(collecteur)) DetailItem('Collecteur', collecteur!),
    if (rempli(numCiterne)) DetailItem('N° citerne', numCiterne!),
    DetailItem(
      'Enregistré le',
      DegDateUtils.formaterDateHeureOuTiret(dateAjout),
    ),
    DetailItem('Reçu physiquement', recuPhysiquement ? 'Oui' : 'Non'),
    DetailItem(
      'Arrivée prévue',
      DegDateUtils.formaterDateHeureOuTiret(dateArrivee),
    ),
    if (recuPhysiquement && rempli(dateReception))
      DetailItem('Reçu le', DegDateUtils.formaterDateHeureOuTiret(dateReception)),
    DetailItem(
      'Livraison du stock',
      DegDateUtils.formaterDateHeureOuTiret(dateLivraisonStock),
    ),
  ];
}
