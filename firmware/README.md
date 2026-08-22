# Firmware ESP-NOW — Chaîne humidité du sol

```
ESP32 DevKit v1.1 + sonde capacitive v1.2          ESP32-C3 SuperMini (sur robot)
        (au champ, dans le sol)                    ──────────────────────────────
        ┌──────────────────────┐   ESP-NOW canal 1  ┌──────────────┐  UART 115200 ┌────────┐
        │ emetteur_devkit_v1   │ ──── diffusion ──> │ recepteur_c3 │ ── GPIO4/5 ─> │  Pi 2B │
        └──────────────────────┘    ~100-200 m      └──────────────┘   /serial0    └────────┘
                                     (champ libre)     LED clignote
                                                        a chaque trame
```

## 1. Câblage

### Émetteur — DevKit v1.1 + sonde capacitive v1.2

| Sonde v1.2 | DevKit v1.1 |
|---|---|
| VCC | **3V3** (⚠️ pas 5V) |
| GND | GND |
| AOUT | **GPIO 34** |

### Récepteur — C3 SuperMini vers Raspberry Pi

| C3 SuperMini | Raspberry Pi 2B |
|---|---|
| GPIO 5 (TX) | GPIO 15 (RXD) |
| GPIO 4 (RX) | GPIO 14 (TXD) — optionnel |
| GND | GND (**obligatoire**, masse commune) |
| 5V | 5V (alimente le C3 depuis le Pi) |

Puis sur le Pi : `sudo raspi-config` → Interfaces → Serial →
login shell série **NON**, port matériel **OUI** → le C3 parle sur `/dev/serial0`.

## 2. Calibration de la sonde (une seule fois)

1. Ouvrir le moniteur série de l'émetteur (115200) ;
2. Sonde **à l'air libre, sèche** → noter `brut` ≈ ex. 3200 → `BRUT_SEC` ;
3. Sonde **dans un verre d'eau** (les dents du capteur immergées, électronique
   hors de l'eau !) → noter `brut` ≈ ex. 1400 → `BRUT_HUMIDE` ;
4. Reportez ces deux valeurs en haut de `emetteur_devkit_v1.ino` et re-téléversez.

> Si l'humidité affichée est inversée (100 % sec), échangez les deux valeurs.

## 3. Téléversement (Arduino IDE)

- Installer le support de cartes **esp32 by Espressif Systems** (Gestionnaire de cartes) ;
- Émetteur : carte **ESP32 Dev Module** ;
- Récepteur : carte **ESP32C3 Dev Module** — si aucun port n'apparaît,
  mettre « USB CDC On Boot : *Enabled* » dans les options de carte ;
- Les deux ESP32 doivent rester sur le **canal 1** (réglé par le programme).

## 4. Test de bout en bout

1. Alimenter l'émetteur (power bank) à quelques mètres ;
2. Moniteur série du récepteur : une ligne `Recu de XX:... h=..%` toutes les 15 s,
   LED qui clignote ;
3. Sur le Pi : `cat /dev/serial0` → `{"h": 62.5,"brut": 1830}` ;
4. Le logiciel (`main.py --reel`) utilise automatiquement cette valeur.

## 5. Portée

100–200 m en champ libre. Si des trames manquent : rapprocher l'émetteur,
éviter les obstacles métalliques, ou ajouter une antenne externe sur le DevKit.
