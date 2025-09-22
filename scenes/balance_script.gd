extends Node3D

@export var tilt_angle: float = 90.0   # Angle max que la planche peut pencher à gauche ou à droite
@export var tilt_speed: float = 2   # Vitesse à laquelle la planche pivote vers l'angle cible

@onready var pivot = $"."               # Node pivot de la planche qui sera réellement tourné
@onready var area_3d = $Area3D

var target_tilt: float = 0.0           # Angle cible de la planche


func _process(delta):
	# Si le joueur n'existe pas, on ne fait rien
	if not GlobalContext.player:
		return

	var player = GlobalContext.player
	var player_pos = player.global_transform.origin  # Position globale du joueur

	# Transforme la position globale du joueur en position locale par rapport au pivot
	# => local_pos.x > 0 si joueur à droite du pivot
	# => local_pos.x < 0 si joueur à gauche du pivot
	var local_pos = pivot.to_local(player_pos)
	
	# Vérifie si le joueur touche l'Area3D
	# in_area = true si une partie du joueur est sur la planche
	var in_area = area_3d.get_overlapping_bodies().has(player)

	# Détermine l'angle cible du pivot en fonction de la position X du joueur
	if in_area:
		target_tilt = clamp(local_pos.z * tilt_angle, -tilt_angle, tilt_angle)
	else:
		target_tilt = 0.0

	# Interpolation douce : fait pivoter le pivot vers l'angle cible
	# Plus tilt_speed est grand, plus la planche réagit vite
	var current_rot = pivot.rotation_degrees
	current_rot.x = lerp(current_rot.x, target_tilt, tilt_speed * delta)
	pivot.rotation_degrees = current_rot
