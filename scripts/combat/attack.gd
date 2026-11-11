extends Resource
class_name Attack

# Données d'une attaque du système de combat (stickman).
@export var name: String = ""
@export var type: String = "light"        # "light" ou "heavy"
@export var damage: int = 10
@export var hitbox: Shape3D = null        # Forme de la hitbox d'arme liée à l'attaque
@export var duration: float = 0.5
@export var combo_link: Attack = null     # Attaque suivante possible dans le combo
@export var animation_name: String = ""   # Nom de l'animation joueur liée

func _init(p_name: String = "", p_type: String = "light", p_damage: int = 10, p_animation: String = "") -> void:
	name = p_name
	type = p_type
	damage = p_damage
	animation_name = p_animation

# Construit un combo prédéfini : light x3 puis heavy finisher.
# Les liens combo_link sont déjà reliés (1 -> 2 -> 3 -> finisseur).
static func create_default_combo() -> Array[Attack]:
	var light1: Attack = Attack.new("Coup léger 1", "light", 10, "attack_light_1")
	var light2: Attack = Attack.new("Coup léger 2", "light", 12, "attack_light_2")
	var light3: Attack = Attack.new("Coup léger 3", "light", 15, "attack_light_3")
	var heavy: Attack = Attack.new("Coup lourd finisseur", "heavy", 30, "attack_heavy_finisher")
	light1.combo_link = light2
	light2.combo_link = light3
	light3.combo_link = heavy
	return [light1, light2, light3, heavy]
