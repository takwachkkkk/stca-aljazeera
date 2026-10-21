"""
Resultat du panel pour un echantillon — methode du fichier COI_CALC.xlsx du COI.

Pour chaque attribut, on prend les notes de tous les degustateurs qui ont
soumis leur evaluation, puis (formules de la feuille « Table ») :

    mediane        = MEDIAN
    moyenne        = AVERAGE
    ecart_type     = STDEV.S
    iqr            = PERCENTILE(0.75) - PERCENTILE(0.25)
    s_robuste (S*) = (1.25 / 1.35) * iqr / racine(n)
    cvr (%)        = S* / mediane * 100   — fiable si <= 20 %
    intervalle     = mediane +/- 1.96 * S*

La categorie de l'echantillon vient de la mediane du defaut le plus fort et de
la mediane du fruite, avec la meme regle que l'evaluation individuelle
(classification.calculer_classification_coi) : une seule regle dans le projet.
"""

import math

from . import classification as pr48

DEFAUTS = (
    ('chome', 'Chômé / lies'),
    ('moisi', 'Moisi / humidité'),
    ('vinaigre', 'Vineux / vinaigré'),
    ('gele', 'Gelé'),
    ('rance', 'Rance'),
    ('autres_defaut', 'Autre défaut'),
)
POSITIFS = (
    ('fruite', 'Fruité'),
    ('amertume', 'Amertume'),
    ('piquant', 'Piquant'),
)

#: Au-dela, le COI demande de refaire la degustation (feuille « Info », point 7).
CVR_MAX = 20.0


def mediane(valeurs):
    """MEDIAN d'Excel."""
    tri = sorted(valeurs)
    n = len(tri)
    if n == 0:
        return None
    milieu = n // 2
    return tri[milieu] if n % 2 else (tri[milieu - 1] + tri[milieu]) / 2


def percentile(valeurs, p):
    """PERCENTILE d'Excel (inclusif, interpolation lineaire)."""
    tri = sorted(valeurs)
    if not tri:
        return None
    rang = p * (len(tri) - 1)
    bas = math.floor(rang)
    haut = math.ceil(rang)
    return tri[bas] + (tri[haut] - tri[bas]) * (rang - bas)


def statistiques_attribut(valeurs):
    """Les lignes de la feuille « Table » pour une colonne de notes."""
    valeurs = [float(v) for v in valeurs]
    n = len(valeurs)
    if n == 0:
        return None
    med = mediane(valeurs)
    moyenne = sum(valeurs) / n
    ecart_type = (
        math.sqrt(sum((v - moyenne) ** 2 for v in valeurs) / (n - 1)) if n > 1 else None
    )
    iqr = percentile(valeurs, 0.75) - percentile(valeurs, 0.25)
    s_robuste = (1.25 / 1.35) * (iqr / math.sqrt(n))
    cvr = (s_robuste / med) * 100 if med else None
    return {
        'n': n,
        'mediane': round(med, 2),
        'moyenne': round(moyenne, 2),
        'ecart_type': round(ecart_type, 2) if ecart_type is not None else None,
        'iqr': round(iqr, 2),
        's_robuste': round(s_robuste, 3),
        'cvr': round(cvr, 1) if cvr is not None else None,
        'ic_bas': round(med - 1.96 * s_robuste, 2),
        'ic_haut': round(med + 1.96 * s_robuste, 2),
    }


def resultat_panel(evaluations):
    """
    Resultat du panel a partir des evaluations soumises d'UN echantillon.

    Une note absente compte 0 (« Missing values must be zeros », feuille Info) :
    un degustateur qui ne percoit pas un defaut ne le note pas.
    """
    evaluations = list(evaluations)
    if not evaluations:
        return None

    def notes(champ):
        return [float(getattr(ev, champ) or 0) for ev in evaluations]

    attributs = []
    for champ, libelle in DEFAUTS + POSITIFS:
        stats = statistiques_attribut(notes(champ))
        attributs.append({'champ': champ, 'libelle': libelle, 'positif': (champ, libelle) in POSITIFS, **stats})
    par_champ = {a['champ']: a for a in attributs}

    # Defaut principal = celui dont la mediane est la plus forte (MAX(D7:I7)).
    defaut_principal = max(
        (par_champ[champ] for champ, _ in DEFAUTS), key=lambda a: a['mediane'],
    )
    mediane_defaut = defaut_principal['mediane']
    mediane_fruite = par_champ['fruite']['mediane']
    categorie = pr48.calculer_classification_coi(mediane_defaut, mediane_fruite)

    # Fiabilite : le CVr% des attributs qui decident (defaut principal s'il
    # existe, fruite s'il existe) doit rester sous 20 %.
    decisifs = []
    if mediane_defaut > 0:
        decisifs.append(defaut_principal)
    if mediane_fruite > 0:
        decisifs.append(par_champ['fruite'])
    fiable = all(a['cvr'] is not None and a['cvr'] <= CVR_MAX for a in decisifs)

    types = {}
    for ev in evaluations:
        if ev.type_fruite:
            types[ev.type_fruite] = types.get(ev.type_fruite, 0) + 1
    type_majoritaire = max(types, key=types.get) if types else None

    return {
        'nombre_degustateurs': len(evaluations),
        'attributs': attributs,
        'defaut_principal': defaut_principal['libelle'] if mediane_defaut > 0 else None,
        'mediane_defaut_principal': mediane_defaut,
        'mediane_fruite': mediane_fruite,
        'classification': categorie,
        'fiable': fiable,
        'cvr_max': CVR_MAX,
        'type_fruite_majoritaire': type_majoritaire,
        'types_fruite': types,
    }
