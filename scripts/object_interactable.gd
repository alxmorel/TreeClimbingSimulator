# object_interactable.gd
extends Node3D
class_name ObjectInteractable  # permet d'utiliser ObjectInteractable comme type dans Godot

# Méthode pour récupérer les paramètres de travel caméra
func get_camera_travel_params() -> Dictionary:
	return {
		"offset": Vector3(0, 1.5, 2.0), # position relative depuis l'objet
		"duration": 0.8,
		"look_at": global_transform.origin + Vector3(0, 1.0, 0) # point que la caméra doit regarder
	}

# Méthode appelée lors de l'interaction
func object_interact() -> void:
	# À surcharger dans les objets concrets
	pass
