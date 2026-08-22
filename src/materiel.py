# -*- coding: utf-8 -*-
"""
materiel.py — Couche materiel du robot.

Deux implementations de la MEME interface :
  - MaterielSimule : tout simule (developpement ici, sans robot)
  - MaterielReel   : Pi 2B + Uno (USB) + caméra CSI + ESP32-B (UART)

La boucle principale (main.py) ne sait pas laquelle tourne : le meme code
tourne en simulation sur un PC et en reel sur le Pi.
"""

import json
import random
import threading
import time

from images_synthese import plante_aleatoire

FRAICHEUR_HUMIDITE_S = 60   # une mesure d'humidite de plus de 60 s = perime


# =====================================================================
#  SIMULATION
# =====================================================================
class MaterielSimule:
    """Simule le cycle complet : deplacement, photo, humidite, temperature.

    Chaque station recoit un etat de plante tire au sort (corrélé a
    l'humidite du sol simulee) pour tester la fusion de bout en bout.
    """

    def __init__(self, graine=42):
        self._rng = random.Random(graine)
        self._etat_actuel = "moyenne"

    def deplacer_vers(self, x_m):
        """Le chariot va a la position x (en metres sur le rail)."""
        duree = min(2.0, 0.3 + abs(x_m) * 0.5)
        time.sleep(duree * 0.3)            # simulation acceleree
        self._etat_actuel = self._rng.choice(["saine", "moyenne", "stressee"])
        return True

    def photo(self):
        """Photo RGB de la plante a la station courante (image BGR)."""
        return plante_aleatoire(self._etat_actuel)

    def humidite_sol(self):
        """Derniere mesure ESP-NOW recue (en %). Correlee a l'etat simulé."""
        base = {"saine": 62.0, "moyenne": 40.0, "stressee": 18.0}[self._etat_actuel]
        return round(base + self._rng.uniform(-4.0, 4.0), 1)

    def temperature_foliaire(self):
        """None tant que le MLX90614 n'est pas remplace (fusion l'ignore)."""
        return None


# =====================================================================
#  MATERIEL REEL (Pi 2B)
# =====================================================================
class LiaisonUno:
    """Commande des moteurs via l'Arduino Uno (USB serie /dev/ttyACM0).

    Protocole : le Pi envoie 'GOTO <mm>' ; l'Uno repond 'OK' puis 'DONE'.
    """

    def __init__(self, port="/dev/ttyACM0", debit=115200):
        import serial                      # pyserial, seulement sur le robot
        self.serie = serial.Serial(port, debit, timeout=1)
        time.sleep(2)                      # reset de l'Uno au branchement USB

    def deplacer_vers(self, x_m):
        self.serie.reset_input_buffer()
        self.serie.write(f"GOTO {int(x_m * 1000)}\n".encode())
        debut = time.time()
        while time.time() - debut < 120:   # securite : 2 min max
            ligne = self.serie.readline().decode(errors="ignore").strip()
            if ligne == "DONE":
                return True
        return False


class CameraCSI:
    """Caméra Pi v1 (OV5647) via Picamera2 — réglages verrouillés.

    Verrouiller AWB et exposition est VITAL : sinon les couleurs changent
    entre deux photos et l'ExG devient incomparable.
    """

    def __init__(self, largeur=1640, hauteur=1232):
        from picamera2 import Picamera2
        import libcamera
        self.cam = Picamera2()
        cfg = self.cam.create_still_configuration(
            main={"size": (largeur, hauteur), "format": "RGB888"})
        self.cam.configure(cfg)
        try:  # réglages verrouillés si disponibles
            self.cam.set_controls({"AwbEnable": True, "AwbMode": libcamera.controls.AwbModeEnum.Auto})
        except Exception:
            pass
        self.cam.start()

    def photo(self):
        import cv2
        return cv2.cvtColor(self.cam.capture_array("main"), cv2.COLOR_RGB2BGR)


class CapteurHumiditeUART:
    """Lecture du flux JSON de l'ESP32-C3 (recepteur ESP-NOW) sur /dev/serial0.

    L'ESP32-B imprime une ligne JSON a chaque trame recue :
        {"h": 62.5, "brut": 1830}
    Un fil d'arriere-plan met a jour la derniere valeur ; humidite_sol()
    renvoie None si la mesure est trop vieille (capteur hors porte).
    """

    def __init__(self, port="/dev/serial0", debit=115200):
        import serial
        self.serie = serial.Serial(port, debit, timeout=2)
        self._verrou = threading.Lock()
        self._derniere = (0.0, None)       # (horodatage, humidite %)
        self._fil = threading.Thread(target=self._boucle, daemon=True)
        self._fil.start()

    def _boucle(self):
        while True:
            try:
                ligne = self.serie.readline().decode(errors="ignore").strip()
                if ligne.startswith("{"):
                    data = json.loads(ligne)
                    with self._verrou:
                        self._derniere = (time.time(), float(data["h"]))
            except Exception:
                time.sleep(1)

    def humidite_sol(self):
        with self._verrou:
            ts, val = self._derniere
        if val is None or (time.time() - ts) > FRAICHEUR_HUMIDITE_S:
            return None
        return val


class MaterielReel:
    """Assemble tout le materiel reel du robot."""

    def __init__(self, port_uno="/dev/ttyACM0", port_esp32="/dev/serial0"):
        self.uno = LiaisonUno(port_uno)
        self.cam = CameraCSI()
        self.hum = CapteurHumiditeUART(port_esp32)
        self._mlx = None                    # MLX90614 plus tard (I2C)

    def deplacer_vers(self, x_m):
        return self.uno.deplacer_vers(x_m)

    def photo(self):
        return self.cam.photo()

    def humidite_sol(self):
        return self.hum.humidite_sol()

    def temperature_foliaire(self):
        if self._mlx is None:
            return None                     # HS — la fusion ignore ce terme
        return self._mlx.temperature()
