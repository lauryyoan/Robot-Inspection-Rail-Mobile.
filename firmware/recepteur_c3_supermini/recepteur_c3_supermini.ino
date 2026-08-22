/*
 * =====================================================================
 *  RECEPTEUR ESP-NOW — ESP32-C3 SuperMini (installe sur le robot)
 *  Role : recoit les trames humidite du champ et les imprime en JSON
 *         sur l'UART1 vers le Raspberry Pi.
 *
 *  CABLAGE C3 SuperMini  ->  Raspberry Pi 2B :
 *      GPIO 5 (TX)  ----> GPIO 15 (RXD du Pi)
 *      GPIO 4 (RX)  ----> GPIO 14 (TXD du Pi)   [optionnel, pour plus tard]
 *      GND          ----> GND                    (OBLIGATOIRE, commun !)
 *      5V           ----> 5V du Pi               (alimente le C3)
 *
 *  Cote Pi : sudo raspi-config -> Interfaces -> Serial
 *      -> login shell sur serie : NON  /  port serie materiel : OUI
 *      -> le C3 apparait sur /dev/serial0 (115200 bauds)
 *
 *  Sortie vers le Pi (une ligne JSON par trame recue) :
 *      {"h": 62.5, "brut": 1830}
 *
 *  Remarque : ESP-NOW est compatible entre ESP32 classique (DevKit)
 *  et ESP32-C3. Les deux sont regles sur le canal 1.
 * =====================================================================
 */

#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>

#define LED             8     // LED integree du C3 SuperMini
#define CANAL           1     // meme canal que l'emetteur
#define MAGIC           0x534F4C31UL

// UART1 : GPIO4 = RX (recoit du Pi), GPIO5 = TX (envoie au Pi)
HardwareSerial SerialPi(1);

typedef struct __attribute__((packed)) {
  uint32_t magic;
  uint8_t  id_capteur;
  float    humidite;
  float    brut;
} TrameSol;

// Callback de reception — signature du core ESP32 v3.x
// (avec un core 2.x, remplacer par :
//  void a_la_reception(const uint8_t *mac, const uint8_t *data, int len)
//  et supprimer le parametre info)
void a_la_reception(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
  if (len != sizeof(TrameSol)) return;          // trame inattendue
  TrameSol t;
  memcpy(&t, data, sizeof(t));
  if (t.magic != MAGIC) return;                 // bruit radio

  // Une ligne JSON, lue par CapteurHumiditeUART (src/materiel.py)
  SerialPi.printf("{\"h\":%.1f,\"brut\":%.0f}\n", t.humidite, t.brut);

  // Acknowledge visuel + debug sur le port USB
  digitalWrite(LED, HIGH);
  Serial.printf("Recu de %02X:%02X:%02X:%02X:%02X:%02X  h=%.1f%%  brut=%.0f\n",
                info->src_addr[0], info->src_addr[1], info->src_addr[2],
                info->src_addr[3], info->src_addr[4], info->src_addr[5],
                t.humidite, t.brut);
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
  Serial.println("Recepteur ESP-NOW pret (canal 1)");

  if (esp_now_init() != ESP_OK) {
    Serial.println("ERREUR esp_now_init");
    while (true) delay(1000);
  }
  esp_now_register_recv_cb(a_la_reception);
}

void loop() {
  delay(1000);   // tout le travail se fait dans le callback
}
