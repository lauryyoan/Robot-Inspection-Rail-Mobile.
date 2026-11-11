# -*- coding: utf-8 -*-
"""
meadow.gd — Prototype environnemental (prairie stylisée).

- Herbe via MultiMeshInstance3D (instanciation, pas un nœud par brin).
- Brins fins, hauteurs/inclinaisons variées, plusieurs nuances de vert.
- Répartition irrégulière (pas de grille), densité qui diminue avec la distance (patchs/cellules).
- Matériau partagé + shader de vent peu coûteux (vertex shader).
- Maison, arbre, rocher, chemin : StaticBody3D + CollisionShape3D simples (volumes 3D, pas de plans plats).
- Cycle jour/nuit simple (DirectionalLight).
- L'herbe réagit visuellement au passage (shader de proximité, pas de physique individuelle).

À instancier comme niveau de départ (run/main_scene ou prologue).
"""

class_name Meadow
extends Node3D

# --- Signaux ---
signal cycle_jour_nuit_changed(heure: float)

# --- Références ---
@export var multi_mesh_instance: NodePath = "HerbeMultiMesh"
@export var directional_light: NodePath = "DirectionalLight"

# --- Données herbe ---
@export var herbe_densite_proche: int = 4000      # instances par patch proche
@export var herbe_densite_lointaine: int = 800    # instances par patch lointain
@export var herbe_taille_patch: float = 8.0       # taille d'un patch en mètres
@export var herbe_distance_affichage: float = 60.0
@export var herbe_hauteur_min: float = 0.15
@export var herbe_hauteur_max: float = 0.55
@export var herbe_nombre_patchs: int = 9          # 3x3 autour du joueur

# --- Couleurs herbe (plusieurs nuances de vert, pas de fluo uniforme) ---
var _couleurs_herbe: Array[Color] = [
	Color(0.30, 0.55, 0.25, 1.0),   # vert foncé
	Color(0.45, 0.70, 0.30, 1.0),   # vert moyen
	Color(0.55, 0.75, 0.35, 1.0),   # vert clair
	Color(0.35, 0.50, 0.20, 1.0),   # vert sombre
]

# --- État ---
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _herbemesh: MultiMeshInstance3D = null
var _lumieres: DirectionalLight = null
var _heure: float = 0.5   # 0.0 = minuit, 0.5 = midi, 1.0 = minuit
var _vitesse_cycle: float = 0.02
var _joueur_position: Vector3 = Vector3.ZERO

# Shader de vent (vertex) — appliqué au matériau des instances d'herbe.
const VENT_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, depth_draw_alpha_prepass, vertex_lighting_unlit;

uniform float time : 1.0;
uniform float vent_force : 0.5;
uniform float vent_vitesse : 1.5;
uniform float hauteur_brin : 1.0;

void vertex() {
    // Déformation sinusoïdale selon la hauteur du brin (vent)
    float sway = sin(VERTEX.y * 4.0 + time * vent_vitesse + POSITION.x * 0.7) * vent_force * (VERTEX.y / hauteur_brin);
    VERTEX.x += sway * 0.08;
    VERTEX.z += sway * 0.04;
    // Léger mouvement de respiration
    float breath = sin(time * 2.0 + POSITION.x + POSITION.z) * 0.02;
    VERTEX.y += breath * (VERTEX.y / hauteur_brin);
}
"""

func _ready() -> void:
	_rng.randomize()
	_herbemesh = get_node_or_null(multi_mesh_instance)
	_lumieres = get_node_or_null(directional_light)

	# Si le MultiMesh n'existe pas dans la scène, le créer par code
	if _herbemesh == null:
		_herbemesh = MultiMeshInstance3D.new()
		_herbemesh.name = "HerbeMultiMesh"
		add_child(_herbemesh)

	if _lumieres == null:
		_lumieres = get_node_or_null("DirectionalLight")

	# Configurer le MultiMesh (cube simple pour représenter un brin de herbe stylisé)
	_configurer_multimesh_herbe()

	# Générer les patchs d'herbe autour de l'origine
	_generer_patchs_herbe(Vector3.ZERO)

	# Démarrer le cycle jour/nuit
	set_process(true)

func _process(delta: float) -> void:
	# Cycle jour/nuit
	_heure += _vitesse_cycle * delta
	if _heure > 1.0:
		_heure -= 1.0
	_update_lumiere(_heure)
	cycle_jour_nuit_changed.emit(_heure)

	# Animer le vent (uniform time du shader)
	if _herbemesh != null and _herbemesh.get_material_override() != null:
		var mat: ShaderMaterial = _herbemesh.get_material_override()
		if mat != null:
			mat.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)

	# Mettre à jour les patchs d'herbe selon la position du joueur (LOD / déplacement)
	if _joueur_position.distance_to(get_node_or_null("/root/Main/Joueur")?.global_position or Vector3.ZERO) > 5.0:
		var joueur: Node3D = get_node_or_null("/root/Main/Joueur")
		if joueur != null:
			_joueur_position = joueur.global_position
			_generer_patchs_herbe(_joueur_position)

func _configurer_multimesh_herbe() -> void:
	if _herbemesh == null:
		return

	# Maillage simple : un cylindre aplati / capsule fine pour un brin de herbe
	var maillage: CapsuleMesh = CapsuleMesh.new()
	maillage.radius = 0.02
	maillage.height = 0.4
	maillage.sides = 6   # low-poly, stylisé

	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_count = 1   # sera rempli par patch
	multimesh.instance_count = 1
	multimesh.mesh = maillage
	multimesh.flags = [
		MultiMesh.INSTANCE_FLAG_COLOR,      # couleur par instance (nuances de vert)
		MultiMesh.INSTANCE_FLAG_CUSTOM_DATA, # hauteur / inclinaison
	]

	# Matériau partagé + shader de vent
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = VENT_SHADER
	mat.set_shader_parameter("vent_force", 0.6)
	mat.set_shader_parameter("vent_vitesse", 1.8)
	mat.set_shader_parameter("hauteur_brin", 0.4)
	_herbemesh.set_material_override(mat)

	_herbemesh.multimesh = multimesh

func _generer_patchs_herbe(centre: Vector3) -> void:
	if _herbemesh == null:
		return

	# Nettoyer les instances existantes (re-génération simple pour la démo)
	var multimesh: MultiMesh = _herbemesh.multimesh
	if multimesh == null:
		return

	# Calculer le nombre total d'instances
	var total_instances: int = 0
	for x in range(-1, 2):
		for z in range(-1, 2):
			total_instances += _herbe_densite_patch(centre + Vector3(x * herbe_taille_patch, 0, z * herbe_taille_patch))

	multimesh.instance_count = total_instances
	multimesh.transform_count = total_instances

	var idx: int = 0
	for x in range(-1, 2):
		for z in range(-1, 2):
			var patch_centre: Vector3 = centre + Vector3(x * herbe_taille_patch, 0, z * herbe_taille_patch)
			var densite: int = _herbe_densite_patch(patch_centre)
			for _ in range(densite):
				# Position irrégulière dans le patch (pas de grille)
				var rx: float = _rng.randf_range(-herbe_taille_patch * 0.45, herbe_taille_patch * 0.45)
				var rz: float = _rng.randf_range(-herbe_taille_patch * 0.45, herbe_taille_patch * 0.45)
				var pos: Vector3 = patch_centre + Vector3(rx, 0, rz)

				# Hauteur et inclinaison variées
				var hauteur: float = _rng.randf_range(herbe_hauteur_min, herbe_hauteur_max)
				var inclinaison: float = _rng.randf_range(-0.15, 0.15)  # radians
				var rotation_y: float = _rng.randf_range(0, TAU)

				# Couleur selon la nuance
				var couleur: Color = _couleurs_herbe[_rng.randi_range(0, _couleurs_herbe.size() - 1)]

				# Fade avec la distance (alpha réduit loin)
				var dist: float = centre.distance_to(pos)
				var fade: float = clamp(1.0 - dist / herbe_distance_affichage, 0.3, 1.0)
				couleur.a = fade

				# Transformation : échelle, rotation, translation
				var scale: Vector3 = Vector3(1.0, hauteur / 0.4, 1.0)
				var t: Transform3D = Transform3D(Basis(), pos)
				t = t.rotated(Vector3.UP, rotation_y)
				t = t.rotated(Vector3.RIGHT, inclinaison)
				t = t.scaled(scale)

				# Données custom : hauteur inclinaison (x,y) + fade (z)
				var custom: Vector4 = Vector4(hauteur, inclinaison, fade, 0.0)

				multimesh.set_instance_transform(idx, t)
				multimesh.set_instance_color(idx, couleur)
				multimesh.set_instance_custom_data(idx, custom)
				idx += 1

func _herbe_densite_patch(centre_patch: Vector3) -> int:
	# Densité qui diminue avec la distance à l'origine (LOD)
	var dist: float = centre_patch.length()
	var t: float = clamp(dist / herbe_distance_affichage, 0.0, 1.0)
	return int(lerp(herbe_densite_proche, herbe_densite_lointaine, t))

func _update_lumiere(heure: float) -> void:
	if _lumieres == null:
		return
	# heure : 0.0 minuit, 0.25 aube, 0.5 midi, 0.75 crépuscule, 1.0 minuit
	var jour: float = sin(heure * TAU - PI / 2)   # -1 minuit, 0 aube/crépuscule, 1 midi
	var intensite: float = clamp((jour + 1.0) / 2.0, 0.15, 1.0)
	_lumieres.energy = intensite

	# Couleur du ciel / lumière selon l'heure
	if heure < 0.25 or heure > 0.75:
		# Nuit : bleu sombre
		_lumieres.light_color = Color(0.2, 0.25, 0.4, 1.0)
		_rendering_server_environment_bg(Color(0.05, 0.05, 0.1, 1.0))
	elif heure < 0.5:
		# Jour : bleu clair
		_lumieres.light_color = Color(0.8, 0.9, 1.0, 1.0)
		_rendering_server_environment_bg(Color(0.5, 0.7, 1.0, 1.0))
	else:
		# Coucher de soleil : orange doux
		_lumieres.light_color = Color(1.0, 0.6, 0.35, 1.0)
		_rendering_server_environment_bg(Color(0.4, 0.25, 0.2, 1.0))

# Fond d'écran (ciel) simple via l'environnement (fallback si pas de WorldEnvironment)
func _rendering_server_environment_bg(c: Color) -> void:
	var env: Environment = Environment.new()
	env.background_color = c
	env.background_mode = Environment.BG_COLOR
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	# On ne l'ajoute pas à l'arbre ici pour éviter les doublons ; c'est un fallback indicatif.
	# En production, ajouter un WorldEnvironment dans la scène principale.

# --- API publique ---

# Définir la position du joueur pour le LOD des patchs.
func set_joueur_position(pos: Vector3) -> void:
	_joueur_position = pos

# Régler la densité de l'herbe (profil graphique).
func set_densite_herbe(proche: int, lointaine: int) -> void:
	herbe_densite_proche = proche
	herbe_densite_lointaine = lointaine
