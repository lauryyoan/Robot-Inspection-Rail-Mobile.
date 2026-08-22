# -*- coding: utf-8 -*-
"""
demo_synthese.py — Test du pipeline complet SANS materiel.

Genere deux images synthetiques (plante saine / plante stresssee sur sol
malgache), leur applique la chaine : ExG -> Otsu -> indicateurs -> fusion,
puis sauvegarde les visuels de controle dans sorties/.

Usage : python3 scripts/demo_synthese.py
"""

import sys
from pathlib import Path

import cv2
import numpy as np

RACINE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RACINE / "src"))

from indicateurs import carte_exg, indicateurs_image, images_debug   # noqa: E402
from fusion import score_stress, niveau_stress                        # noqa: E402

SORTIES = RACINE / "sorties"
SORTIES.mkdir(exist_ok=True)
RNG = np.random.default_rng(42)


def fond_sol(h=480, w=640):
    """Sol terreux brun avec du grain."""
    img = np.full((h, w, 3), (72, 88, 118), np.uint8)   # brun terre en BGR
    bruit = RNG.normal(0, 12, (h, w, 1)).repeat(3, axis=2)
    img = np.clip(img.astype(np.float32) + bruit, 0, 255).astype(np.uint8)
    for _ in range(40):                                  # cailloux / mottes
        x, y = RNG.integers(0, w), RNG.integers(0, h)
        r = int(RNG.integers(2, 6))
        cv2.circle(img, (int(x), int(y)), r, (60, 75, 100), -1)
    return img


def feuille(img, centre, taille, angle, couleur_bgr, veinures=False):
    """Dessine une feuille (ellipse orientee) avec un peu de texture."""
    masque = np.zeros(img.shape[:2], np.uint8)
    cv2.ellipse(masque, centre, taille, angle, 0, 360, 255, -1)
    bruit = RNG.normal(0, 10, img.shape).astype(np.float32)
    couche = np.clip(np.array(couleur_bgr, np.float32) + bruit, 0, 255).astype(np.uint8)
    img[masque > 0] = couche[masque > 0]
    if veinures:                                         # nervures = texture
        c = (int(centre[0]), int(centre[1]))
        cv2.line(img, c, (c[0] + taille[0] // 2, c[1] + taille[1] // 2), (90, 120, 90), 1)
    return img


def plante_saine():
    img = fond_sol()
    # feuilles bien vertes, port ouvert
    for dx, dy, t, a in [(-70, 40, (38, 14), 25), (-30, 10, (44, 16), -15),
                         (10, -20, (46, 15), 10), (50, 15, (40, 14), -30),
                         (90, 45, (34, 13), 40), (20, 50, (36, 13), 70)]:
        feuille(img, (320 + dx, 240 + dy), t, a, (45, 115, 55), veinures=True)
    return img


def plante_stressee():
    img = fond_sol()
    # feuilles jaunissantes, recourbees (petites, textures marquees)
    for dx, dy, t, a, col in [
            (-70, 45, (30, 11), 55, (95, 165, 105)),
            (-30, 15, (34, 12), 10, (60, 160, 110)),
            (15, -15, (32, 11), -40, (70, 175, 120)),
            (55, 25, (26, 10), -60, (60, 185, 135)),
            (10, 55, (24, 9), 80, (75, 195, 145))]:
        feuille(img, (320 + dx, 240 + dy), t, a, col, veinures=True)
    return img


def analyser(nom, img, humidite_sol):
    print(f"\n=== {nom} ===")
    res, brut = indicateurs_image(img)
    for k, v in res.items():
        print(f"  {k:20s} : {v}")
    score, details = score_stress(
        res["exg_moyen"], res["jaunissement_pct"], res["texture_laplacien"],
        humidite_sol_pct=humidite_sol)
    print(f"  {'score_stress':20s} : {score}  ({niveau_stress(score)})")
    print(f"  contributions        : {details}")

    dbg = images_debug(img, brut["exg"], brut["masque"])
    cv2.imwrite(str(SORTIES / f"{nom}_source.jpg"), img)
    cv2.imwrite(str(SORTIES / f"{nom}_exg.jpg"), dbg["carte_exg"])
    cv2.imwrite(str(SORTIES / f"{nom}_contours.jpg"), dbg["contours"])
    return score


if __name__ == "__main__":
    s_saine = analyser("plante_saine", plante_saine(), humidite_sol=55.0)
    s_stressee = analyser("plante_stressee", plante_stressee(), humidite_sol=18.0)

    print("\n--- VERIFICATION ---")
    ok = s_stressee > s_saine
    print(f"plante saine score={s_saine} < plante stresssee score={s_stressee}"
          f" -> {'OK ✔' if ok else 'ECHEC ✘'}")
    sys.exit(0 if ok else 1)
