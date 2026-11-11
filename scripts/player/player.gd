# -*- coding: utf-8 -*-
"""
player.gd — Contrôleur du joueur stickman (3e personne).

- Déplacement relatif à l'orientation de la caméra (marche / course / sprint).
- Saut, gravité, accélération/décélération naturelles.
- Collisions via CharacterBody3D (le personnage ne traverse pas les solides).
- États d'animation exposés par signaux (idle, walk, run, sprint, jump, fall, land, ...).
- Identité stickman préservée : jamais d'humanoïde réaliste.

À attacher sur le node racine `Player` (CharacterBody3D) de scenes/player/player.tscn.
"""

class_name Player
extends CharacterBody3D

# --- Signaux d'état d'animation (brancher sur un AnimationPlayer / AnimationTree) ---
signal animation_changed(new_state: String)
signal jump_started()
signal landed()
signal dodged(direction: Vector2)
signal interacted()

# --- Références ---
@export var camera_pivot: Node3D = null   # GameCamera (pivot) pour la direction relative
@export var animation_player: NodePath = "" # AnimationPlayer enfant (optionnel)

# --- Vitesses (m/s) ---
@export var walk_speed: float = 3.5
@export var run_speed: float = 6.0
@export var sprint_speed: float = 9.0
@export var jump_force: float = 6.5
@export var gravity: float = -24.0
@export var acceleration: float = 12.0
@export var deceleration: float = 14.0
@export var air_control: float = 6.0

# --- État interne ---
var _velocity: Vector3 = Vector3.ZERO
var _current_speed: float = 0.0
var _target_speed: float = 0.0
var _is_sprinting: bool = false
var _is_grounded: bool = false
var _was_grounded: bool = false
var _move_input: Vector2 = Vector2.ZERO
var _animation_state: String = "idle"

# Constante de marche au sol (échelle Godot mètre).
const FLOOR_UP: Vector3 = Vector3.UP

func _ready() -> void:
	if animation_player != "" and has_node(animation_player):
		var ap: AnimationPlayer = get_node(animation_player)
		ap.animation_finished.connect(_on_animation_finished)
		ap.frame_changed.connect(_on_frame_changed)

	# S'assurer que la collision est active
	var collision: CollisionShape3D = get_node_or_null("CollisionShape")
	if collision:
		collision.disabled = false

func _physics_process(delta: float) -> void:
	_was_grounded = _is_grounded
	_is_grounded = is_on_floor()

	# Lecture des entrées de mouvement (clavier manette / joystick virtuel branché via Input)
	_move_input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Sprint : touche Shift ou bouton dédié (à mapper dans project.godot / UI)
	_is_sprinting = Input.is_action_pressed("sprint") or Input.is_action_pressed("ui_accept")

	# Saut (une seule fois au contact du sol)
	if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("jump"):
		if _is_grounded:
			_velocity.y = jump_force
			_animation_state = "jump"
			_apply_animation_state()
			jump_started.emit()

	# Gravité
	if not _is_grounded:
		_velocity.y += gravity * delta

	# Vitesse cible selon l'état de marche/course/sprint
	if _is_sprinting:
		_target_speed = sprint_speed
	elif _move_input.length() > 0.1:
		_target_speed = run_speed
	else:
		_target_speed = 0.0

	# Lissage accélération / décélération
	if _target_speed > 0.0 and _move_input.length() > 0.1:
		_current_speed = lerp(_current_speed, _target_speed, acceleration * delta)
	else:
		_current_speed = lerp(_current_speed, _target_speed, deceleration * delta)

	# Direction de déplacement relative à la caméra
	var move_dir: Vector3 = Vector3.ZERO
	if _move_input.length() > 0.05 and camera_pivot != null:
		var cam_forward: Vector3 = -camera_pivot.global_transform.basis.z.normalized()
		var cam_right: Vector3 = camera_pivot.global_transform.basis.x.normalized()
		cam_forward.y = 0.0
		cam_right.y = 0.0
		cam_forward = cam_forward.normalized()
		cam_right = cam_right.normalized()
		move_dir = (cam_forward * _move_input.y + cam_right * _move_input.x).normalized()
	elif _target_speed <= 0.0:
		move_dir = Vector3.ZERO

	# Appliquer la vélocité horizontale
	if _is_grounded:
		_velocity.x = move_dir.x * _current_speed
		_velocity.z = move_dir.z * _current_speed
	else:
		# Contrôle limité en l'air
		var wish_dir: Vector3 = move_dir * _current_speed * air_control
		_velocity.x = lerp(_velocity.x, wish_dir.x, air_control * delta)
		_velocity.z = lerp(_velocity.z, wish_dir.z, air_control * delta)

	move_and_slide()

	# Détermination de l'état d'animation
	_update_animation_state(move_dir)

	# Orientation progressive du stickman vers la direction de déplacement
	if move_dir.length() > 0.1 and _is_grounded:
		var target_look: Vector3 = global_position + move_dir
		look_at(target_look, Vector3.UP)

func _update_animation_state(move_dir: Vector3) -> void:
	var new_state: String = _animation_state

	if not _is_grounded:
		if _velocity.y < 0:
			new_state = "fall"
		else:
			new_state = "jump"
	elif _move_input.length() > 0.1:
		if _is_sprinting:
			new_state = "sprint"
		else:
			new_state = "run"
	else:
		new_state = "idle"

	# Détection atterrissage
	if _is_grounded and not _was_grounded:
		new_state = "land"
		landed.emit()

	if new_state != _animation_state:
		_animation_state = new_state
		_apply_animation_state()

func _apply_animation_state() -> void:
	animation_changed.emit(_animation_state)
	if animation_player != "" and has_node(animation_player):
		var ap: AnimationPlayer = get_node(animation_player)
		if ap.has_animation(_animation_state):
			ap.play(_animation_state)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "land":
		_animation_state = "idle"
		_apply_animation_state()
	elif anim_name == "jump":
		# Si toujours en l'air après l'animation de saut, passer en fall
		if not _is_grounded:
			_animation_state = "fall"
			_apply_animation_state()

func _on_frame_changed(frame: int) -> void:
	# Exposé pour le CombatManager (fenêtres de dégâts liées à l'animation)
	pass

# --- API publique ---

# Demande un changement d'état d'animation (appelé par le CombatManager / UI).
func set_animation_state(state: String) -> void:
	_animation_state = state
	_apply_animation_state()

# Retourne l'état d'animation courant.
func get_animation_state() -> String:
	return _animation_state

# Indique si le joueur est au sol.
func is_player_grounded() -> bool:
	return _is_grounded

# Retourne la vélocité courante (utile pour le combat / recul).
func get_velocity() -> Vector3:
	return _velocity

# Applique un recul (knockback) suite à un impact ennemi.
func apply_knockback(direction: Vector3, strength: float) -> void:
	_velocity = direction.normalized() * strength
	_velocity.y = max(_velocity.y, strength * 0.5)

# Définit la référence caméra (appelé depuis la scène principale).
func set_camera(cam: Node3D) -> void:
	camera_pivot = cam
