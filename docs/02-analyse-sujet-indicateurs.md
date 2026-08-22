# Analyse du Sujet & Indicateurs Avancés — Module 2

> **Projet : Robot d'Inspection sur Rail Mobile (AgriTech) — Sujet 3, Binôme C**
> Binôme : ANDRIAMANJARY Gervais Yoan Laurie & RAKOTOARISOA Jean Armel
> ESPA — École Supérieure Polytechnique d'Antsiranana

Ce module traduit **le sujet officiel** en spécifications techniques pour le
sous-projet 2 (Imagerie & Indicateurs). Il complète le module 1 (bases).

---

## 1. Ce que le sujet exige exactement (extraction des exigences)

| Exigence du sujet | Traduction technique |
|---|---|
| Caméra RGB | caméra Picamera2 sur Raspberry Pi, réglages verrouillés |
| Images de **qualité contrôlée** | contrôle netteté + exposition + distance constante (échelle px/cm connue) |
| Acquisition à **hauteur variable** | l'axe Z du robot règle la distance caméra→canopée |
| Indice de verdeur **ExG** | calculé par pixel après normalisation (cf. module 1) |
| Indicateur de **jaunissement** | % de pixels végétatifs classés « jaunes » (hue / b*) |
| Indicateur de **flétrissement** | métriques de texture + suivi temporel |
| Capteur humidité + thermo IR | fusion multi-capteurs (T° foliaire, humidité air) |
| **Carte linéaire d'état hydrique** | score de stress par position x le long du rail → graphe |
| Protocole **lab (stress contrôlé)** | plantes avec arrosage gradué, conditions reproductibles |
| Protocole **terrain (conditions réelles)** | robustesse à l'éclairage naturel (→ normalisation, Otsu) |
| **Base d'images annotées** lab + terrain | dossiers + CSV de métadonnées structuré |
| Guide reproductible | documentation du pipeline + paramètres |

---

## 2. Les trois indicateurs visuels exigés

### 2.1 Verdeur — ExG (déjà vu, module 1)

```
ExG = 2·g − r − b        avec r,g,b = R,G,B normalisés par (R+G+B)
```

Indicateur principal : **ExG moyen** sur les pixels végétation + **% de
couverture végétale**.

### 2.2 Jaunissement (nouveau)

**Principe physique** : une feuille qui jaunit perd sa chlorophylle. Le vert
(bleu+rouge absorbés) laisse place au jaune (rouge + vert réfléchis, bleu
faible). Un pixel « jaune » a donc **R et G élevés, B faible**.

Deux méthodes simples et fiables :

**Méthode A — Teinte HSV (recommandée)**

On convertit l'image RGB → HSV. La teinte (*hue*) du jaune pur est 60°
(soit H ≈ 20 à 40 dans l'échelle OpenCV 0–179, qui divise par 2).

```
jaune si :  20 ≤ H ≤ 40   et   S > seuil_bas   et   V > seuil_bas
```

**Méthode B — Canal b* de l'espace CIE L\*a\*b***

L'espace Lab sépare la luminosité (L*) des couleurs : **a* = axe vert↔rouge**,
**b* = axe bleu↔jaune**. Un pixel jaunissant a un **b* élevé**.

```
jaune si :  b* > seuil_jaune
```

**Indicateur final** :

```
Jaunissement % = 100 × (pixels jaunes) / (pixels végétation totaux)
```

> 💡 On calcule le jaunissement **uniquement à l'intérieur du masque plante**
> (module 1) — sinon le sol sec, qui est jaunâtre, fausserait tout !

### 2.3 Flétrissement (nouveau — le plus difficile)

**Principe physique** : une feuille flétrie se courbe, se plisse, perd son
brillant. Sa **texture** change et sa **surface projetée** diminue.

Aucun indicateur couleur ne le détecte → on passe à l'analyse de **texture** :

| Méthode | Mesure | Ce qu'elle révèle |
|---|---|---|
| Variance du Laplacien | netteté / micro-contraste local | feuille plissée = plus de micro-détails |
| GLCM (matrice de co-occurrence) | contraste, entropie, homogénéité | surface lisse ↔ surface ridée |
| Surface projetée | nb de pixels plante dans le masque | feuille qui se recourbe → surface vue ↓ |

**Stratégie réaliste pour notre projet** :

1. Calculer 2–3 métriques de texture simples (variance du Laplacien, entropie)
   sur la zone plante de chaque image ;
2. Les suivre **dans le temps** (même plante, jours après jours) : le
   flétrissement est avant tout une **évolution** ;
3. Stocker ces valeurs dans la base annotée pour corréler avec les mesures
   IR/humidité au moment du protocole lab.

> ⚠️ À ce stade du projet, le flétrissement sera un indicateur **tendance**
> (variation relative), pas une détection absolue. C'est honnête et défendable
> en soutenance.

---

## 3. La carte linéaire d'état hydrique le long de la rangée

C'est le **livrable signature** du projet : savoir où sont les plantes stressées
sur la rangée, pas seulement si elles le sont.

### 3.1 Principe

Pour **chaque position x** du chariot sur le rail, le robot acquiert une image +
T° IR + humidité, puis calcule un **score de stress normalisé (0 à 1)** :

```
score_stress(x) = w1·(1 − ExG_norm)  +  w2·Jaun%_norm  +  w3·Tex_norm
                + w4·ΔT_norm
```

avec :

- `ExG_norm` : ExG moyen normalisé sur [0,1] (bonne santé = 1)
- `Jaun%_norm` : % jaunissement normalisé
- `Tex_norm` : variation de texture (proxy flétrissement)
- `ΔT = T_foliaire − T_air` : une feuille stressée est **plus chaude que l'air**
  (stomates fermés → pas d'évaporative cooling)
- `w1…w4` : poids à calibrer pendant le protocole lab (on commence à poids
  égaux, on ajuste avec les données annotées)

> 📚 Notion scientifique de référence : le **CWSI** (Crop Water Stress Index)
> utilise précisément l'écart (T_canopée − T_air). Notre score est une version
> simplifiée multi-capteurs — bon argument pour la soutenance.

### 3.2 Format des données (une ligne par acquisition)

```csv
horodatage,position_x_m,hauteur_z_cm,exg_moyen,couverture_pct,jaunissement_pct,
texture_laplacien,t_foliaire_c,t_air_c,humidite_pct,score_stress,image_ref
2026-07-15T10:02:11,0.50,45,0.412,63.2,8.1,148.3,31.2,28.4,54,0.37,IMG_0007.jpg
2026-07-15T10:02:29,1.00,45,0.398,61.7,9.4,152.7,31.8,28.4,54,0.41,IMG_0008.jpg
```

### 3.3 Rendu final

Un simple graphe matplotlib : **position sur le rail (axe x) ↔ score de stress
(axe y)**, une couleur par niveau (vert = sain → rouge = stressé). C'est cette
figure qui ira dans le rapport et la soutenance.

---

## 4. Qualité contrôlée des images (exigence explicite du sujet)

« Acquérir des images de **qualité contrôlée** à **hauteur variable** » signifie :

### 4.1 Échelle constante grâce à l'axe Z

À distance fixe `d`, l'échelle (px/cm) est constante :

```
échelle = (largeur réelle du champ de vision) / (largeur image en pixels)
largeur du champ ≈ d × FOV_horizontal
```

→ en réglant Z, on garantit que **1 pixel représente toujours la même surface
réelle de feuille**, indispensable pour comparer les plantes entre elles et
mesurer la surface projetée (flétrissement).

### 4.2 Contrôles automatiques à la prise de vue

| Contrôle | Méthode | Action si échec |
|---|---|---|
| Netteté | variance du Laplacien > seuil | reprendre la photo |
| Exposition | % pixels saturés (≈255 ou ≈0) < limite | ajuster exposition |
| Réglages verrouillés | exposition + balance des blancs **fixes** (Picamera2) | — |

Verrouiller la balance des blancs est vital : sinon la caméra « corrige » les
couleurs à sa manière et l'ExG devient incomparable d'une photo à l'autre.

---

## 5. La base d'images annotées (lab + terrain)

### 5.1 Structure de dossiers proposée

```
base_images/
├── lab/
│   ├── 2026-07-15/           # une campagne = un dossier daté
│   │   ├── P01_x050_z45.jpg
│   │   ├── P01_x050_z30.jpg  # hauteur variable → z dans le nom
│   │   └── ...
│   └── 2026-07-22/
├── terrain/
│   └── 2026-08-05/
└── annotations.csv           # un seul fichier central de vérité terrain
```

**Convention de nommage** : `P{plante}_{x position dm}_{z hauteur cm}.jpg`

### 5.2 Le fichier annotations.csv (vérité terrain)

```csv
image,contexte,date,plante_id,position_x_m,hauteur_z_cm,niveau_arrosage_ml,
stresse_obsserve,notes
P01_x050_z45.jpg,lab,2026-07-15,P01,0.5,45,200,non,témooin bien arrosé
P04_x200_z45.jpg,lab,2026-07-15,P04,2.0,45,50,oui,feuilles basses molles
```

C'est **ce fichier qui rend la base « annotée »** : chaque image est reliée à
l'arrosage reçu et à l'observation humaine. C'est lui qui permettra de calibrer
les poids `w1…w4` du score de stress et de valider les indicateurs.

### 5.3 Protocole lab (stress contrôlé) — principe

Plusieurs plantes identiques, arrosage gradué (ex. 100 % / 75 % / 50 % / 25 % des
besoins), acquisition quotidienne à heure fixe → on **sait** quelles plantes
sont stressées → on **valide** que nos indicateurs le détectent. Ensuite
seulement, on part au terrain où la vérité est inconnue.

---

## 6. Feuille de route logicielle (sous-projet 2)

| Module | Contenu | Statut |
|---|---|---|
| 1 | Théorie : bases du traitement d'image | ✅ fait |
| 2 | Analyse du sujet, indicateurs avancés, spécifications | ✅ ce document |
| 3 | **Code : capture + calcul ExG + segmentation** (Python/OpenCV) | ⏳ prochain |
| 4 | Code : jaunissement (HSV/Lab) + texture (flétrissement) | ⏳ |
| 5 | Code : fusion capteurs + score de stress + carte linéaire + CSV | ⏳ |
| 6 | Intégration Raspberry Pi (Picamera2, MLX90614, DHT) + protocoles lab/terrain | ⏳ |

---

## 7. À retenir de ce module

1. Le sujet exige **trois** indicateurs visuels : ExG ✔ simple, jaunissement ✔
   faisable (hue HSV ou b*), flétrissement ⚠ approche par texture + temps.
2. La **carte linéaire** = score de stress par position x → c'est la fusion de
   TOUS les capteurs du robot, pas seulement de la caméra.
3. « Qualité contrôlée » = réglages caméra verrouillés + échelle connue grâce à
   l'axe Z + contrôles netteté/exposition automatiques.
4. La **base annotée** (images + CSV vérité terrain) est un livrable exigé : à
   concevoir AVANT les premières campagnes, pas après.

---

*Prochain module (3) : architecture matérielle réelle — inventaire, câblage
ESP-NOW/Uno/Pi 2B, calibration de la sonde, liste de courses.*
