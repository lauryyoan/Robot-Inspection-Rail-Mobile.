extends Node
class_name CombatManager

# États de combat du système (inspiration rythme/impact God of War III, sans copie d'animations).
enum CombatState { IDLE, ENGAGED, COMBO, DODGING, PARRYING, HIT, DEFEATED }

# --- Signaux ---
signal combo_started(combo_index: int)
signal combo_hit(index: int, damage: int)
signal combo_ended()
signal player_dodged()
signal player_parried()
signal enemy_hit(target: Node, damage: int)
signal enemy_defeated(target: Node)
# QTE : structure prévue (rare et annoncé). À déclencher par le niveau/boss, jamais au hasard.
signal qte_requested(action_name: String, duration: float)

# --- Références ---
var player: Node3D = null
var current_target: Node = null

# --- État ---
var combat_state: CombatState = CombatState.IDLE

# --- Combo ---
var combo_attacks: Array[Attack] = []
var combo_index: int = 0
var combo_timer: Timer = null
@export var combo_reset_time: float = 1.5

# --- Cooldowns ---
@export var attack_cooldown: float = 0.6
var last_attack_time: float = 0.0
@export var dodge_cooldown: float = 0.8
var last_dodge_time: float = 0.0
@export var parry_window: float = 0.3
var parry_active: bool = false

# --- Fenêtres de dégâts liées aux animations ---
# Dictionnaire : nom_animation -> {start_frame, end_frame, shape, damage}
var damage_windows: Dictionary = {}
var _active_animation: String = ""
var _current_frame: int = 0

# Hitbox d'arme (Area3D), activée seulement durant la fenêtre de dégâts de l'animation.
var weapon_hitbox: Area3D = null
var _hitbox_collision: CollisionShape3D = null

func _ready() -> void:
	# Timer de reset du combo
	combo_timer = Timer.new()
	combo_timer.one_shot = true
	combo_timer.wait_time = combo_reset_time
	combo_timer.timeout.connect(_on_combo_timeout)
	add_child(combo_timer)

	# Hitbox d'arme (désactivée par défaut)
	weapon_hitbox = Area3D.new()
	weapon_hitbox.name = "WeaponHitBox"
	weapon_hitbox.monitoring = false
	_hitbox_collision = CollisionShape3D.new()
	_hitbox_collision.name = "HitBoxShape"
	weapon_hitbox.add_child(_hitbox_collision)
	add_child(weapon_hitbox)

	weapon_hitbox.body_entered.connect(_on_weapon_hitbox_body_entered)

func _process(_delta: float) -> void:
	_update_damage_window()

# Enregistre une fenêtre de dégâts pour une animation donnée.
# start_frame/end_frame : borne de frame durant laquelle la hitbox d'arme est active.
func register_attack(animation_name: String, start_frame: int, end_frame: int, hitbox_shape: Shape3D, damage: int) -> void:
	damage_windows[animation_name] = {
		"start_frame": start_frame,
		"end_frame": end_frame,
		"shape": hitbox_shape,
		"damage": damage
	}

# Définit le node joueur (à appeler depuis la scène Player).
func set_player(p: Node3D) -> void:
	player = p

# Définit la cible courante (ennemi engagé).
func set_target(target: Node) -> void:
	current_target = target
	combat_state = CombatState.ENGAGED if target != null else CombatState.IDLE

# Enregistre un ennemi afin que CombatManager émette enemy_defeated à sa mort.
func register_enemy(enemy: EnemyStickman) -> void:
	if enemy == null:
		return
	enemy.died.connect(_on_enemy_died.bind(enemy))

# Demande une attaque (type : "light" ou "heavy").
func request_attack(type: String) -> void:
	if combat_state == CombatState.DEFEATED:
		return
	if combat_state == CombatState.DODGING or combat_state == CombatState.PARRYING:
		return
	var time: float = Time.get_ticks_msec() / 1000.0
	if time - last_attack_time < attack_cooldown:
		return

	var attack: Attack = null
	if combo_index < combo_attacks.size():
		attack = combo_attacks[combo_index]
	else:
		_end_combo()
		return

	# On pourrait forcer attack.type == type ici pour imposer l'alternance light/heavy.
	last_attack_time = time
	combat_state = CombatState.COMBO

	if combo_index == 0:
		combo_started.emit(0)

	_activate_damage_window(attack.animation_name)

	combo_index += 1
	combo_timer.start()

	combo_hit.emit(combo_index - 1, attack.damage)

# Demande une esquive dans une direction (Vector2 : x = horizontal, y = avant/arrière).
func request_dodge(direction: Vector2) -> void:
	if combat_state == CombatState.DEFEATED:
		return
	var time: float = Time.get_ticks_msec() / 1000.0
	if time - last_dodge_time < dodge_cooldown:
		return
	if combat_state == CombatState.PARRYING:
		return

	# Une esquive annule le combo en cours
	if combat_state == CombatState.COMBO:
		combo_index = 0
		combo_timer.stop()

	last_dodge_time = time
	combat_state = CombatState.DODGING
	player_dodged.emit()

	# Retour à l'état engagé après l'esquive (durée à caler sur l'animation du joueur)
	await get_tree().create_timer(0.4).timeout
	if combat_state == CombatState.DODGING:
		combat_state = CombatState.ENGAGED if current_target != null else CombatState.IDLE

# Demande une parade (fenêtre active durant parry_window secondes).
func request_parry() -> void:
	if combat_state == CombatState.DEFEATED:
		return
	parry_active = true
	combat_state = CombatState.PARRYING
	await get_tree().create_timer(parry_window).timeout
	parry_active = false
	if combat_state == CombatState.PARRYING:
		combat_state = CombatState.ENGAGED if current_target != null else CombatState.IDLE

# Marque une parade réussie (appelé par le joueur ou un détecteur de coup adverse).
func parry_success() -> void:
	if combat_state != CombatState.PARRYING:
		return
	player_parried.emit()
	parry_active = false
	combat_state = CombatState.ENGAGED if current_target != null else CombatState.IDLE

# À appeler par le joueur pour indiquer la frame courante de l'animation
# (ex: depuis _process ou le signal frame_changed d'AnimationPlayer).
func set_animation_frame(frame: int) -> void:
	_current_frame = frame

# Active la fenêtre de dégâts d'une animation (appelé par le joueur au lancement de l'attaque).
func _activate_damage_window(animation_name: String) -> void:
	_active_animation = animation_name

func _update_damage_window() -> void:
	if _active_animation == "":
		weapon_hitbox.monitoring = false
		_hitbox_collision.shape = null
		return
	var data: Dictionary = damage_windows.get(_active_animation, {})
	if data.is_empty():
		weapon_hitbox.monitoring = false
		_hitbox_collision.shape = null
		return
	var start_frame: int = data.get("start_frame", 0)
	var end_frame: int = data.get("end_frame", 0)
	if _current_frame >= start_frame and _current_frame <= end_frame:
		_hitbox_collision.shape = data.get("shape", null)
		weapon_hitbox.monitoring = true
	else:
		weapon_hitbox.monitoring = false
		_hitbox_collision.shape = null

func _on_weapon_hitbox_body_entered(body: Node) -> void:
	if body is EnemyStickman:
		var data: Dictionary = damage_windows.get(_active_animation, {})
		var damage: int = data.get("damage", 0)
		var knockback: Vector3 = -global_transform.basis.z * 5.0
		body.take_damage(damage, knockback)
		enemy_hit.emit(body, damage)

func _on_enemy_died(enemy: EnemyStickman) -> void:
	enemy_defeated.emit(enemy)

func _on_combo_timeout() -> void:
	_end_combo()

func _end_combo() -> void:
	combo_ended.emit()
	combo_index = 0
	_active_animation = ""
	weapon_hitbox.monitoring = false
	combat_state = CombatState.ENGAGED if current_target != null else CombatState.IDLE
