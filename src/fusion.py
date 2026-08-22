# -*- coding: utf-8 -*-
"""
fusion.py — Fusion multi-capteurs : score de stress hydrique (0 = sain, 1 = stress).

Version 1 (materiel actuel)  : ExG + jaunissement + texture + humidite du sol.
Version 2 (MLX90614 rachete) : ajouter dt_t = (T_foliaire - T_air).

Un capteur absent (None) est simplement ignore : les poids restants sont
re-normalises, donc le code ne change pas quand on ajoutera le MLX.
"""

import numpy as np

# Plages de normalisation empiriques (a recalibrer avec la base annotee lab)
PLAGES = {
    "exg": (0.10, 0.60),     # ExG moyen : 0.10 = tres degrade, 0.60 = tres vert
    "jaun": (0.0, 40.0),     # % jaunissement
    "texture": (50.0, 400.0),  # variance Laplacien (proxy fletrissement)
    "humidite": (10.0, 80.0),  # % humidite du sol
    "dt": (0.0, 6.0),        # T_foliaire - T_air en degres C
}

# Poids par defaut (somme quelconque, normalisee dans la fonction)
POIDS_DEFAUT = {
    "exg": 0.40,
    "jaun": 0.30,
    "texture": 0.15,
    "humidite": 0.15,
    "dt": 0.00,              # actif quand le MLX90614 sera branche
}


def _norm(v, cle):
    lo, hi = PLAGES[cle]
    return float(np.clip((v - lo) / (hi - lo), 0.0, 1.0))


def score_stress(exg_moyen, jaunissement_pct=None, texture=None,
                 humidite_sol_pct=None, dt_t=None, poids=None):
    """Score de stress hydrique pondere, entre 0 (sain) et 1 (tres stress).

    Parametres None = capteur absent -> terme ignore.
    Retourne (score, details) avec la contribution de chaque terme.
    """
    poids = poids or POIDS_DEFAUT
    termes, poids_actifs = {}, {}

    if exg_moyen is not None:
        termes["exg"] = 1.0 - _norm(exg_moyen, "exg")   # moins vert = plus stresse
        poids_actifs["exg"] = poids["exg"]
    if jaunissement_pct is not None:
        termes["jaun"] = _norm(jaunissement_pct, "jaun")
        poids_actifs["jaun"] = poids["jaun"]
    if texture is not None:
        termes["texture"] = _norm(texture, "texture")
        poids_actifs["texture"] = poids["texture"]
    if humidite_sol_pct is not None:
        termes["humidite"] = 1.0 - _norm(humidite_sol_pct, "humidite")  # sol sec = stress
        poids_actifs["humidite"] = poids["humidite"]
    if dt_t is not None:
        termes["dt"] = _norm(dt_t, "dt")                # feuille chaude = stress
        poids_actifs["dt"] = poids["dt"]

    if not termes:
        return None, {}

    total_poids = sum(poids_actifs.values())
    score = sum(termes[k] * poids_actifs[k] for k in termes) / total_poids
    details = {k: round(v, 3) for k, v in termes.items()}
    return round(float(score), 3), details


def niveau_stress(score):
    """Classe lisible pour la carte / les alertes."""
    if score is None:
        return "inconnu"
    if score < 0.25:
        return "sain"
    if score < 0.50:
        return "vigilance"
    if score < 0.75:
        return "stress_modere"
    return "stress_severe"
