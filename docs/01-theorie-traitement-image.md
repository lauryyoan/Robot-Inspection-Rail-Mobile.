# Théorie du Traitement d'Image — Module 1 : Les Bases

> **Projet : Robot d'Inspection sur Rail Mobile (AgriTech)**
> Binôme : ANDRIAMANJARY Gervais Yoan Laurie & RAKOTOARISOA Jean Armel
> ESPA — École Supérieure Polytechnique d'Antsiranana

---

## 1. Pourquoi le traitement d'image dans notre projet ?

Notre robot circule sur un rail au-dessus d'une culture. Sa caméra RGB prend des
photos des plantes à intervalles réguliers. Mais **une photo brute ne dit rien
en elle-même** : c'est le traitement d'image qui transforme cette photo en
**indicateur mesurable** de la santé de la plante.

```
 PHOTO (des millions de pixels)  →  TRAITEMENT  →  DÉCISION
                                   (notre travail)   "plante stressée ?"
```

L'objectif final : détecter le **stress hydrique** (manque d'eau) le plus tôt
possible, avant même que ça soit visible à l'œil nu pour un humain.

---

## 2. Qu'est-ce qu'une image numérique ?

### 2.1 Le pixel

Une image numérique est une **grille de petits carrés appelés pixels**
(picture element). Chaque pixel porte une valeur numérique.

```
Zoom extrême sur une photo :

  ┌───┬───┬───┬───┐
  │ ■ │ ■ │ □ │ □ │   ■ = pixel sombre (valeur faible)
  ├───┼───┼───┼───┤   □ = pixel clair (valeur élevée)
  │ ■ │ □ │ □ │ □ │
  └───┴───┴───┴───┘
```

### 2.2 Résolution

La **résolution** = dimensions de la grille, en pixels.

Exemple : une photo de **1920 × 1080** contient 2 073 600 pixels (~2 MP).
Plus la résolution est haute, plus on voit de détails — mais plus le
traitement est lourd en calcul (important pour notre Raspberry Pi embarqué !).

### 2.3 Profondeur (niveaux)

Pour une image en **niveaux de gris** sur **8 bits**, chaque pixel vaut un
entier entre :

- **0** = noir complet
- **255** = blanc complet
- 256 valeurs possibles au total

### 2.4 L'image couleur RGB

Une image couleur = **3 grilles superposées** (3 canaux) :

| Canal | Lettre | Rôle |
|---|---|---|
| Rouge | **R** | intensité de lumière rouge |
| Vert | **G** | intensité de lumière verte |
| Bleu | **B** | intensité de lumière bleue |

Un pixel couleur est donc un triplet `(R, G, B)`, par exemple :

- Vert pur : `(0, 255, 0)`
- Vert "végétation" typique : `(58, 95, 32)` → c'est le **vert chlorophylle**
- Marron "sol sec" : `(139, 90, 43)`
- Gris "rail métallique" : `(128, 128, 128)`

**Point clé pour nous** : le canal **vert** domine dans la végétation. C'est
tout le secret de l'indice ExG que nous verrons plus loin.

> ⚠️ Convention OpenCV : les canaux sont stockés dans l'ordre **B, G, R** et non
> R, G, B. Source classique d'erreurs de débutant !

---

## 3. La normalisation chromatique (étape cruciale)

### 3.1 Le problème avec RGB brut

Les valeurs R, G, B dépendent de **l'éclairage** :

- Plein soleil → toutes les valeurs montent
- Nuage, ombre, fin de journée → toutes les valeurs descendent

Deux pixels de la **même plante** peuvent avoir des valeurs très différentes
selon l'heure de la journée. Un seuil fixe sur R, G, B bruts serait donc peu
fiable.

### 3.2 La solution : normaliser

On divise chaque canal par la **somme totale** pour obtenir des **composantes
chromatiques** (r, g, b) :

```
r = R / (R + G + B)
g = G / (R + G + B)
b = B / (R + G + B)
```

Propriétés obtenues :

- `r + g + b = 1` toujours
- chaque composante est entre 0 et 1
- les valeurs ne dépendent plus de l'intensité lumineuse, seulement de la
  **teinte** → robustesse à l'éclairage

**Exemple numérique** :

| Situation | Pixel (R,G,B) | r | g | b |
|---|---|---|---|---|
| Plein soleil | (116, 190, 64) | 0.31 | **0.51** | 0.17 |
| Nuage | (58, 95, 32) | 0.31 | **0.51** | 0.17 |

→ Même plante, luminosité différente, mais **les mêmes composantes normalisées**.
C'est exactement ce qu'il nous faut pour un robot qui travaille toute la journée
au champ !

---

## 4. L'indice de verdeur ExG (cœur de notre projet)

### 4.1 L'idée

La chlorophylle des feuilles absorbe le rouge et le bleu et **réfléchit le
vert**. Une plante en bonne santé est donc "très verte" ; une plante stressée
(manque d'eau) produit moins de chlorophylle et devient jaunissante / terne.

On cherche donc un nombre qui mesure **à quel point un pixel est vert**.

### 4.2 La formule (Woebbecke et al., 1995)

Sur les composantes normalisées :

```
ExG = 2·g − r − b
```

Interprétation : le vert (g) compte **double**, on lui soustrait le rouge et le
bleu.

| Type de surface | g vs r, b | ExG |
|---|---|---|
| Feuille saine (très verte) | g >> r, b | **fort** (≈ 0.5 à 0.8) |
| Feuille jaunissante (stressée) | g ≈ r | faible (≈ 0.1 à 0.2) |
| Sol / rail / fond | g ≤ r, b | proche de 0, voire négatif |

### 4.3 Exemple de calcul complet

Pixel d'une feuille saine : `(R,G,B) = (58, 95, 32)`

1. Somme : 58 + 95 + 32 = 185
2. Normalisation : r = 0.31, g = 0.51, b = 0.17
3. ExG = 2×0.51 − 0.31 − 0.17 = **0.54** → végétation saine ✔

Pixel de sol sec : `(R,G,B) = (139, 90, 43)`

1. Somme = 272
2. r = 0.51, g = 0.33, b = 0.16
3. ExG = 2×0.33 − 0.51 − 0.16 = **−0.01** → pas de la végétation ✘

### 4.4 Autres indices de couleur (pour la culture générale)

| Indice | Formule | Remarque |
|---|---|---|
| **ExG** | 2g − r − b | le plus utilisé, le nôtre |
| ExGR | ExG − 1.4·r − g | variante |
| CIVE | 0.441r − 0.811g + 0.385b + 18.78745 | pondéré statistiquement |
| VEG | g / (r^0.667 · b^0.333) | ratio |
| NDVI | (NIR − R) / (NIR + R) | nécessite un capteur **infrarouge** — pas possible avec notre simple caméra RGB, mais c'est la référence scientifique |

> 💡 Notre démarche ExG + température IR + humidité est une alternative
> économique au NDVI, parfaitement adaptée à un projet étudiant.

---

## 5. La segmentation : séparer la plante du fond

### 5.1 Principe

Calculer ExG pour chaque pixel nous donne une "carte de verdeur". Il faut
ensuite **décider**, pixel par pixel : végétation ou pas ?

```
Image RGB → ExG (par pixel) → Seuillage → Masque binaire (0 ou 255)
```

Le résultat est un **masque binaire** : blanc = plante détectée, noir = fond.

### 5.2 Le seuillage (thresholding)

- **Seuil fixe** : pixel végétation si `ExG > seuil` (ex. seuil = 0.25)
  - simple, rapide, mais le seuil idéal varie avec les conditions
- **Méthode d'Otsu** : le seuil est calculé **automatiquement** en analysant
  l'histogramme des valeurs ExG (il sépare les deux "bosses" : fond et plante)
  - plus robuste, recommandée pour nos tests au champ

### 5.3 Nettoyage du masque (morphologie mathématique)

Le masque brut contient du **bruit** : petits points isolés, trous dans les
feuilles. On applique des opérations morphologiques :

- **Érosion** : ronge les petits points isolés (bruit)
- **Dilatation** : regonfle les zones
- **Ouverture** (érosion puis dilatation) : supprime le bruit sans déformer
- **Fermeture** (dilatation puis érosion) : bouche les petits trous

### 5.4 Indicateurs qu'on peut en tirer

À partir du masque + de la carte ExG, notre robot pourra calculer :

| Indicateur | Signification |
|---|---|
| % de couverture végétale | surface de plante visible dans l'image |
| ExG moyen (sur les pixels plante) | **verdeur globale** → indicateur clé |
| histogramme des ExG | distribution, détection de zones hétérogènes |
| % de pixels "jaunis" (ExG faible) | signe précoce de stress |

---

## 6. Le lien avec le stress hydrique (physiologie)

Pourquoi ces mesures traduisent un manque d'eau :

1. **Manque d'eau → stomates fermés** (les pores des feuilles se ferment pour
   économiser l'eau) → **la transpiration diminue** → **la feuille chauffe**
   → notre capteur MLX90614 voit la température foliaire monter.
2. **Manque d'eau → moins de photosynthèse** → moins de chlorophylle →
   **la feuille devient moins verte** → **l'ExG baisse**.
3. La **température + humidité ambiante** donnent le contexte (une feuille chaude
   par forte chaleur n'est pas forcément stressée si l'air est humide).

D'où la **fusion des 3 capteurs** — c'est la force de notre projet :

```
   ExG (caméra RGB)  ──┐
   T° foliaire (IR)  ──┼──→  INDICE DE STRESS HYDRIQUE  →  alerte / cartographie
   Humidité air      ──┘
```

Aucun capteur seul ne suffit ; leur combinaison rend la détection fiable.

---

## 7. La chaîne de traitement complète du robot

Voici le **pipeline** que notre logiciel implémentera (sous-projet 2) :

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ 1. CAPTURE   │ → │ 2. PRÉTRAIT. │ → │ 3. ExG       │ → │ 4. SEUILLAGE │
│ caméra RGB   │   │ débruitage   │   │ normalisation│   │ Otsu + mor-  │
│ (Picamera2)  │   │ (flou léger) │   │ + ExG/pixel  │   │ phologie     │
└──────────────┘   └──────────────┘   └──────────────┘   └──────┬───────┘
                                                                ↓
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ 7. DÉCISION  │ ← │ 6. FUSION    │ ← │ 5. INDICATEURS│  │ Sauvegarde   │
│ stress ?     │   │ + T° IR      │   │ ExG moyen, % │   │ CSV/JSON +   │
│ alerte       │   │ + humidité   │   │ couverture   │   │ images masque│
└──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
```

Outils logiciels prévus : **Python 3**, **OpenCV** (`cv2`), **NumPy**, et
**Picamera2** pour la capture sur Raspberry Pi.

---

## 8. Résumé & vocabulaire à retenir

| Terme | Définition courte |
|---|---|
| Pixel | plus petit point d'une image, porte une valeur numérique |
| Canal | une des composantes couleur (R, G ou B) |
| Composantes chromatiques (r,g,b) | R,G,B divisés par leur somme → indépendants de la lumière |
| ExG | 2g − r − b : mesure la « verdeur » d'un pixel |
| Segmentation | séparer les objets d'intérêt (plantes) du fond |
| Seuillage / Otsu | classer chaque pixel selon un seuil (fixe ou auto-calculé) |
| Morphologie | nettoyage du masque (érosion, dilatation…) |
| Masque binaire | image noir/blanc : plante détectée ou non |
| Stress hydrique | manque d'eau de la plante → ExG ↓ et T° foliaire ↑ |

---

*Prochain module (2) : analyse du sujet officiel — indicateurs de jaunissement et
flétrissement, carte linéaire d'état hydrique, base d'images annotées.*
