# Firmware ESP-NOW — Chaîne humidité du sol

```
ESP32 DevKit v1.1 + sonde capacitive v1.2          ESP32-C3 SuperMini (sur robot)
        (au champ, dans le sol)                    ──────────────────────────────
        ┌──────────────────────┐   ESP-NOW canal 1  ┌──────────────┐  UART 115200 ┌────────┐
        │ emetteur_devkit_v1   │ ─── DIFFUSION ───> │ recepteur_c3 │ ── GPIO4/5 ─> │  Pi 2B │
        └──────────────────────┘   (broadcast)      └──────────────┘   /serial0    └────────┘
                                     ~100-200 m
                                     (champ libre)
```

## 0. Diffusion ouverte (broadcast)

L'émetteur envoie à l'adresse `FF:FF:FF:FF:FF:FF` : **tout ESP32 sur le canal 1
reçoit la trame**, sans appairage. La trame est du **JSON lisible** — les autres
équipes n'ont besoin d'aucune bibliothèque ni structure de notre part :

```json
{"id":"SOL-A","h":62.5,"brut":1830,"mac":"AA:BB:CC:DD:EE:FF"}
```

Un tiers peut recevoir avec n'importe quel ESP32 et ce mini-sketch :

```cpp
#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>
void a_la_reception(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
  if (data[0] == '{') Serial.println((const char *)data);   // core 2.x : signature sans info
}
void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);
  esp_now_init();
  esp_now_register_recv_cb(a_la_reception);
}
void loop() {}
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

## 3. Téléversement (Arduino IDE ou ArduinoDroid)

- Installer le support de cartes **esp32 by Espressif Systems** (Gestionnaire de cartes) ;
- Émetteur : carte **ESP32 Dev Module** ;
- Récepteur : carte **ESP32C3 Dev Module** — si aucun port n'apparaît,
  mettre « USB CDC On Boot : *Enabled* » dans les options de carte ;
- Les deux ESP32 doivent rester sur le **canal 1** (réglé par le programme) ;
- **ArduinoDroid** (téléphone) : si la compilation ESP32 échoue (support
  parfois limité selon la version), le sketch reste 100 % standard —
  un PC du labo avec Arduino IDE compilera à l'identique.

## 4. Test de bout en bout

1. Alimenter l'émetteur (power bank) à quelques mètres ;
2. Moniteur série du récepteur : une ligne `[MAC] {"id":...}` toutes les 15 s,
   LED qui clignote ;
3. Sur le Pi : `cat /dev/serial0` → `{"id":"SOL-A","h":62.5,...}` ;
4. Le logiciel (`main.py --reel`) utilise automatiquement le champ `h`.

## 5. Portée

100–200 m en champ libre. Si des trames manquent : rapprocher l'émetteur,
éviter les obstacles métalliques, ou ajouter une antenne externe sur le DevKit.
