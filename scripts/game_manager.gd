# -*- coding: utf-8 -*-
"""
game_manager.gd — Gestionnaire de jeu (autoload).

- Chargement / déchargement par zones (monde ouvert, étape 6 du CdC).
- Sauvegarde / chargement de partie (FileAccess, JSON).
- Données persistantes : position joueur, vie, mana, flags, inventaire.

À déclarer comme autoload dans project.godot :
[autoload]
GameManager = "res://scripts/game_manager.gd"
"""

class_name GameManager
extends Node

# --- Signaux ---
signal zone_loaded(zone_path: String)
signal zone_unloaded(zone_path: String)
signal game_saved(path: String)
signal game_loaded(path: String)
signal save_error(message: String)

# --- Références ---
@export var scene_main: NodePath = "/root/Main"  # node contenant le niveau courant

# --- Données de partie courante ---
var game_data: GameData = null
var _zone_courante: String = ""
var _zones_precachees: Array[String] = []

# Dossier de sauvegarde
const SAVE_DIR: String = "user://saves"
const SAVE_EXT: String = ".sav"

func _ready() -> void:
	# Initialiser les données si absent
	if game_data == null:
		game_data = GameData.new()
	# Créer le dossier de sauvegarde si besoin
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		DirAccess.make_dir_recursive(SAVE_DIR)

# --- Zones (chargement progressif) ---

# Charger une zone (instancier sa scène et l'ajouter à l'arbre principal).
func change_scene_to_zone(zone_path: String) -> void:
	# Décharger la zone précédente si une est active
	if _zone_courante != "" and _zone_courante != zone_path:
		unload_zone(_zone_courante)

	var scene: PackedScene = load(zone_path)
	if scene == null:
		push_error("GameManager : impossible de charger la zone " + zone_path)
		return

	var instance: Node = scene.instantiate()
	var main: Node = get_node_or_null(scene_main)
	if main:
		main.add_child(instance)
		_zone_courante = zone_path
		zone_loaded.emit(zone_path)

	# Placer le joueur au point de spawn s'il existe dans la zone
	var spawn: Marker3D = instance.get_node_or_null("SpawnPoint")
	if spawn and game_data.joueur_position != Vector3.ZERO:
		# La position sera appliquée au joueur par la scène elle-même (voir Prologue)
		pass

# Précharger une zone (à appeler pour les zones proches).
func preload_zone(zone_path: String) -> void:
	if zone_path not in _zones_precachees:
		var scene: PackedScene = load(zone_path)
		if scene:
			_zones_precachees.append(zone_path)

# Décharger une zone.
func unload_zone(zone_path: String) -> void:
	var main: Node = get_node_or_null(scene_main)
	if main:
		# Trouver l'instance de cette zone (par nom de scène ou tag)
		for child in main.get_children():
			if child.scene_file_path == zone_path or child.get_filename() == zone_path:
				main.remove_child(child)
				child.queue_free()
				break
	_zone_courante = ""
	if zone_path in _zones_precachees:
		_zones_precachees.erase(zone_path)
	zone_unloaded.emit(zone_path)

# --- Sauvegarde / chargement ---

func save_game(path: String) -> void:
	if path == "":
		path = SAVE_DIR + "/partie" + SAVE_EXT
	if not path.begin_with("user://") and not path.begin_with("res://"):
		path = "user://" + path

	# Mettre à jour la position depuis le joueur si présent
	var joueur: Node = get_node_or_null("/root/Main/Joueur")
	if joueur:
		game_data.joueur_position = joueur.global_position

	var fichier: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if fichier == null:
		save_error.emit("Impossible d'ouvrir " + path + " en écriture")
		return

	fichier.store_string(game_data.to_json())
	fichier.close()
	game_saved.emit(path)

func load_game(path: String) -> void:
	if path == "":
		path = SAVE_DIR + "/partie" + SAVE_EXT
	if not path.begin_with("user://") and not path.begin_with("res://"):
		path = "user://" + path

	var fichier: FileAccess = FileAccess.open(path, FileAccess.READ)
	if fichier == null:
		save_error.emit("Aucune sauvegarde trouvée : " + path)
		return

	var contenu: String = fichier.get_as_text()
	fichier.close()

	var donnees: GameData = GameData.from_json(contenu)
	if donnees:
		game_data = donnees
		# Appliquer la position au joueur s'il existe
		var joueur: Node = get_node_or_null("/root/Main/Joueur")
		if joueur and game_data.joueur_position != Vector3.ZERO:
			joueur.global_position = game_data.joueur_position
		game_loaded.emit(path)
	else:
		save_error.emit("Sauvegarde corrompue : " + path)

# --- Accesseurs ---

func get_data() -> GameData:
	return game_data

func get_zone_courante() -> String:
	return _zone_courante

func est_zone_precachee(zone_path: String) -> bool:
	return zone_path in _zones_precachees
