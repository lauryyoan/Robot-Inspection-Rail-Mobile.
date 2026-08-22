# Architecture Matérielle Réelle — Module 3

> **Projet : Robot d'Inspection sur Rail Mobile (AgriTech) — Sujet 3, Binôme C**
> Ce document adapte l'architecture théorique (README) au **matériel réellement
> disponible**, avec ses contraintes et ses solutions.

---

## 1. Inventaire réel du matériel

| Matériel | Rôle dans le projet | Caractéristiques / contraintes |
|---|---|---|
| **Raspberry Pi 2B** | Cerveau (sous-projet 2) : traitement d'image, fusion, journalisation | 4×900 MHz ARMv7, 1 Go RAM. **Pas de WiFi intégré** (prévoir dongle USB ou câble Ethernet). Port caméra CSI ✔ |
| **Caméra Pi v1 5 MP** (OV5647) | Imagerie RGB des plantes | 2592×1944 px, FOV ≈ 54,8° × 41,6°, focus **réglable** (objectif vissé) |
| **Arduino Uno** | Commande moteurs (sous-projet 1) | 14 E/S numériques — suffisant pour 2 drivers pas-à-pas + fins de course |
| **2× ESP32** | Lien sans fil humidité du sol (ESP-NOW) | Émetteur au champ + récepteur sur le robot, portée 100–200 m en champ libre |
| **Sonde humidité du sol capacitive v1.2** | Mesure directe de l'eau disponible dans le sol | Sortie analogique, alimentation 3,3 V, résiste à la corrosion |
| **MLX90614** | Température foliaire IR | ⚠️ **HORS SERVICE** — rachat prévu plus tard. Le système doit fonctionner sans, dès maintenant |
| **PC** | — | ❌ Aucun. Développement via agent + GitHub, contrôle du Pi en SSH depuis le téléphone |

---

## 2. Architecture système révisée

```
                        AU CHAMP (dans le sol, poste fixe)
┌─────────────────────────────────────────────┐
│  ESP32-A  ←→  Sonde capacitive v1.2         │
│  (deep sleep, réveil périodique)            │
└──────────────────┬──────────────────────────┘
                   │  ESP-NOW (sans box, sans WiFi,
                   │  portée 100–200 m champ libre)
                   ↓
┌──────────────────────────────────────────────────────────────┐
│  ROBOT SUR RAIL                                              │
│                                                              │
│  ESP32-B (récepteur) ──UART 3,3 V──→ Raspberry Pi 2B         │
│                                        ├── Caméra v1 (CSI)   │
│                                        ├── (plus tard:       │
│                                        │   MLX90614 en I2C)  │
│                                        └── USB série ──→ Arduino Uno
│                                                           │  │
│                                        ┌── fin de course X ←┘  │
│                                        ├── fin de course Z     │
│                                        ├── Driver A4988 → Moteur X
│                                        └── Driver A4988 → Moteur Z
└──────────────────────────────────────────────────────────────┘
```

### Répartition des rôles

| Composant | Responsabilité | Pourquoi lui ? |
|---|---|---|
| **Pi 2B** | Capture image, ExG, jaunissement, texture, fusion, score de stress, CSV, carte linéaire | Linux + Python + OpenCV ; c'est le seul à savoir traiter des images |
| **Arduino Uno** | Pilotage temps réel des moteurs pas-à-pas (X, Z), fins de course | Génération d'impulsions précises — ne jamais faire ça depuis le Pi (Linux n'est pas temps réel) |
| **ESP32-A** | Mesure humidité du sol au pied des plantes, envoi ESP-NOW | WiFi intégré + très basse consommation (deep sleep) |
| **ESP32-B** | Réception ESP-NOW → transmission UART au Pi | Libère le Pi de la radio ; protocole simple |
| **MLX90614** (plus tard) | T° foliaire, branché en I2C sur le **Pi** | Le Pi est en 3,3 V comme le MLX (l'Uno est en 5 V → il faudrait un convertisseur de niveau) |

---

## 3. Le score de stress en deux versions (avec/sans MLX)

Pour ne pas bloquer, le code prévoira **des poids nuls pour les capteurs
absents** — ajouter le MLX plus tard se fera sans rien réécrire :

**Version 1 — aujourd'hui (sans T° foliaire) :**

```
score_stress(x) = w1·(1 − ExG_norm) + w2·Jaun%_norm + w3·Texture_norm
                + w4·(1 − humidité_sol_norm)
```

**Version 2 — quand le MLX90614 sera racheté :**

```
score_stress(x) = … + w5·ΔT_norm        avec ΔT = T_foliaire − T_air
```

> 💡 L'humidité du sol est même **plus directe** que la T° foliaire pour le
> stress hydrique : elle mesure la cause, pas le symptôme. Notre v1 est donc
> scientifiquement défendable en soutenance.

---

## 4. Raspberry Pi 2B — contraintes et plan d'installation

### 4.1 Ce qu'il faut savoir

- **Pas de WiFi/Bluetooth intégrés** (arrivés au Pi 3). Solutions :
  1. **Câble Ethernet** vers la box (le plus fiable, gratuit),
  2. **Dongle USB WiFi** (~10 000 Ar, à vérifier localement — prendre un modèle à puce RTL8188/8192 bien supporté).
- 1 Go de RAM et CPU modeste → **traitement ExG vectorisé NumPy** (pas de
  boucles pixel par pixel !). Ordre de grandeur : ~1 s par image 5 MP, ~0,3 s si
  on réduit à 1600 px de large. Suffisant : on photographie toutes les ~50 cm.

### 4.2 Installation logicielle (à faire une fois, avec un écran+clavier empruntés)

```bash
# 1. OS : Raspberry Pi OS Bookworm Lite 32-bit (flashé sur la micro-SD)
# 2. Activer la caméra, SSH, et l'UART (voir section ESP32-B)
sudo raspi-config          # → Interface: Camera ON, SSH ON, Serial: console OFF / hardware ON

# 3. Paquets (versions système, plus légères que pip sur Pi 2B)
sudo apt update
sudo apt install -y python3-opencv python3-numpy python3-matplotlib git

# 4. Vérifier la caméra v1 (OV5647)
rpicam-hello --list-cameras   # ou libcamera-hello selon la version
```

### 4.3 Workflow sans PC (le flux qu'on va suivre ensemble)

```
┌─────────────┐   push    ┌──────────┐  git pull  ┌──────────┐
│ Agent Arena │ ────────→ │  GitHub  │ ─────────→ │  Pi 2B   │
│ (je code +  │           │  dépôt   │            │ (exécute)│
│  teste ici) │           └──────────┘            └────┬─────┘
└─────────────┘                                     SSH
                                              ┌──────────────┐
                                              │ Votre tél.    │
                                              │ (Termux/Juice │
                                              │  SSH)         │
                                              └──────────────┘
```

1. Moi : je développe et **teste le code ici** (sandbox, avec images d'exemple) ;
2. Le code part sur **GitHub** (ce dépôt) ;
3. Sur le Pi (SSH depuis le téléphone, app **Termux** sur Android) :
   `git pull` puis `python3 pipeline.py`.

> 📱 Installation initiale : il faudra **une fois** un écran HDMI + clavier USB
> (empruntés, ~10 min) pour configurer SSH, WiFi et la caméra. Ensuite, tout se
> fait depuis le téléphone.

---

## 5. Caméra Pi v1 (OV5647) — ce qu'elle vaut pour nous

| Caractéristique | Valeur | Conséquence pour le projet |
|---|---|---|
| Résolution photo | 2592×1944 (5 MP) | largement suffisant |
| Champ de vision | ≈ 54,8° (H) × 41,6° (V) | permet le calcul de l'échelle |
| Focus | fixe mais **objectif vissé réglable** | 🔧 on ajustera la bague pour une netteté parfaite à la distance de travail (ex. 50 cm) |

### Calcul de l'échelle (lien avec « qualité contrôlée », module 2)

```
largeur_scène = 2 × distance × tan(FOV_H / 2) = 2 × d × tan(27,4°)
échelle (cm/px) = largeur_scène / largeur_image_px
```

| Distance caméra→plante (axe Z) | Largeur de scène vue | Échelle à 2592 px |
|---|---|---|
| 30 cm | 31 cm | ~0,12 cm/px |
| 50 cm | 52 cm | ~0,20 cm/px |
| 80 cm | 83 cm | ~0,32 cm/px |

→ L'axe Z du robot nous laisse **choisir la résolution spatiale** : près = détail
feuille par feuille ; loin = vue d'ensemble de la rangée.

---

## 6. Chaîne humidité du sol (ESP-NOW) — conception

### 6.1 Pourquoi ESP-NOW (et pas WiFi classique)

- **Pas de box, pas d'abonnement** : communication directe ESP32↔ESP32 ;
- portée 100–200 m en champ libre — la longueur de notre rangée ;
- très sobre en énergie (le nœud champ dort entre deux mesures).

### 6.2 Schéma fonctionnel

```
ESP32-A (champ)                      ESP32-B (robot)
─────────────────                    ─────────────────
deep sleep                           UART 115200 vers Pi
  ↓ réveil (toutes les 10 min)       reçoit trame ESP-NOW
lit sonde (moyenne de 10 mesures)    → écrit 1 ligne JSON sur le port série
  ↓
envoie {"id":"SOL-A","h":62.5}       → le Pi lit: {"id":"SOL-A","h":62.5}
  ↓
rendort
```

### 6.3 Sonde capacitive v1.2 — câblage et calibration

```
Sonde v1.2        ESP32-A
  VCC  ────────── 3V3        (⚠️ pas 5V : sortie plus propre sur 3,3 V)
  GND  ────────── GND
  AOUT ────────── GPIO 34    (entrée ADC1, OK en deep sleep)
```

**Calibration obligatoire en 2 points** (les valeurs brutes varient d'une sonde
à l'autre, et l'ADC de l'ESP32 est connu pour sa non-linéarité) :

```
1. Sonde à l'air libre, sèche    → noter BRUT_SEC      (ex. ~3200)
2. Sonde dans un verre d'eau     → noter BRUT_HUMIDE   (ex. ~1400)
3. humidité% = 100 × (BRUT_SEC − mesure) / (BRUT_SEC − BRUT_HUMIDE)
```

> Si les valeurs sont inversées avec votre version de sonde, on échange les deux
> repères — d'où l'importance de noter les bruts, pas des pourcentages devinés.

**Anti-bruit** : faire la **moyenne de 10 lectures** espacées de 100 ms à chaque
réveil, et alimenter la sonde proprement (le bruit de l'alimentation fausse les
capacitifs).

---

## 7. Arduino Uno — commande moteurs (sous-projet 1)

### 7.1 Budget de broches (2 moteurs, ça tient sur un Uno)

| Fonction | Broches Uno |
|---|---|
| Moteur X : STEP / DIR | D2 / D5 |
| Moteur Z : STEP / DIR | D3 / D6 |
| ENABLE commun aux drivers | D8 |
| Fins de course X (2) / Z (2) | D9, D10 / D11, D12 |
| USB série vers le Pi | (port série intégré) |

### 7.2 Protocole Pi → Uno (simple et robuste)

```
Le Pi envoie :      X+200\n     (avance X de 200 mm)
                    Z-30\n      (descend Z de 30 mm)
                    HOME\n      (retour origine, fins de course)
L'Uno répond :      OK\n        (commande reçue)
                    DONE\n      (mouvement terminé)
```

→ Le Pi décide **où** aller (il gère la logique de la campagne de mesures),
l'Uno garantit **comment** (tempo précis des pas, accélérations, sécurité fins
de course).

---

## 8. Liste de courses (motorisation + divers)

À valider selon votre budget — **ordres de grandeur à vérifier localement** :

| Article | Qté | Usage | Priorité |
|---|---|---|---|
| Moteur NEMA17 (~1,2–1,7 N·m, 12 V) | 2 | axes X et Z | 🔴 bloquant |
| Driver A4988 (+ radiateur) | 2 | pilotage des NEMA17 | 🔴 bloquant |
| Courroie GT2/T2.5 + poulies (axe X) | 2–4 m | translation chariot | 🔴 bloquant |
| Vis trapézoïdale T8 + écrou (axe Z) | 1 | bras vertical | 🔴 bloquant |
| Fins de course mécaniques | 4 | sécurité HOME X/Z | 🟠 important |
| Alimentation 12 V 3–5 A (labo) | 1 | moteurs (avant batterie) | 🔴 bloquant |
| Dongle USB WiFi (puce RTL8188) | 1 | SSH sans Ethernet | 🟠 important |
| MLX90614 | 1 | T° foliaire (version 2 du score) | 🟡 plus tard |
| Batterie LiPo 3S + BMS (terrain) | 1 | autonomie 2–4 h | 🟡 plus tard |

> 💡 Pour débuter, on peut valider **toute la chaîne logicielle** (modules 4–6)
> avec des photos de test, sans attendre la motorisation : le traitement
> d'image ne dépend pas du rail.

---

## 9. Conséquences sur les modules précédents

- Le score de stress (module 2) passe en **version 1 sans ΔT** → `w5 = 0`
  jusqu'au rachat du MLX ;
- la carte linéaire utilisera : ExG, jaunissement, texture, humidité du sol
  (celle-ci affichée en parallèle, car elle est mesurée **à un point fixe** du
  champ et non à chaque position x) ;
- la base annotée (module 2) gagne une colonne `humidite_sol_pct`.

---

*Prochain module (4) : **implémentation Python/OpenCV** — capture, normalisation,
ExG, segmentation Otsu, masque plante. Développé et testé ici, prêt à `git pull`
sur le Pi.*
