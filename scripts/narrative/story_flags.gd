# -*- coding: utf-8 -*-
"""
story_flags.gd — Flags de progression narrative (prologue).

IMPORTANT (contrat avec l'auteur / CdC) :
- Ne PAS inclure de flags révélant l'origine des voix mystérieuses.
- Ne PAS inclure l'identité du dieu scellé.
- Ne PAS inclure les secrets des archives du premier royaume.
- Ces emplacements restent volontairement vides / commentés jusqu'à validation explicite de l'auteur.

Flags autorisés (prologue uniquement) :
- rencontre_garde : le protagoniste a rencontré le garde qui l'a élevé.
- academie_entree : entrée à l'académie d'épée (16 ans).
- epee_recue : l'épée ancienne du père adoptif a été récupérée.
- voix_entendues : le protagoniste a entendu les voix mystérieuses (origine inconnue).

À NE PAS AJOUTER sans autorisation : origine_voix, dieu_scele, secret_archives, identité_père_biologique, ...
"""

class_name StoryFlags
extends Resource

@export var rencontre_garde: bool = false
@export var academie_entree: bool = false
@export var epee_recue: bool = false
@export var voix_entendues: bool = false

# Emplacements réservés — NE PAS remplir sans validation de l'auteur.
# var origine_voix: bool = false          # INTERDIT sans validation
# var dieu_scele_connu: bool = false      # INTERDIT sans validation
# var secret_archives_devoile: bool = false  # INTERDIT sans validation

func _init() -> void:
	rencontre_garde = false
	academie_entree = false
	epee_recue = false
	voix_entendues = false

# Valider un flag narratif (appelé par le GameManager / niveau).
func valider(flag: String) -> void:
	match flag:
		"rencontre_garde": rencontre_garde = true
		"academie_entree": academie_entree = true
		"epee_recue": epee_recue = true
		"voix_entendues": voix_entendues = true
		_:
			push_warning("story_flags : flag non autorisé ou inconnu : " + flag)

func est_valide(flag: String) -> bool:
	match flag:
		"rencontre_garde": return rencontre_garde
		"academie_entree": return academie_entree
		"epee_recue": return epee_recue
		"voix_entendues": return voix_entendues
		_: return false
