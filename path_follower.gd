extends VehicleBody3D
class_name PathFollower

# Suivi souple d'un Path3D avec rappel latéral (spring-damper),
# inertie et arrêt à la fin. On colle en XZ au chemin et on laisse la
# physique gérer la gravité (Y libre).

@export var path_3d: Path3D
@export var auto_find_path: bool = true

@export_group("Vitesse")
@export var max_speed: float = 1.39  # 5 km/h = 1.39 m/s
@export var acceleration_force: float = 200.0  # Réduit pour accélération douce
@export var brake_force: float = 500.0  # Réduit pour freinage doux

@export_group("Suivi souple")
@export var position_tolerance: float = 1.0
@export var lateral_stiffness: float = 60.0  # k du ressort latéral
@export var lateral_damping: float = 10.0    # c de l'amortisseur
@export var look_ahead_distance: float = 3.0 # m, point visé en avant
@export var orientation_lerp_speed: float = 0.1

var curve: Curve3D
var path_length: float = 0.0
var current_offset: float = 0.0
var is_following: bool = false
var has_reached_end: bool = false

func _ready():
	print("=== PATH_FOLLOWER INITIALISATION ===")
	print("Nom du véhicule: ", name)
	print("Position initiale: ", global_position)
	print("Visible: ", visible)
	print("auto_find_path: ", auto_find_path)
	print("path_3d assigné: ", path_3d)
	
	if auto_find_path and not path_3d:
		print("Recherche automatique du Path3D...")
		_find_path_3d()
	
	if path_3d:
		print("Path3D trouvé: ", path_3d.name)
		print("Position du Path3D: ", path_3d.global_position)
		_setup_path()
		_start_following()
	else:
		print("ERREUR: Aucun Path3D trouvé!")
		print("Veuillez assigner manuellement le Path3D dans l'inspecteur")

func _physics_process(delta):
	if not is_following or not curve or has_reached_end:
		return

	_update_progression(delta)
	_apply_lateral_correction(delta)
	_update_orientation()
	_apply_drive_and_stop()
	
	# Log de debug toutes les 60 frames (1 seconde)
	if Engine.get_process_frames() % 60 == 0:
		print("DEBUG - Position: ", global_position, " | Offset: ", current_offset, " | Vitesse: ", linear_velocity.length(), " | Suivi: ", is_following)

func _find_path_3d():
	print("Recherche du Path3D dans la hiérarchie...")
	var parent = get_parent()
	while parent and not path_3d:
		print("Recherche dans: ", parent.name)
		path_3d = parent.find_child("Path3D", false, false)
		if path_3d:
			print("Path3D trouvé: ", path_3d.name)
			break
		parent = parent.get_parent()
	
	if not path_3d:
		print("Aucun Path3D trouvé dans la hiérarchie")
		print("Recherche dans toute la scène...")
		var scene_root = get_tree().current_scene
		path_3d = scene_root.find_child("Path3D", false, false)
		if path_3d:
			print("Path3D trouvé dans la scène: ", path_3d.name)
		else:
			print("Aucun Path3D trouvé dans la scène")

func _setup_path():
	print("=== CONFIGURATION DU CHEMIN ===")
	curve = path_3d.curve
	if not curve:
		print("ERREUR: Le Path3D n'a pas de courbe!")
		return
	path_length = curve.get_baked_length()
	print("Longueur du chemin: ", path_length)
	current_offset = 0.0
	
	# Positionner en XZ sur le début du chemin, laisser Y tel quel
	var p0 = path_3d.global_position + curve.sample_baked(0.0)
	print("Position du début du chemin (global): ", p0)
	print("Position actuelle de la voiture: ", global_position)
	global_position = Vector3(p0.x, global_position.y, p0.z)
	print("Nouvelle position de la voiture: ", global_position)
	
	# S'assurer que la voiture est visible
	visible = true
	print("Visibilité forcée à true")

func _start_following():
	is_following = curve != null
	has_reached_end = false
	print("=== DÉMARRAGE DU SUIVI ===")
	print("Suivi activé: ", is_following)
	print("Courbe disponible: ", curve != null)

func _stop_following():
	is_following = false
	engine_force = 0
	brake = brake_force

func _update_progression(delta: float):
	# Avancer l'offset en fonction de la vitesse avant actuelle
	var forward_speed = linear_velocity.dot(-global_transform.basis.z)
	var speed = clamp(forward_speed, 0.0, max_speed)
	# Inverser la direction de progression
	current_offset -= speed * delta
	if current_offset <= 0:
		current_offset = 0
		has_reached_end = true

func _apply_lateral_correction(delta: float):
	# Point visé un peu en avant pour anticiper (direction inversée)
	var target_offset = clamp(current_offset - look_ahead_distance, 0.0, path_length)
	var path_point = path_3d.global_position + curve.sample_baked(target_offset)

	# Erreur latérale uniquement sur XZ pour laisser la gravité agir sur Y
	var current_pos = global_position
	var desired_pos = Vector3(path_point.x, current_pos.y, path_point.z)
	var lateral_error = desired_pos - current_pos

	# Vitesse latérale (projetée sur XZ)
	var lateral_velocity = Vector3(linear_velocity.x, 0.0, linear_velocity.z)

	# Force ressort-amortisseur
	var spring_force = lateral_error * lateral_stiffness
	var damper_force = -lateral_velocity * lateral_damping
	var correction = spring_force + damper_force

	# Appliquer la correction
	apply_central_force(correction)

	# Sécurité: si très loin, rapprocher doucement
	if lateral_error.length() > position_tolerance * 3.0:
		global_position = current_pos.lerp(desired_pos, 0.2)

func _update_orientation():
	# Direction inversée pour l'orientation
	var ahead_offset = clamp(current_offset - 1.0, 0.0, path_length)
	var pos_a = path_3d.global_position + curve.sample_baked(current_offset)
	var pos_b = path_3d.global_position + curve.sample_baked(ahead_offset)
	var dir = (pos_a - pos_b).normalized()  # Inversé pour aller dans le bon sens
	if dir.length() > 0.001:
		var target = Transform3D().looking_at(global_position + dir, Vector3.UP)
		target.origin = global_position
		transform = transform.interpolate_with(target, orientation_lerp_speed)

func _apply_drive_and_stop():
	if has_reached_end:
		engine_force = 0
		brake = brake_force
		return
	
	# Vérifier que les roues sont configurées
	var wheels = get_children().filter(func(child): return child is VehicleWheel3D)
	if wheels.size() == 0:
		print("ERREUR: Aucune roue trouvée sur le véhicule!")
		return
	
	# Contrôle de vitesse plus strict
	var current_speed = linear_velocity.length()
	if current_speed < max_speed:
		engine_force = acceleration_force
		brake = 0
	else:
		# Si on dépasse la vitesse max, freiner légèrement
		engine_force = 0
		brake = brake_force * 0.3

# Gardé pour compatibilité si d'autres scripts appellent ces noms
func calculate_target_speed():
	return

func apply_speed_control(_delta: float):
	return

# =============================================================================
# FONCTIONS PUBLIQUES
# =============================================================================

func set_path(new_path: Path3D):
	path_3d = new_path
	_setup_path()
	_start_following()

func get_progress() -> float:
	return 0.0

func get_remaining_distance() -> float:
	return 0.0

func is_at_end() -> bool:
	return false

func reset_to_start():
	if not curve:
		return
	current_offset = path_length  # Commencer à la fin du chemin (direction inversée)
	has_reached_end = false
	var p0 = path_3d.global_position + curve.sample_baked(path_length)
	global_position = Vector3(p0.x, global_position.y, p0.z)

# =============================================================================
# SIGNALS
# =============================================================================

signal path_started
signal path_completed
signal path_progress_changed(progress: float)
