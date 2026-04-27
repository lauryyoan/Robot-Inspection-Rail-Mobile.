Robot d'Inspection sur Rail Mobile (AgriTech)
​
Présentation du Projet

​Ce projet consiste à concevoir et réaliser un prototype fonctionnel de robot mobile circulant sur un rail, dédié à l'agriculture de précision. L'objectif principal est la détection précoce du stress hydrique des cultures via l'acquisition et le traitement de données multi-capteurs.
​Le système est conçu pour être démontable, transportable et capable de fonctionner aussi bien en laboratoire qu'en plein champ. Il permet de surveiller l'état de santé des plantes sans intervention humaine constante.


Architecture Technique
​Le projet est divisé en deux sous-systèmes interdépendants qui communiquent par liaison série:

​Sous-projet 1 : Mécanique & Commande

​Structure : Rail de guidage et chariot mobile.

​Motorisation : Système de déplacement sur deux axes (Axe X pour la translation, Axe Z pour le positionnement vertical des capteurs).

​Contrôle : Pilotage des moteurs pas-à-pas via microcontrôleur.

​Énergie : Système embarqué avec gestion de l'autonomie pour les tests au champ.


​Sous-projet 2 : Imagerie & Indicateurs

​Unité de traitement : Calculateur embarqué pour la gestion des capteurs.

​Capteurs : Imagerie RGB pour le calcul de l'indice de verdeur (ExG), thermométrie infrarouge pour la température foliaire et mesure de l'humidité environnementale.


Planning Prévisionnel (Mai - Septembre 2026)

​Mai : Phase de Conception & Études (4 semaines)

​Rédaction finale du cahier des charges.

​Choix des alternatives économiques (PVC, matériaux de récupération).

​Schémas électriques définitifs (Arduino Mega / Raspberry Pi).

​Juin : Approvisionnement & Assemblage (4 semaines)

​Achat des composants électroniques.

​Construction de la structure du rail et du chariot mobile.

​Montage des moteurs pas-à-pas et du bras vertical (Axe Z).

​Juillet : Développement Logiciel (4 semaines)

​Programmation de la commande moteur (G-Code/Arduino).

​Scripts Python pour la capture image et les capteurs (MLX90614).

​Tests de communication entre les deux unités.

​Août : Intégration & Tests unitaires (4 semaines)

​Assemblage final du robot sur le rail.

​Premiers tests de détection du stress hydrique en conditions contrôlées.

​Optimisation de l'autonomie énergétique.

​Septembre : Validation & Rapport Final (3 semaines)
​Campagnes de mesures réelles.

​Analyse des résultats et rédaction du rapport de projet.
​Soutenance finale.
​

Équipe du Projet (Binôme)
​Ce projet est réalisé par :
​ANDRIAMANJARY Gervais Yoan Laurie

​RAKOTOARISOA Jean Armel

​Projet développé au sein de l'École Supérieure Polytechnique d'Antsiranana (ESPA).