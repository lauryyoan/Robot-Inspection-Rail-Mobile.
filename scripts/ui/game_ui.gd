# -*- coding: utf-8 -*-
"""
game_ui.gd — Interface tactile Android.

- Joystick virtuel à gauche (déplacement).
- Zone de caméra à droite (glissement pour orbiter).
- Boutons : attaque légère, attaque lourde, esquive, saut, interaction, compétence.
- Barres de vie et de mana en haut à gauche.
- Multitouch : déplacement + caméra + attaque simultanés.
- Boutons assez grands, espacés, ne masquent pas la visibilité du combat.
- Redimensionnement / sensibilité préparés.

À attacher sur le node racine `GameUI` (CanvasLayer) de scenes/ui/game_ui.tscn.
"""

class_name GameUI
extends CanvasLayer

# --- Signaux vers le gameplay ---
signal joystick_direction(direction: Vector2)
signal camera_drag(delta: Vector2)
signal attack_light()
signal attack_heavy()
signal dodge()
signal jump()
signal interact()
signal skill_1()

# --- Références ---
@export var joystick_bg: NodePath = "JoystickBg"
@export var joystick_knob: NodePath = "JoystickBg/JoystickKnob"
@export var camera_zone: NodePath = "CameraZone"
@export var btn_attack_light: NodePath = "BtnAttackLight"
@export var btn_attack_heavy: NodePath = "BtnAttackHeavy"
@export var btn_dodge: NodePath = "BtnDodge"
@export var btn_jump: NodePath = "BtnJump"
@export var btn_interact: NodePath = "BtnInteract"
@export var btn_skill: NodePath = "BtnSkill"
@export var bar_hp: NodePath = "BarHP"
@export var bar_mana: NodePath = "BarMana"

# --- Réglages ---
@export var joystick_radius: float = 60.0
@export var camera_sensitivity: float = 0.003
@export var joystick_deadzone: float = 0.15

# --- État tactile ---
var _joystick_active_id: int = -1
var _joystick_anchor: Vector2 = Vector2.ZERO
var _joystick_value: Vector2 = Vector2.ZERO
var _camera_active_id: int = -1
var _camera_last_pos: Vector2 = Vector2.ZERO

# Suivi des doigts actifs (multitouch)
var _active_touches: Dictionary = {}   # id -> {type: "joystick"|"camera", pos: Vector2}

func _ready() -> void:
	# Configurer les boutons (signaux pressé)
	var btns: Array[NodePath] = [btn_attack_light, btn_attack_heavy, btn_dodge, btn_jump, btn_interact, btn_skill]
	for p in btns:
		var btn: Button = get_node_or_null(p)
		if btn:
			btn.pressed.connect(_on_btn_pressed.bind(p))

	# Position initiale du joystick (centré sur son bg)
	var bg: Control = get_node_or_null(joystick_bg)
	var knob: Control = get_node_or_null(joystick_knob)
	if bg and knob:
		_joystick_anchor = bg.get_global_rect().center + Vector2(0, -bg.size.y * 0.15)
		knob.position = Vector2.ZERO  # relatif au bg

	# Valeurs par défaut des barres
	set_hp(100, 100)
	set_mana(50, 50)

func _input(event: InputEvent) -> void:
	# Gestion multitouch : chaque doigt est traité indépendamment.
	if event is InputEventScreenTouch:
		var id: int = event.index
		if event.pressed:
			_activer_doigt(id, event.position)
		else:
			_desactiver_doigt(id)

	if event is InputEventScreenDrag:
		var id: int = event.index
		if _active_touches.has(id):
			var info: Dictionary = _active_touches[id]
			var type_doigt: String = info.get("type", "")
			var pos: Vector2 = event.position
			if type_doigt == "joystick":
				_mettre_a_jour_joystick(id, pos)
			elif type_doigt == "camera":
				_mettre_a_jour_camera(id, pos)

	# Souris (test sur PC) : clic gauche = joystick, clic droit = caméra
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_activer_souris_joystick(event.position)
			else:
				_desactiver_souris_joystick()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_activer_souris_camera(event.position)
			else:
				_desactiver_souris_camera()

	if event is InputEventMouseMotion:
		if _joystick_active_id == -1 and _camera_active_id == -1:
			# Pas de prise en main souris définie ; ignorer
			pass

func _activer_doigt(id: int, pos: Vector2) -> void:
	# Détecter si le doigt touche le joystick (bas gauche) ou la zone caméra (droite)
	var bg_rect: Rect2
	var bg: Control = get_node_or_null(joystick_bg)
	if bg:
		bg_rect = bg.get_global_rect()

	var cam_rect: Rect2
	var cz: Control = get_node_or_null(camera_zone)
	if cz:
		cam_rect = cz.get_global_rect()

	if bg_rect.has_point(pos):
		_active_touches[id] = {"type": "joystick", "pos": pos}
		_joystick_active_id = id
		_joystick_anchor = bg_rect.center + Vector2(0, -bg_rect.size.y * 0.15)
		_mettre_a_jour_joystick(id, pos)
	elif cam_rect.has_point(pos):
		_active_touches[id] = {"type": "camera", "pos": pos}
		_camera_active_id = id
		_camera_last_pos = pos

func _desactiver_doigt(id: int) -> void:
	if _active_touches.has(id):
		var type_doigt: String = _active_touches[id].get("type", "")
		_active_touches.erase(id)
		if type_doigt == "joystick":
			_joystick_active_id = -1
			_joystick_value = Vector2.ZERO
			var knob: Control = get_node_or_null(joystick_knob)
			if knob:
				knob.position = Vector2.ZERO
			joystick_direction.emit(Vector2.ZERO)
		elif type_doigt == "camera":
			_camera_active_id = -1

# --- Souris (PC) ---
var _souris_joystick: bool = false
var _souris_camera: bool = false
var _souris_joystick_pos: Vector2 = Vector2.ZERO
var _souris_camera_pos: Vector2 = Vector2.ZERO

func _activer_souris_joystick(pos: Vector2) -> void:
	_souris_joystick = true
	_souris_joystick_pos = pos
	var bg: Control = get_node_or_null(joystick_bg)
	if bg:
		_joystick_anchor = bg.get_global_rect().center + Vector2(0, -bg.size.y * 0.15)
	_mettre_a_jour_souris_joystick(pos)

func _desactiver_souris_joystick() -> void:
	_souris_joystick = false
	_joystick_value = Vector2.ZERO
	var knob: Control = get_node_or_null(joystick_knob)
	if knob:
		knob.position = Vector2.ZERO
	joystick_direction.emit(Vector2.ZERO)

func _activer_souris_camera(pos: Vector2) -> void:
	_souris_camera = true
	_souris_camera_pos = pos

func _desactiver_souris_camera() -> void:
	_souris_camera = false

func _process(delta: float) -> void:
	# Souris joystick en continu
	if _souris_joystick:
		_mettre_a_jour_souris_joystick(_souris_joystick_pos)

	# Souris caméra en continu
	if _souris_camera:
		var delta_pos: Vector2 = get_viewport().get_mouse_position() - _souris_camera_pos
		_souris_camera_pos = get_viewport().get_mouse_position()
		camera_drag.emit(delta_pos * camera_sensitivity)

def _mettre_a_jour_joystick(id: int, pos: Vector2) -> void:
	var bg: Control = get_node_or_null(joystick_bg)
	var knob: Control = get_node_or_null(joystick_knob)
	if not bg or not knob:
		return

	var local_pos: Vector2 = pos - bg.get_global_position()
	var dir: Vector2 = (local_pos - _joystick_anchor + bg.get_global_position() - bg.get_global_position()).normalized()
	# Simplifier : direction relative à l'ancre
	var offset: Vector2 = pos - _joystick_anchor
	var dist: float = offset.length()
	var clamped: Vector2 = offset.clamped(joystick_radius)
	_joystick_value = clamped / joystick_radius

	# Deadzone
	if _joystick_value.length() < joystick_deadzone:
		_joystick_value = Vector2.ZERO

	knob.position = clamped
	joystick_direction.emit(_joystick_value)

	# Mémoriser pour le doigt
	if _active_touches.has(id):
		_active_touches[id]["pos"] = pos

func _mettre_a_jour_camera(id: int, pos: Vector2) -> void:
	var delta: Vector2 = pos - _camera_last_pos
	_camera_last_pos = pos
	camera_drag.emit(delta * camera_sensitivity)

	if _active_touches.has(id):
		_active_touches[id]["pos"] = pos

func _mettre_a_jour_souris_joystick(pos: Vector2) -> void:
	var bg: Control = get_node_or_null(joystick_bg)
	var knob: Control = get_node_or_null(joystick_knob)
	if not bg or not knob:
		return

	var anchor_screen: Vector2 = _joystick_anchor
	var offset: Vector2 = pos - anchor_screen
	var clamped: Vector2 = offset.clamped(joystick_radius)
	_joystick_value = clamped / joystick_radius
	if _joystick_value.length() < joystick_deadzone:
		_joystick_value = Vector2.ZERO
	knob.position = clamped
	joystick_direction.emit(_joystick_value)

# --- Boutons ---
func _on_btn_pressed(path: NodePath) -> void:
	match path:
		btn_attack_light: attack_light.emit()
		btn_attack_heavy: attack_heavy.emit()
		btn_dodge: dodge.emit()
		btn_jump: jump.emit()
		btn_interact: interact.emit()
		btn_skill: skill_1.emit()

# --- API publique (appelée par le GameManager / Player) ---

# Mettre à jour la barre de vie.
func set_hp(valeur: int, maximum: int) -> void:
	var bar: TextureProgress = get_node_or_null(bar_hp)
	if bar:
		bar.max = maximum
		bar.value = clamp(valeur, 0, maximum)

# Mettre à jour la barre de mana.
func set_mana(valeur: int, maximum: int) -> void:
	var bar: TextureProgress = get_node_or_null(bar_mana)
	if bar:
		bar.max = maximum
		bar.value = clamp(valeur, 0, maximum)

# Régler la sensibilité de la caméra.
func set_camera_sensitivity(val: float) -> void:
	camera_sensitivity = val

# Régler le rayon du joystick (redimensionnement).
func set_joystick_radius(val: float) -> void:
	joystick_radius = val

# Retourne la direction courante du joystick.
func get_joystick_value() -> Vector2:
	return _joystick_value
