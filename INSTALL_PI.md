# Installer le logiciel du robot sur le Raspberry Pi 2B

> Guide pour le Pi du projet (Raspberry Pi OS 32-bit, sans PC — tout se fait
> depuis le téléphone en SSH ou VNC).

## 1. Récupérer le code (une seule fois)

**Préalable** : fusionner la Pull Request sur GitHub (téléphone → github.com →
onglet *Pull requests* → *Merge pull request*). Sinon, cloner la branche de
travail (étape B).

**A. Cloner (recommandé — mises à jour faciles avec `git pull`) :**

```bash
cd ~
git clone https://github.com/lauryyoan/Robot-Inspection-Rail-Mobile..git
cd Robot-Inspection-Rail-Mobile.
```

**B. Si la PR n'est pas fusionnée**, ajouter `-b` avec la branche :

```bash
git clone -b arena/01a02a58-robot-inspection-rail-mobile \
    https://github.com/lauryyoan/Robot-Inspection-Rail-Mobile..git
```

**C. Sans git du tout** : sur le Pi, ouvrir Chromium → GitHub → bouton vert
*Code* → *Download ZIP* → `unzip Robot-Inspection-Rail-Mobile..-main.zip`
(moins pratique pour les mises à jour).

## 2. Installer les dépendances (une seule fois)

```bash
sudo apt update
sudo apt install -y git python3-opencv python3-numpy python3-matplotlib
```

> Ne PAS utiliser `pip install opencv-python` sur le Pi 2B : les paquets
> système (`apt`) sont plus légers et déjà compilés pour ARM.

## 3. Tester immédiatement (mode simulation, sans matériel)

```bash
python3 main.py --simulation
```

Attendu : 6 stations simulées, puis :

```
6 lignes ecrites -> sorties/campagne_20xxxxxx.csv
Carte generee     -> sorties/carte_20xxxxxx.png
```

La carte s'ouvre dans l'explorateur de fichiers du Pi (via VNC).

## 4. Mettre à jour (à chaque fois que le code évolue sur GitHub)

```bash
cd ~/Robot-Inspection-Rail-Mobile.
git pull
```

## 5. Aller plus loin (quand le matériel sera branché)

| Test | Commande |
|---|---|
| Caméra CSI (photo seule) | `rpicam-still -o test.jpg` |
| Flux ESP32-B sur le Pi | `cat /dev/serial0` (doit afficher `{"id":"SOL-A",...}`) |
| Campagne réelle complète | `python3 main.py --reel --stations 0.5,1.0,1.5,2.0` |
| Campagne avec images de debug | ajouter `--debug` |
