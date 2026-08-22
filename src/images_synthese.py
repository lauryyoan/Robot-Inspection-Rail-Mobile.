# -*- coding: utf-8 -*-
"""images_synthese.py — Images de plantes synthetiques pour developper sans materiel."""

import numpy as np
import cv2

RNG = np.random.default_rng(7)


def fond_sol(h=480, w=640):
    """Sol terreux brun avec du grain et quelques cailloux."""
    img = np.full((h, w, 3), (72, 88, 118), np.uint8)
    bruit = RNG.normal(0, 12, (h, w, 1)).repeat(3, axis=2)
    img = np.clip(img.astype(np.float32) + bruit, 0, 255).astype(np.uint8)
    for _ in range(40):
        x, y = int(RNG.integers(0, w)), int(RNG.integers(0, h))
        cv2.circle(img, (x, y), int(RNG.integers(2, 6)), (60, 75, 100), -1)
    return img


def _feuille(img, centre, taille, angle, couleur_bgr, veinures=False):
    masque = np.zeros(img.shape[:2], np.uint8)
    cv2.ellipse(masque, centre, taille, angle, 0, 360, 255, -1)
    bruit = RNG.normal(0, 8, img.shape).astype(np.float32)
    couche = np.clip(np.array(couleur_bgr, np.float32) + bruit, 0, 255).astype(np.uint8)
    img[masque > 0] = couche[masque > 0]
    if veinures:
        c = (int(centre[0]), int(centre[1]))
        cv2.line(img, c, (c[0] + taille[0] // 2, c[1] + taille[1] // 2), (90, 120, 90), 1)
    return img


def plante_saine():
    img = fond_sol()
    for dx, dy, t, a in [(-70, 40, (38, 14), 25), (-30, 10, (44, 16), -15),
                         (10, -20, (46, 15), 10), (50, 15, (40, 14), -30),
                         (90, 45, (34, 13), 40), (20, 50, (36, 13), 70)]:
        _feuille(img, (320 + dx, 240 + dy), t, a, (45, 115, 55), veinures=True)
    return img


def plante_moyenne():
    img = fond_sol()
    for dx, dy, t, a, col in [(-70, 40, (36, 13), 30, (50, 125, 60)),
                              (-25, 10, (42, 15), -10, (55, 135, 70)),
                              (20, -15, (40, 14), 15, (60, 140, 80)),
                              (60, 30, (34, 12), -35, (65, 150, 90))]:
        _feuille(img, (320 + dx, 240 + dy), t, a, col, veinures=True)
    return img


def plante_stressee():
    img = fond_sol()
    for dx, dy, t, a, col in [
            (-70, 45, (30, 11), 55, (95, 165, 105)),
            (-30, 15, (34, 12), 10, (60, 160, 110)),
            (15, -15, (32, 11), -40, (70, 175, 120)),
            (55, 25, (26, 10), -60, (60, 185, 135)),
            (10, 55, (24, 9), 80, (75, 195, 145))]:
        _feuille(img, (320 + dx, 240 + dy), t, a, col, veinures=True)
    return img


def plante_aleatoire(etat):
    """etat : 'saine' | 'moyenne' | 'stressée' (ou 'stressee')."""
    return {"saine": plante_saine, "moyenne": plante_moyenne,
            "stressee": plante_stressee, "stressée": plante_stressee}[etat]()
