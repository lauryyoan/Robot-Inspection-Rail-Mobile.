# -*- coding: utf-8 -*-
"""
indicateurs.py — Indicateurs visuels du robot d'inspection (Sous-projet 2).

Chaîne : image BGR -> normalisation rgb -> carte ExG -> masque plante
(Otsu + morphologie) -> ExG moyen / couverture / jaunissement / texture.

Toutes les fonctions sont vectorisees NumPy : compatible Raspberry Pi 2B
(~0,3 a 1 s par image selon resolution).
"""

import cv2
import numpy as np

EPS = 1e-6
AIRE_MIN_PX = 150          # zones vegetales plus petites ignorees (bruit)


# ---------------------------------------------------------------- normalisation
def normaliser_rgb(bgr):
    """Convertit une image BGR uint8 en composantes chromatiques r,g,b.

    r,g,b valent entre 0 et 1 et ne dependent plus de l'eclairage.
    Retourne (r, g, b) : trois tableaux float32 de forme (H, W).
    """
    img = bgr.astype(np.float32)
    somme = img.sum(axis=2) + EPS          # (H, W)
    b = img[:, :, 0] / somme
    g = img[:, :, 1] / somme
    r = img[:, :, 2] / somme
    return r, g, b


# ---------------------------------------------------------------------- ExG
def carte_exg(bgr):
    """Carte ExG = 2*g - r - b, plage theorique [-1, +1]."""
    r, g, b = normaliser_rgb(bgr)
    return 2.0 * g - r - b


def exg_vers_u8(exg):
    """ExG [-1,1] -> uint8 [0,255] avec un mapping FIXE (comparable entre images)."""
    return np.clip((exg + 1.0) * 127.5, 0, 255).astype(np.uint8)


# ------------------------------------------------------------------ masque
def masque_plante(exg, seuil=None, nettoyer=True):
    """Segmente la vegetation a partir de la carte ExG.

    seuil : seuil ExG dans [-1, 1]. Si None -> seuil automatique d'Otsu.
    Retourne (masque uint8 0/255, seuil_utilise).
    """
    exg_u8 = exg_vers_u8(exg)

    if seuil is None:
        seuil_u8, brut = cv2.threshold(
            exg_u8, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        seuil = seuil_u8 / 127.5 - 1.0
    else:
        s = int(np.clip((seuil + 1.0) * 127.5, 0, 255))
        _, brut = cv2.threshold(exg_u8, s, 255, cv2.THRESH_BINARY)

    if not nettoyer:
        return brut, seuil

    # 1) morphologie : on enleve les points isoles et on bouche les trous
    noyau = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    brut = cv2.morphologyEx(brut, cv2.MORPH_OPEN, noyau)
    brut = cv2.morphologyEx(brut, cv2.MORPH_CLOSE, noyau)

    # 2) on ne garde que les zones assez grandes (feuilles, pas du bruit)
    n, etiquettes, stats, _ = cv2.connectedComponentsWithStats(brut, 8)
    masque = np.zeros_like(brut)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] >= AIRE_MIN_PX:
            masque[etiquettes == i] = 255
    return masque, float(seuil)


# ------------------------------------------------------------- indicateurs
def exg_moyen(exg, masque):
    """ExG moyen sur les pixels vegetation (None si aucune plante)."""
    sel = masque > 0
    if not sel.any():
        return None
    return float(exg[sel].mean())


def couverture_pct(masque):
    """% de pixels vegetation dans l'image."""
    return 100.0 * float((masque > 0).sum()) / masque.size


def jaunissement_pct(bgr, masque, h_min=15, h_max=38, s_min=40, v_min=40):
    """% de pixels vegetation classes 'jaunes' (chlorose).

    Methode HSV : le jaune pur vaut H=30 (echelle OpenCV 0-179) ; une
    feuille qui jaunit glisse du vert (H~50-70) vers le jaune (H~20-35).
    On ne compte QUE a l'interieur du masque plante.
    """
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    plante = masque > 0
    if not plante.any():
        return None
    h = hsv[:, :, 0][plante]
    s = hsv[:, :, 1][plante]
    v = hsv[:, :, 2][plante]
    jaunes = (h >= h_min) & (h <= h_max) & (s >= s_min) & (v >= v_min)
    return 100.0 * float(jaunes.sum()) / float(plante.sum())


def texture_laplacien(bgr, masque):
    """Variance du Laplacien dans la zone plante (proxy fletrissement).

    Une feuille ferme et lisse a un Laplacien homogene (variance faible) ;
    une feuille plissee/fanee presente plus de micro-contraste.
    Indicateur de TENDANCE : a comparer dans le temps pour une meme plante.
    """
    gris = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    lap = cv2.Laplacian(gris, cv2.CV_32F)
    plante = masque > 0
    if not plante.any():
        return None
    return float(lap[plante].var())


# ---------------------------------------------------------------- image complete
def indicateurs_image(bgr, seuil=None):
    """Calcule tous les indicateurs d'une image. Retourne un dict."""
    exg = carte_exg(bgr)
    masque, seuil_util = masque_plante(exg, seuil=seuil)
    return {
        "exg_moyen": exg_moyen(exg, masque),
        "couverture_pct": couverture_pct(masque),
        "jaunissement_pct": jaunissement_pct(bgr, masque),
        "texture_laplacien": texture_laplacien(bgr, masque),
        "seuil_otsu": seuil_util,
        "nb_pixels_plante": int((masque > 0).sum()),
    }, {"exg": exg, "masque": masque}


def images_debug(bgr, exg, masque):
    """Genere les visuels de controle (pour la base annotee / le rapport)."""
    exg_u8 = exg_vers_u8(exg)
    thermique = cv2.applyColorMap(exg_u8, cv2.COLORMAP_PLASMA)
    contour = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    contour = cv2.cvtColor(contour, cv2.COLOR_GRAY2BGR)
    ctr, _ = cv2.findContours(masque, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    cv2.drawContours(contour, ctr, -1, (0, 255, 255), 2)
    return {"carte_exg": thermique, "masque": masque, "contours": contour}
