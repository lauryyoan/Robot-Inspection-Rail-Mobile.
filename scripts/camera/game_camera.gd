# -*- coding: utf-8 -*-
"""
game_camera.gd — Caméra à la 3e personne, orbite libre autour du joueur.

- Rotation horizontale et verticale contrôlée (souris / glissement tactile droit).
- Suivi fluide (lerp) de la position et des angles.
- Déplacement du joueur relatif à l'orientation de la caméra.
- Sensibilité réglable, clamp de l'angle vertical (évite le retournement).
- Raycast simple pour rapprocher la caméra si un obstacle se trouve entre le pivot et la caméra.

À attacher sur le node racine `CameraPivot` (Node3D) de scenes/camera/game_camera.tscn.
"""

class_name GameCamera
extends Node3D

# --- Signaux ---
signal camera_ready()

# --- Références ---
@export var target: Node3D = null   # Le joueur (Player)
@export var camera_node: NodePath = "Camera3D"

# --- Distances et hauteur ---
@export var distance: float = 4.5
@export var height: float = 1.6
@export var min_distance: float = 2.0
@export var max_distance: float = 8.0

# --- Sensibilités ---
@export var sensitivity_h: float = 0.004   # par pixel / unité d'entrée
@export var sensitivity_v: float = 0.004
@export var smooth_speed: float = 10.0

# --- Limites d'angle vertical (degrés) ---
@export var vertical_min: float = -30.0
@export var vertical_max: float = 70.0

# --- État interne ---
var _angle_h: float = 0.0   # yaw (autour de Y)
var _angle_v: float = 20.0  # pitch (autour de X)
var _current_distance: float = 4.5
var _input_h: float = 0.0
var _input_v: float = 0.0
var _is_dragging: bool = false
var _last_drag_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Initialiser les angles depuis la rotation actuelle du pivot
	var rot: Vector3 = rotation_degrees
	_angle_h = rot.y
	_angle_v = clamp(rot.x, vertical_min, vertical_max)
	_current_distance = distance
	_update_camera_position()
	camera_ready.emit()

func _input(event: InputEvent) -> void:
	# Souris : clic droit ou glissement pour orbiter
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_dragging = event.pressed
			if event.pressed:
				_last_drag_pos = event.position
		# Molette pour zoomer (distance)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = clamp(distance - 0.5, min_distance, max_distance)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = clamp(distance + 0.5, min_distance, max_distance)

	if event is InputEventMouseMotion and _is_dragging:
		var delta: Vector2 = event.relative
		_input_h += delta.x * sensitivity_h
		_input_v -= delta.y * sensitivity_v   # inversé Y pour naturel

	# Glissement tactile (simulé par InputEventTouch / InputEventScreenDrag)
	if event is InputEventScreenDrag:
		_input_h += event.relative.x * sensitivity_h
		_input_v -= event.relative.y * sensitivity_v

func _process(delta: float) -> void:
	# Appliquer les entrées accumulées
	_angle_h += _input_h
	_angle_v = clamp(_angle_v + _input_v, vertical_min, vertical_max)

	# Reset des entrées après application (pour ne pas cumuler deux fois)
	_input_h = 0.0
	_input_v = 0.0

	# Normaliser l'angle horizontal
	while _angle_h > 180.0:
		_angle_h -= 360.0
	while _angle_h < -180.0:
		_angle_h += 360.0

	# Interpolation fluide de la distance (zoom / obstacle)
	var target_distance: float = _cast_obstacle_distance()
	_current_distance = lerp(_current_distance, target_distance, smooth_speed * delta)

	# Mise à jour de la position et rotation du pivot
	rotation_degrees = Vector3(_angle_v, _angle_h, 0.0)
	_update_camera_position()

	# Faire regarder le pivot vers le joueur (si cible définie)
	if target != null:
		look_at(target.global_position, Vector3.UP)

func _update_camera_position() -> void:
	# Position de la Camera3D : derrière et au-dessus du pivot, à la distance voulue
	var cam: Camera3D = get_node_or_null(camera_node)
	if cam == null:
		return

	# Direction vers l'avant du pivot (après rotation)
	var forward: Vector3 = -global_transform.basis.z.normalized()
	var up: Vector3 = Vector3.UP
	var offset: Vector3 = forward * -_current_distance + Vector3.UP * height
	cam.global_position = global_position + offset
	# La caméra regarde déjà vers le pivot via look_at du Node3D parent ; on s'assure qu'elle est orientée vers le centre
	cam.look_at(global_position, Vector3.UP)

# Raycast simple : si un obstacle se trouve entre le pivot et la position idéale de la caméra,
# rapprocher la caméra pour éviter de traverser les murs.
func _cast_obstacle_distance() -> float:
	var ideal_pos: Vector3
	var cam: Camera3D = get_node_or_null(camera_node)
	if cam == null:
		return distance
	# Recalculer la position idéale sans tenir de l'obstacle
	var forward: Vector3 = -global_transform.basis.z.normalized()
	ideal_pos = global_position + forward * -distance + Vector3.UP * height

	var space_state: DirectPhysicsState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQuery3D = PhysicsRayQuery3D.create(global_position, ideal_pos)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result: Dictionary = space_state.intersect_ray(query)

	if result.has("collider"):
		var hit_pos: Vector3 = result.get("position")
		var hit_dist: float = global_position.distance_to(hit_pos)
		# Marge de sécurité pour ne pas coller au mur
		return clamp(hit_dist - 0.2, min_distance, max_distance)

	return distance

# --- API publique ---

# Définir la cible (joueur) à suivre.
func set_target(t: Node3D) -> void:
	target = t
	if target != null:
		# Placer le pivot sur la position du joueur au démarrage
		global_position = target.global_position

# Ajouter un delta d'entrée (appelé par l'UI joystick caméra).
func add_input(delta_h: float, delta_v: float) -> void:
	_input_h += delta_h * sensitivity_h
	_input_v -= delta_v * sensitivity_v

# Régler la sensibilité.
func set_sensitivity(h: float, v: float) -> void:
	sensitivity_h = h
	sensitivity_v = v

# Régler la distance.
func set_distance(d: float) -> void:
	distance = clamp(d, min_distance, max_distance)
	_current_distance = distance

# Retourne la direction avant de la caméra (utile pour le déplacement du joueur).
func get_camera_forward() -> Vector3:
	var f: Vector3 = -global_transform.basis.z.normalized()
	f.y = 0.0
	return f.normalized()

# Retourne la direction droite de la caméra.
func get_camera_right() -> Vector3:
	var r: Vector3 = global_transform.basis.x.normalized()
	r.y = 0.0
	return r.normalized()
