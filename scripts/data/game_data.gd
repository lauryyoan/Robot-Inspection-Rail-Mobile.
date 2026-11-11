# -*- coding: utf-8 -*-
"""
game_data.gd — Ressource de données de partie (sérialisable).

Contient tout ce qui doit persister entre les sessions : position du joueur,
vie, mana, flags de progression et inventaire simple.
"""

class_name GameData
extends Resource

@export var joueur_position: Vector3 = Vector3.ZERO
@export var hp: int = 100
@export var max_hp: int = 100
@export var mana: int = 50
@export var max_mana: int = 50
@export var stamina: int = 100
@export var max_stamina: int = 100
@export var prologue_termine: bool = false
@export var inventaire: Array[String] = []
@export var flags: Dictionary = {}

func _init() -> void:
	joueur_position = Vector3.ZERO
	hp = 100
	max_hp = 100
	mana = 50
	max_mana = 50
	stamina = 100
	max_stamina = 100
	prologue_termine = false
	inventaire = []
	flags = {}

# --- Sérialisation JSON ---

func to_json() -> String:
	var d: Dictionary = {
		"joueur_position": [joueur_position.x, joueur_position.y, joueur_position.z],
		"hp": hp,
		"max_hp": max_hp,
		"mana": mana,
		"max_mana": max_mana,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"prologue_termine": prologue_termine,
		"inventaire": inventaire,
		"flags": flags,
	}
	return JSON.stringify(d)

static func from_json(json_texte: String) -> GameData:
	var resultat: Variant = JSON.parse(json_texte)
	if typeof(resultat) != TYPE_DICTIONARY:
		push_err("game_data.from_json : JSON invalide")
		return null

	var d: Dictionary = resultat
	var data: GameData = GameData.new()

	data.joueur_position = Vector3(
		d.get("joueur_position", [0, 0, 0])[0],
		d.get("joueur_position", [0, 0, 0])[1],
		d.get("joueur_position", [0, 0, 0])[2]
	)
	data.hp = d.get("hp", 100)
	data.max_hp = d.get("max_hp", 100)
	data.mana = d.get("mana", 50)
	data.max_mana = d.get("max_mana", 50)
	data.stamina = d.get("stamina", 100)
	data.max_stamina = d.get("max_stamina", 100)
	data.prologue_termine = d.get("prologue_termine", false)
	data.inventaire = d.get("inventaire", [])
	data.flags = d.get("flags", {})

	return data

# --- Utilitaires ---

func ajouter_item(item: String) -> void:
	if item not in inventaire:
		inventaire.append(item)

func retirer_item(item: String) -> void:
	inventaire.erase(item)

def set_flag(flag: String, valeur: bool) -> void:
	flags[flag] = valeur

def get_flag(flag: String, defaut: bool = false) -> bool:
	return flags.get(flag, defaut)
