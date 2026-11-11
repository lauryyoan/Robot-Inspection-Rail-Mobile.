# -*- coding: utf-8 -*-
"""
prologue.gd — Scène de prologue jouable (SHADOWS OF FATE).

- Instancie le joueur (Player), la caméra (GameCamera) et l'environnement (Meadow) par code.
- Place le joueur au point de spawn.
- Affiche un dialogue à l'écran (interaction avec un PNJ stickman, texte uniquement).
- Le prologue est jouable (déplacement, saut, interaction), pas une cinématique passive.
- Respecte le canon : n'évoque pas l'origine des voix ni le dieu scellé.

À attacher sur le node racine `Prologue` (Node3D) de scenes/levels/prologue.tscn.
"""

class_name Prologue
extends Node3D

# --- Signaux ---
signal dialogue_started(texte: String)
signal dialogue_ended()

# --- Références (instanciées par code) ---
var joueur: Node3D = null
var caméra: Node3D = null
var environnement: Node3D = null
var label_dialogue: Label = null

# --- Données du prologue ---
var _dialogue_index: int = 0
var _dialogue_en_cours: bool = false
var _dialogues: Array[String] = [
	"Le village s'éveille. L'académie d'épée t'attend, à seize ans.",
	"Ton père adoptif, le garde loyal, t'a élevé comme son propre fils.",
	"Il est mort quand tu avais douze ans. Tu portes son épée ancienne.",
	"Une inscription sur la lame mène aux archives du premier royaume.",
	"Parfois, des voix mystérieuses résonnent. Leur origine reste inconnue.",
]

func _ready() -> void:
	label_dialogue = get_node_or_null("Prologue/DialogueUI/DialogueLabel")

	# Instancier le joueur
	var scène_joueur: PackedScene = load("res://scenes/player/player.tscn")
	if scène_joueur:
		joueur = scène_joueur.instantiate()
		add_child(joueur)
		var spawn: Marker3D = get_node_or_null("SpawnPoint")
		if spawn:
			joueur.global_position = spawn.global_position

	# Instancier la caméra
	var scène_caméra: PackedScene = load("res://scenes/camera/game_camera.tscn")
	if scène_caméra:
		caméra = scène_caméra.instantiate()
		add_child(caméra)
		# Lier caméra → joueur
		var game_camera: GameCamera = caméra
		if game_camera:
			game_camera.set_target(joueur)

	# Instancier l'environnement (prairie)
	var scène_env: PackedScene = load("res://scenes/environment/meadow.tscn")
	if scène_env:
		environnement = scène_env.instantiate()
		add_child(environnement)

	# Démarrer le premier dialogue après une courte pause
	await get_tree().create_timer(1.0).timeout
	_afficher_dialogue(_dialogue_index)

func _input(event: InputEvent) -> void:
	# Interaction : clic / touche pour avancer dans le dialogue ou interagir
	if _dialogue_en_cours:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_avancer_dialogue()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_E:
			_avancer_dialogue()
			return

	# Si pas de dialogue, touche E pour interagir avec le PNJ / relancer le dialogue
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if not _dialogue_en_cours:
			_afficher_dialogue(0)

func _afficher_dialogue(index: int) -> void:
	if index >= _dialogues.size():
		_dialogue_en_cours = false
		label_dialogue.visible = false
		dialogue_ended.emit()
		# Marquer le prologue comme commencé (flags narratifs)
		var flags: StoryFlags = StoryFlags.new()
		flags.valider("rencontre_garde")
		return

	_dialogue_en_cours = true
	_dialogue_index = index
	label_dialogue.text = _dialogues[index]
	label_dialogue.visible = true
	dialogue_started.emit(_dialogues[index])

func _avancer_dialogue() -> void:
	_afficher_dialogue(_dialogue_index + 1)

# --- API publique ---

func get_joueur() -> Node3D:
	return joueur

func get_camera() -> Node3D:
	return caméra
