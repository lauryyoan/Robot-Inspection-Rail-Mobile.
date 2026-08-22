/*
 * =====================================================================
 *  EMETTEUR ESP-NOW — ESP32 DevKit v1.1 + sonde capacitive v1.2
 *  Role : au champ, mesure l'humidite du sol et l'envoie au robot
 *         toutes les 15 s (diffusion, pas d'appairage MAC).
 *
 *  CABLAGE :
 *    Sonde v1.2   ESP32 DevKit v1.1
 *      VCC  -----> 3V3        (PAS 5V !)
 *      GND  -----> GND
 *      AOUT -----> GPIO 34    (entree ADC, input-only)
 *
 *  ALIMENTATION SUR TERRAIN : power bank USB ou 18650 + module TP4056.
 *  (L'emetteur peut etre pose au pied de la rangee, a portee du robot.)
 * =====================================================================
 */

#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>

#define PIN_SONDE    34     // AOUT de la sonde capacitive
#define CANAL        1      // les DEUX ESP32 doivent etre sur ce canal
#define PERIODE_S    15     // secondes entre deux envois
#define MAGIC        0x534F4C31UL  // "SOL1" — anti-bruit

// ---- CALIBRATION (a faire UNE fois, voir README du dossier firmware) ----
const int BRUT_SEC    = 3200;   // lecture sonde a l'air libre, seche
const int BRUT_HUMIDE = 1400;   // lecture sonde dans un verre d'eau

// Adresse de diffusion : le recepteur n'a pas besoin d'etre appaire
uint8_t ADRESSE_DIFFUSION[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

// Trame binaire compacte (12 octets)
typedef struct __attribute__((packed)) {
  uint32_t magic;
  uint8_t  id_capteur;
  float    humidite;    // %
  float    brut;        // valeur ADC brute (debug/calibration)
} TrameSol;

TrameSol trame;

float lire_sonde() {
  // Moyenne de 10 lectures pour eliminer le bruit electrique
  float somme = 0;
  for (int i = 0; i < 10; i++) {
    somme += analogRead(PIN_SONDE);
    delay(100);
  }
  float brut = somme / 10.0;
  float h = 100.0 * (BRUT_SEC - brut) / (BRUT_SEC - BRUT_HUMIDE);
  if (h < 0) h = 0;
  if (h > 100) h = 100;
  return h;
}

void setup() {
  Serial.begin(115200);
  analogReadResolution(12);          // 0..4095 sur 0..3,3 V

  WiFi.mode(WIFI_STA);
  esp_wifi_set_channel(CANAL, WIFI_SECOND_CHAN_NONE);
  // Pour info : cette MAC doit correspondre a ce que voit le recepteur
  Serial.print("Emetteur pret. MAC = ");
  Serial.println(WiFi.macAddress());

  if (esp_now_init() != ESP_OK) {
    Serial.println("ERREUR esp_now_init — redemarrer.");
    while (true) delay(1000);
  }
  esp_now_peer_info_t destinataire = {};
  memcpy(destinataire.peer_addr, ADRESSE_DIFFUSION, 6);
  destinataire.channel = CANAL;
  destinataire.ifidx = WIFI_IF_STA;
  destinataire.encrypt = false;
  esp_now_add_peer(&destinataire);

  trame.magic = MAGIC;
  trame.id_capteur = 1;
}

void loop() {
  trame.brut = 0;
  float h = lire_sonde();
  trame.humidite = h;
  // On relit le brut pour l'envoyer (utile pour la calibration a distance)
  trame.brut = 0;
  for (int i = 0; i < 5; i++) trame.brut += analogRead(PIN_SONDE);
  trame.brut /= 5.0;

  esp_err_t resultat = esp_now_send(ADRESSE_DIFFUSION,
                                    (uint8_t *)&trame, sizeof(trame));
  Serial.printf("Envoi : humidite=%.1f%%  brut=%.0f  %s\n",
                trame.humidite, trame.brut,
                resultat == ESP_OK ? "OK" : "ECHEC");
  delay(PERIODE_S * 1000UL);
}
