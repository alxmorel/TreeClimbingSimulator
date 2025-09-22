# object_interactable.gd
extends Node3D
class_name ObjectInteractable  # permet d'utiliser ObjectInteractable comme type dans Godot

# Retourne le texte que l'UI doit afficher pour cette interaction
func get_interaction_label() -> String:
	return "Interagir"

# Méthode appelée lors de l'interaction
func object_interact() -> void:
	# À surcharger dans les objets concrets
	pass
