# -*- coding: utf-8 -*-
"""
main.py — Boucle principale du robot (le comportement demande).

    Le robot part -> s'arrete a la station -> prend EN MEME TEMPS la photo
    + l'humidite + (la temperature, quand le MLX sera remplace) -> calcule
    les indicateurs -> stocke tout (CSV + images) -> repart a la station
    suivante -> ... -> a la fin, genere la carte lineaire d'etat hydrique.

Modes :
    --simulation   tout simule (PC, sans materiel)   [par defaut ici]
    --reel         sur le Pi 2B (Uno + caméra CSI + ESP32-B)

Exemples :
    python3 main.py --simulation
    python3 main.py --simulation --stations 0.5,1.0,1.5,2.0
    python3 main.py --reel --stations 0.5,1.0,1.5,2.0,2.5,3.0
"""

import argparse
import csv
import sys
import time
from datetime import datetime
from pathlib import Path

import cv2

sys.path.insert(0, str(Path(__file__).resolve().parent / "src"))

from indicateurs import indicateurs_image, images_debug          # noqa: E402
from fusion import score_stress, niveau_stress                   # noqa: E402
from carte import generer                                        # noqa: E402

COLONNES = ["horodatage", "position_x_m", "exg_moyen", "couverture_pct",
            "jaunissement_pct", "texture_laplacien", "humidite_sol_pct",
            "t_foliaire_c", "score_stress", "niveau", "image_ref"]


def campagne(materiel, stations, dir_sorties, garder_debug=False):
    """Execute la campagne : une station = un arret complet du robot."""
    dir_images = dir_sorties / "images"
    dir_images.mkdir(parents=True, exist_ok=True)
    lignes = []

    for i, x_m in enumerate(stations):
        print(f"\n--- Station {i + 1}/{len(stations)} : x = {x_m:.2f} m ---")

        # 1) DEPLACEMENT : le chariot va a la station et s'arrete
        if not materiel.deplacer_vers(x_m):
            print("  ! deplacement rate, station sautee")
            continue

        # 2) ACQUISITION SIMULTANEE (photo + capteurs dans la meme seconde)
        t0 = time.time()
        humidite = materiel.humidite_sol()
        image = materiel.photo()
        t_feuille = materiel.temperature_foliaire()      # None si MLX HS
        print(f"  acquisition simultanee en {time.time() - t0:.2f}s "
              f"(humidite sol = {humidite} %)")

        # 3) INDICATEURS + FUSION
        res, brut = indicateurs_image(image)
        score, details = score_stress(
            res["exg_moyen"], res["jaunissement_pct"],
            res["texture_laplacien"], humidite_sol_pct=humidite, dt_t=t_feuille)
        niveau = niveau_stress(score)
        print(f"  ExG={res['exg_moyen']:.3f}  jaun={res['jaunissement_pct']:.1f}%  "
              f"score={score} ({niveau})")

        # 4) STOCKAGE
        nom_img = f"station{i + 1:02d}_x{int(x_m * 100):03d}cm.jpg"
        cv2.imwrite(str(dir_images / nom_img), image)
        if garder_debug:
            dbg = images_debug(image, brut["exg"], brut["masque"])
            cv2.imwrite(str(dir_images / f"station{i + 1:02d}_exg.jpg"), dbg["carte_exg"])
            cv2.imwrite(str(dir_images / f"station{i + 1:02d}_contours.jpg"), dbg["contours"])

        lignes.append({
            "horodatage": datetime.now().isoformat(timespec="seconds"),
            "position_x_m": f"{x_m:.2f}",
            "exg_moyen": round(res["exg_moyen"], 3) if res["exg_moyen"] else None,
            "couverture_pct": round(res["couverture_pct"], 2),
            "jaunissement_pct": round(res["jaunissement_pct"], 2) if res["jaunissement_pct"] is not None else None,
            "texture_laplacien": round(res["texture_laplacien"], 1) if res["texture_laplacien"] else None,
            "humidite_sol_pct": humidite,
            "t_foliaire_c": t_feuille,
            "score_stress": score,
            "niveau": niveau,
            "image_ref": nom_img,
        })

    return lignes


def main():
    p = argparse.ArgumentParser(description="Campagne d'inspection du robot")
    p.add_argument("--simulation", action="store_true", default=False)
    p.add_argument("--reel", action="store_true", default=False)
    p.add_argument("--stations", default="0.5,1.0,1.5,2.0,2.5,3.0",
                   help="positions en metres, separees par des virgules")
    p.add_argument("--sorties", default="sorties")
    p.add_argument("--debug", action="store_true",
                   help="garder aussi les cartes ExG et contours")
    args = p.parse_args()

    reel = args.reel or (not args.simulation and Path("/dev/ttyACM0").exists())
    if reel and not args.reel:                       # detection auto sur le Pi
        print("Materiel detecte (/dev/ttyACM0) : mode REEL")
    if args.reel:
        from materiel import MaterielReel
        materiel = MaterielReel()
    else:
        from materiel import MaterielSimule
        materiel = MaterielSimule()
        print("Mode SIMULATION (aucun materiel requis)")

    stations = [float(s) for s in args.stations.split(",")]
    dir_sorties = Path(args.sorties)
    dir_sorties.mkdir(parents=True, exist_ok=True)

    print(f"Campagne : {len(stations)} stations -> {stations[-1]:.1f} m max\n")
    lignes = campagne(materiel, stations, dir_sorties, garder_debug=args.debug)

    # 5) CSV de campagne (la base de donnees du robot)
    horodatage = datetime.now().strftime("%Y%m%d_%H%M%S")
    chemin_csv = dir_sorties / f"campagne_{horodatage}.csv"
    with open(chemin_csv, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLONNES)
        w.writeheader()
        w.writerows(lignes)
    print(f"\n{len(lignes)} lignes ecrites -> {chemin_csv}")

    # 6) Carte lineaire d'etat hydrique (livrable du sujet)
    chemin_png = dir_sorties / f"carte_{horodatage}.png"
    try:
        generer(lignes, chemin_png)
        print(f"Carte generee     -> {chemin_png}")
    except Exception as e:
        print(f"Carte non generee : {e}")

    # Resume console
    scores = [l["score_stress"] for l in lignes if l["score_stress"] is not None]
    if scores:
        print(f"\nResume : score moyen {sum(scores) / len(scores):.2f} | "
              f"max {max(scores)} | min {min(scores)}")
        pires = sorted(lignes, key=lambda l: l["score_stress"] or 0, reverse=True)[:2]
        for l in pires:
            print(f"  -> vigilance a x = {l['position_x_m']} m "
                  f"(score {l['score_stress']}, {l['niveau']})")


if __name__ == "__main__":
    main()
