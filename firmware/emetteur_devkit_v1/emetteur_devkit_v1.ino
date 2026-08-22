/*
 * =====================================================================
 *  EMETTEUR ESP-NOW — ESP32 DevKit v1.1 + sonde capacitive v1.2
 *  Role : au champ, mesure l'humidite du sol et DIFFUSE une trame JSON
 *         lisible par n'importe quel ESP32 sur le canal 1.
 *
 *  DIFFUSION (broadcast) : adresse FF:FF:FF:FF:FF:FF — pas d'appairage.
 *  Toute equipe avec un ESP32 (canal 1) recoit directement :
 *      {"id":"SOL-A","h":62.5,"brut":1830,"mac":"AA:BB:..."}
 *
 *  CABLAGE :
 *    Sonde v1.2   ESP32 DevKit v1.1
 *      VCC  -----> 3V3        (PAS 5V !)
 *      GND  -----> GND
 *      AOUT -----> GPIO 34    (entree ADC, input-only)
 *
 *  ALIMENTATION TERRAIN : power bank USB ou 18650 + TP4056.
 * =====================================================================
 */

#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>

#define PIN_SONDE    34     // AOUT de la sonde capacitive
#define CANAL        1      // canal commun a tous les recepteurs
#define PERIODE_S    15     // secondes entre deux envois
#define ID_CAPTEUR   "SOL-A"

// ---- CALIBRATION (a faire UNE fois, voir README du dossier firmware) ----
const int BRUT_SEC    = 3200;   // lecture sonde a l'air libre, seche
const int BRUT_HUMIDE = 1400;   // lecture sonde dans un verre d'eau

// Adresse de diffusion : tout le monde recoit, personne n'est appaire
uint8_t ADRESSE_DIFFUSION[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

char trame[180];   // la ligne JSON envoyee

float lire_brut() {
  // Moyenne de 10 lectures pour eliminer le bruit electrique
  float somme = 0;
  for (int i = 0; i < 10; i++) {
    somme += analogRead(PIN_SONDE);
    delay(100);
  }
  return somme / 10.0;
}

float brut_vers_humidite(float brut) {
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
  Serial.print("Emetteur pret (canal ");
  Serial.print(CANAL);
  Serial.print("). MAC = ");
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
}

void loop() {
  float brut = lire_brut();
  float h = brut_vers_humidite(brut);

  // Trame JSON OUVERTE : n'importe quel recepteur peut la lire directement
  snprintf(trame, sizeof(trame),
           "{\"id\":\"%s\",\"h\":%.1f,\"brut\":%.0f,\"mac\":\"%s\"}",
           ID_CAPTEUR, h, brut, WiFi.macAddress().c_str());

  esp_err_t resultat = esp_now_send(ADRESSE_DIFFUSION,
                                    (uint8_t *)trame, strlen(trame) + 1);
  Serial.printf("Diffusion : %s  [%s]\n", trame,
                resultat == ESP_OK ? "OK" : "ECHEC");
  delay(PERIODE_S * 1000UL);
}
