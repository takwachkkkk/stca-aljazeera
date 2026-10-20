"""
Classification sensorielle — deux niveaux.

Niveau 1 : categorie reglementaire COI (extra vierge / vierge / vierge ordinaire / lampante).
Niveau 2 : classe interne PR-48, applicable uniquement aux huiles extra vierges (PR-48 SS6).

Ce module est le miroir Python de lib/core/classification/classification_interne.dart.
Le client calcule en direct pendant la saisie, le serveur revalide ce qu'il recoit.
Les deux implementations sont couvertes par le meme jeu de cas de test.
"""

# Echelles de saisie
MAX_POSITIF = 10.0  # fruite / amertume / piquant — saisie 0-10 ; seuils de classe PR-48 inchanges (ecrits pour 0-5)
MAX_DEFAUT = 10.0   # defauts — echelle COI, absente du PR-48
PAS_SLIDER = 0.1

# Categories COI
EXTRA_VIERGE = 'extra_vierge'
VIERGE = 'vierge'
VIERGE_ORDINAIRE = 'vierge_ordinaire'
LAMPANTE = 'lampante'

# Types de fruite (PR-48 SS8)
VERT = 'vert'
VERT_MUR = 'vert_mur'
MUR = 'mur'

# Classes internes (PR-48 SS8, plus SS9 pour extra_desequilibre)
EXTRA_A_PLUS = 'extra_a_plus'
EXTRA_A = 'extra_a'
EXTRA_B_PLUS = 'extra_b_plus'
EXTRA_B = 'extra_b'
EXTRA_B_MOINS = 'extra_b_moins'
EXTRA_C = 'extra_c'
EXTRA_DESEQUILIBRE = 'extra_desequilibre'

#: Classes que le PR-48 SS9 interdit a une huile au profil non harmonieux.
CLASSES_SOUMISES_A_HARMONIE = (EXTRA_A_PLUS, EXTRA_A)

#: Ordre d'affichage et de test de la grille — de la meilleure a la plus faible.
CLASSES_GRILLE = (
    EXTRA_A_PLUS,
    EXTRA_A,
    EXTRA_B_PLUS,
    EXTRA_B,
    EXTRA_B_MOINS,
    EXTRA_C,
)

#: Toutes les classes proposables a la main, extra_desequilibre incluse.
CLASSES_MANUELLES = CLASSES_GRILLE + (EXTRA_DESEQUILIBRE,)


def mediane_defauts(chome, moisi, vinaigre, rance, gele, autres_defaut):
    """Intensite du defaut dominant — le plus fort des six (methode COI)."""
    valeurs = [chome, moisi, vinaigre, rance, gele, autres_defaut]
    return max((float(v) for v in valeurs if v is not None), default=0.0)


def calculer_classification_coi(mediane, fruite):
    """
    Niveau 1 — categorie reglementaire COI/T.20/Doc. n 15/Rev. 11.

    Retourne None quand rien n'a encore ete saisi (aucun defaut ET aucun fruite) ;
    le formulaire affiche alors « En attente d'evaluation ». Ce comportement existait
    deja avant le PR-48 et n'est pas modifie.
    """
    mediane = float(mediane or 0.0)
    fruite = float(fruite or 0.0)

    if mediane == 0.0 and fruite == 0.0:
        return None
    if mediane == 0.0 and fruite > 0.0:
        return EXTRA_VIERGE
    if 0.0 < mediane <= 3.5 and fruite > 0.0:
        return VIERGE
    if mediane > 6.0:
        return LAMPANTE
    return VIERGE_ORDINAIRE


#: Grille du PR-48 SS8, lue de haut en bas — la premiere ligne qui correspond gagne.
#: Cet ordre est la regle de resolution des chevauchements (fruite pile 3, ou
#: fruite <= 2 tout plat) ; le document source ne la precise pas.
#: Chaque entree : (classe, predicat).
_GRILLE = (
    # Extra A+ : Fruite >=5 (vert) ; 3 < Amertume < 4.5 ; 3 <= piquant <= 5
    (EXTRA_A_PLUS, lambda f, t, a, p: (
        f >= 5 and t == VERT and 3 < a < 4.5 and 3 <= p <= 5
    )),
    # Extra A : 3.5 < Fruite < 4.5 (vert) ; 2.5 < Amertume < 4 ; 2.5 <= piquant <= 5
    (EXTRA_A, lambda f, t, a, p: (
        3.5 < f < 4.5 and t == VERT and 2.5 < a < 4 and 2.5 <= p <= 5
    )),
    # Extra B+ : 3 <= Fruite <= 3.5 (vert) ; 2.5 < Amertume < 3.5 ; 3 <= piquant <= 5
    (EXTRA_B_PLUS, lambda f, t, a, p: (
        3 <= f <= 3.5 and t == VERT and 2.5 < a < 3.5 and 3 <= p <= 5
    )),
    # Extra B : 2.5 <= Fruite <= 3 (vert ou vert-mure) ; 2.5 < Amertume < 3.5 ; 2 <= piquant <= 3.5
    (EXTRA_B, lambda f, t, a, p: (
        2.5 <= f <= 3 and t in (VERT, VERT_MUR) and 2.5 < a < 3.5 and 2 <= p <= 3.5
    )),
    # Extra B- : Fruite <= 2 (majoritairement mure) ; Amertume et piquant <= 2.5
    (EXTRA_B_MOINS, lambda f, t, a, p: (
        f <= 2 and t == MUR and a <= 2.5 and p <= 2.5
    )),
    # Extra C : Fruite <= 2 ; Amertume et piquant <= 2
    (EXTRA_C, lambda f, t, a, p: (
        f <= 2 and a <= 2 and p <= 2
    )),
)


def calculer_classe_interne(coi, fruite, type_fruite, amertume, piquant,
                            profil_non_harmonieux=False):
    """
    Niveau 2 — classe interne PR-48.

    Retourne None (« hors grille ») dans trois cas :
      - l'huile n'est pas extra vierge au sens COI (PR-48 SS6) ;
      - aucune ligne de la grille SS8 ne correspond ;
      - le profil est declare non harmonieux et la grille rendait une classe haute (SS9).

    Un None impose au degustateur de choisir la classe a la main.
    """
    if coi != EXTRA_VIERGE:
        return None

    f = float(fruite or 0.0)
    a = float(amertume or 0.0)
    p = float(piquant or 0.0)
    t = type_fruite or VERT

    for classe, correspond in _GRILLE:
        if correspond(f, t, a, p):
            if profil_non_harmonieux and classe in CLASSES_SOUMISES_A_HARMONIE:
                return None
            return classe
    return None


def classes_choisissables(profil_non_harmonieux=False):
    """Liste proposee au degustateur quand la classe est hors grille."""
    if profil_non_harmonieux:
        return tuple(c for c in CLASSES_MANUELLES
                     if c not in CLASSES_SOUMISES_A_HARMONIE)
    return CLASSES_MANUELLES
