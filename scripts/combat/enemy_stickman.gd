extends CharacterBody3D
class_name EnemyStickman

# Signaux
signal died()
signal hit_taken(amount: int, knockback: Vector3)

# Stats
@export var hp: int = 100
@export var max_hp: int = 100
@export var damage: int = 15
@export var move_speed: float = 4.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 2.0
@export var knockback_strength: float = 8.0

# Machine à états simple
enum State { IDLE, CHASE, ATTACK, HIT, DIE }
var state: State = State.IDLE

# Cible (joueur)
var target: Node3D = null
var last_attack_time: float = 0.0
var hit_recovery: float = 0.0
var is_dead: bool = false

func _ready() -> void:
	max_hp = hp

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	match state:
		State.IDLE:
			_update_target()
			if target != null:
				state = State.CHASE
		State.CHASE:
			_update_target()
			if target == null:
				state = State.IDLE
				return
			var direction: Vector3 = (target.global_position - global_position).normalized()
			var distance: float = global_position.distance_to(target.global_position)
			if distance <= attack_range:
				state = State.ATTACK
			else:
				velocity = direction * move_speed
				move_and_slide()
		State.ATTACK:
			_update_target()
			if target == null:
				state = State.CHASE
				return
			var distance: float = global_position.distance_to(target.global_position)
			if distance > attack_range:
				state = State.CHASE
				return
			if Time.get_ticks_msec() / 1000.0 - last_attack_time >= attack_cooldown:
				last_attack_time = Time.get_ticks_msec() / 1000.0
				_perform_attack()
		State.HIT:
			hit_recovery -= delta
			if hit_recovery <= 0:
				state = State.CHASE if target != null else State.IDLE
		State.DIE:
			velocity = Vector3.ZERO
			move_and_slide()

# Reçoit des dégâts : applique le recul (knockback), joue l'animation "hit", meurt si HP <= 0.
func take_damage(amount: int, knockback_vector: Vector3) -> void:
	if is_dead:
		return
	hp -= amount
	if hp <= 0:
		hp = 0
		_die()
		return
	state = State.HIT
	hit_recovery = 0.5
	hit_taken.emit(amount, knockback_vector)
	# Applique le recul physique
	velocity = knockback_vector * knockback_strength
	velocity.y = max(velocity.y, knockback_strength * 0.5)
	move_and_slide()
	# Joue l'animation "hit" (à brancher sur l'AnimationPlayer de l'ennemi)
	# $AnimationPlayer.play("hit")

func _perform_attack() -> void:
	# Joue l'animation d'attaque (à brancher sur l'AnimationPlayer)
	# $AnimationPlayer.play("attack")
	# Les dégâts au joueur sont appliqués via une hitbox/en fenêtre de dégâts côté CombatManager.
	pass

func _die() -> void:
	is_dead = true
	state = State.DIE
	velocity = Vector3.ZERO
	# Joue l'animation de mort (à brancher)
	# $AnimationPlayer.play("die")
	died.emit()
	# Notifie le CombatManager s'il est disponible (autoload)
	if Engine.has_singleton("CombatManager"):
		var cm: CombatManager = CombatManager
		if cm.is_instance_valid():
			cm.enemy_defeated.emit(self)

func _update_target() -> void:
	if target == null or not target.is_inside_tree():
		var players: Array = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
