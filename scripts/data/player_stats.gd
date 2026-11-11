# -*- coding: utf-8 -*-
"""
player_stats.gd — Ressource de statistiques du joueur stickman.

Vie, mana, endurance et vitesses. Sérialisable pour la sauvegarde.
"""

class_name PlayerStats
extends Resource

@export var max_hp: int = 100
@export var hp: int = 100
@export var max_mana: int = 50
@export var mana: int = 50
@export var max_stamina: int = 100
@export var stamina: int = 100

@export var walk_speed: float = 3.5
@export var run_speed: float = 6.0
@export var sprint_speed: float = 9.0
@export var jump_force: float = 6.5

func _init(
	p_max_hp: int = 100,
	p_hp: int = 100,
	p_max_mana: int = 50,
	p_mana: int = 50,
	p_max_stamina: int = 100,
	p_stamina: int = 100,
	p_walk_speed: float = 3.5,
	p_run_speed: float = 6.0,
	p_sprint_speed: float = 9.0,
	p_jump_force: float = 6.5
) -> void:
	max_hp = p_max_hp
	hp = p_hp
	max_mana = p_max_mana
	mana = p_mana
	max_stamina = p_max_stamina
	stamina = p_stamina
	walk_speed = p_walk_speed
	run_speed = p_run_speed
	sprint_speed = p_sprint_speed
	jump_force = p_jump_force

# Soigne / endommage le joueur, clampé aux bornes.
func modify_hp(amount: int) -> int:
	hp = clamp(hp + amount, 0, max_hp)
	return hp

# Consomme / restaure le mana.
func modify_mana(amount: int) -> int:
	mana = clamp(mana + amount, 0, max_mana)
	return mana

# Consomme l'endurance (sprint, esquive).
func modify_stamina(amount: int) -> int:
	stamina = clamp(stamina + amount, 0, max_stamina)
	return stamina

func is_dead() -> bool:
	return hp <= 0
