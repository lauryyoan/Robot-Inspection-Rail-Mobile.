/*
 * =====================================================================
 *  RECEPTEUR ESP-NOW — ESP32-C3 SuperMini (installe sur le robot)
 *  Role : recoit les trames JSON diffusees et les transmet TELLES
 *         QUELLES au Raspberry Pi sur l'UART1 (aucun decodage ici :
 *         le Pi parse le JSON — moins de code, moins de bugs).
 *
 *  CABLAGE C3 SuperMini  ->  Raspberry Pi 2B :
 *      GPIO 5 (TX)  ----> GPIO 15 (RXD du Pi)
 *      GPIO 4 (RX)  ----> GPIO 14 (TXD du Pi)   [optionnel]
 *      GND          ----> GND                    (OBLIGATOIRE, commun !)
 *      5V           ----> 5V du Pi               (alimente le C3)
 *
 *  Cote Pi : sudo raspi-config -> Interfaces -> Serial
 *      -> login shell sur serie : NON  /  port serie materiel : OUI
 *      -> le C3 parle sur /dev/serial0 (115200 bauds)
 *
 *  Sortie vers le Pi (recopie de la trame recue) :
 *      {"id":"SOL-A","h":62.5,"brut":1830,"mac":"AA:BB:..."}
 *
 *  Compatibilite : ESP-NOW fonctionne entre ESP32 classique (DevKit,
 *  emetteur) et ESP32-C3 — les deux regles sur le canal 1.
 * =====================================================================
 */

#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>

#define LED     8     // LED integree du C3 SuperMini
#define CANAL   1     // meme canal que l'emetteur

// UART1 : GPIO4 = RX (recoit du Pi), GPIO5 = TX (envoie au Pi)
HardwareSerial SerialPi(1);

// Callback de reception — signature du core ESP32 v3.x
// (core 2.x : void a_la_reception(const uint8_t *mac, const uint8_t *data, int len)
//  — supprimer le parametre info et utiliser mac)
void a_la_reception(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
  if (len <= 1 || data[0] != '{') return;      // trame inattendue (non JSON)

  // Transmission telle quelle vers le Pi + fin de ligne
  SerialPi.write(data, len);
  SerialPi.write('\n');
  SerialPi.flush();

  // Acknowledge visuel + debug USB avec la source
  digitalWrite(LED, HIGH);
  Serial.printf("[%02X:%02X:%02X:%02X:%02X:%02X] %s\n",
                info->src_addr[0], info->src_addr[1], info->src_addr[2],
                info->src_addr[3], info->src_addr[4], info->src_addr[5],
                (const char *)data);
  delay(30);
  digitalWrite(LED, LOW);
}

void setup() {
  pinMode(LED, OUTPUT);
  digitalWrite(LED, LOW);

  Serial.begin(115200);                          // debug USB
  SerialPi.begin(115200, SERIAL_8N1, /*RX=*/4, /*TX=*/5);

  WiFi.mode(WIFI_STA);
  esp_wifi_set_channel(CANAL, WIFI_SECOND_CHAN_NONE);
  Serial.println("Recepteur ESP-NOW pret (canal 1, diffusion)");

  if (esp_now_init() != ESP_OK) {
    Serial.println("ERREUR esp_now_init");
    while (true) delay(1000);
  }
  esp_now_register_recv_cb(a_la_reception);
}

void loop() {
  delay(1000);   // tout le travail se fait dans le callback
}
