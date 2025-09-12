extends Camera3D

# Paramètres de mouvement
const BASE_SPEED = 10.0
const ACCELERATION = 30.0
const FRICTION = 8.0
const BASE_MAX_SPEED = 15.0
const SPRINT_MULTIPLIER = 2.5
const ALTITUDE_SPEED_FACTOR = 0.3  # Facteur pour ajuster vitesse selon altitude

# Paramètres d'altitude (zoom)
const MIN_ALTITUDE = 10.0
const MAX_ALTITUDE = 80.0
const ZOOM_SPEED = 8.0  # Augmenté pour un zoom plus fluide

# Variables de mouvement
var velocity = Vector3.ZERO
var target_altitude = 30.0

# Référence au joueur pour le positionnement initial
var player_controller: CharacterBody3D

func _ready():
	# Configuration pour caméra perspective avec vue inclinée
	projection = PROJECTION_PERSPECTIVE
	fov = 75.0
	
	# Trouver le joueur dans la scène
	player_controller = get_node_or_null("../CharacterBody3D")
	if not player_controller:
		# Essayer de le trouver dans la scène racine
		var scene_root = get_tree().current_scene
		player_controller = scene_root.get_node_or_null("CharacterBody3D")
	
	# Position et orientation initiales
	#position = Vector3(0, 30, -30)
	#rotation_degrees = Vector3(-45, 0, 0)
	target_altitude = position.y

func _input(event):
	if not current:
		return
		
	# Suppression de la gestion du zoom avec la molette
	# Le zoom se fait maintenant avec Ctrl dans _physics_process

func _physics_process(delta):
	if not current:
		return
	
	# Si la caméra vient d'être activée, se positionner derrière le joueur
	if current and player_controller:
		# Vérifier si c'est la première frame d'activation
		if not has_meta("was_active"):
			position_behind_player()
			set_meta("was_active", true)
	elif not current and has_meta("was_active"):
		# La caméra a été désactivée, retirer le flag
		remove_meta("was_active")
		
	# Calculer la direction de mouvement basée sur les inputs
	var input_direction = Vector3.ZERO
	
	if Input.is_action_pressed("up"):
		input_direction += Vector3.FORWARD
	if Input.is_action_pressed("down"):
		input_direction += Vector3.BACK
	if Input.is_action_pressed("left"):
		input_direction += Vector3.LEFT
	if Input.is_action_pressed("right"):
		input_direction += Vector3.RIGHT
	
	# Normaliser la direction pour éviter mouvement plus rapide en diagonal
	input_direction = input_direction.normalized()
	
	# Appliquer le mouvement dans l'espace local de la caméra (pour respecter la rotation)
	var world_direction = transform.basis * input_direction
	# On ne veut pas de mouvement vertical avec ZQSD
	world_direction.y = 0
	world_direction = world_direction.normalized()
	
	# Calculer la vitesse en fonction de l'altitude (plus haut = plus rapide)
	var altitude_factor = 1.0 + (position.y - MIN_ALTITUDE) * ALTITUDE_SPEED_FACTOR / (MAX_ALTITUDE - MIN_ALTITUDE)
	var current_acceleration = ACCELERATION * altitude_factor
	
	# Mode turbo avec une autre touche (par exemple Alt)
	var max_speed = BASE_MAX_SPEED * altitude_factor
	if Input.is_key_pressed(KEY_ALT):
		max_speed *= SPRINT_MULTIPLIER
	
	# Système d'inertie
	if world_direction.length() > 0:
		# Accélération quand il y a un input
		velocity += world_direction * current_acceleration * delta
	else:
		# Friction quand pas d'input
		velocity = velocity.lerp(Vector3.ZERO, FRICTION * delta)
	
	# Limiter la vitesse maximale
	velocity = velocity.limit_length(max_speed)
	
	# Appliquer le mouvement
	position += velocity * delta
	
	# Gestion du zoom progressif avec Ctrl et Shift
	if Input.is_key_pressed(KEY_CTRL):
		# Zoom in (descendre) avec Ctrl
		target_altitude = max(MIN_ALTITUDE, target_altitude - ZOOM_SPEED * delta)
	elif Input.is_key_pressed(KEY_SHIFT):
		# Zoom out (monter) avec Shift
		target_altitude = min(MAX_ALTITUDE, target_altitude + ZOOM_SPEED * delta)
	
	# Gestion smooth de l'altitude (zoom)
	if abs(position.y - target_altitude) > 0.1:
		position.y = lerp(position.y, target_altitude, ZOOM_SPEED * delta)

func zoom_in():
	target_altitude = max(MIN_ALTITUDE, target_altitude - ZOOM_SPEED)

func zoom_out():
	target_altitude = min(MAX_ALTITUDE, target_altitude + ZOOM_SPEED)

# Méthode pour positionner la caméra derrière le joueur
func position_behind_player():
	if not player_controller:
		print("Erreur: Player controller non trouvé pour le positionnement de la caméra")
		return
	
	# Trouver la caméra du joueur
	var player_camera = player_controller.get_node_or_null("Head/Camera3D")
	if not player_camera:
		player_camera = player_controller.get_node_or_null("Camera3D")
	
	if not player_camera:
		print("Erreur: Caméra du joueur non trouvée")
		return
	
	# Obtenir la position et la direction de la caméra du joueur
	var player_cam_pos = player_camera.global_position
	var player_cam_forward = -player_camera.global_transform.basis.z  # Direction vers l'avant de la caméra
	
	# Calculer la position derrière le joueur par rapport à la direction de sa caméra
	var distance_behind = 15.0  # Distance derrière le joueur
	var height_offset = 20.0    # Hauteur au-dessus du joueur
	
	# Position de la caméra builder (derrière le joueur dans la direction opposée à sa caméra)
	var camera_pos = player_cam_pos - player_cam_forward * distance_behind
	camera_pos.y += height_offset
	
	# Positionner la caméra builder
	position = camera_pos
	target_altitude = camera_pos.y
	
	# Orienter la caméra builder dans la même direction que la caméra du joueur
	# mais avec un angle plus incliné vers le bas pour une vue top-down
	var look_direction = player_cam_forward
	look_direction.y = -0.7  # Incliner plus vers le bas (était -0.3)
	look_direction = look_direction.normalized()
	
	var look_at_pos = camera_pos + look_direction * 10.0
	look_at(look_at_pos, Vector3.UP)
	
	# Réinitialiser la vélocité
	velocity = Vector3.ZERO
	
	print("Caméra builder positionnée derrière le joueur à: ", position)
	print("Direction de la caméra joueur: ", player_cam_forward)
	print("Direction de la caméra builder: ", look_direction)

# Méthode pour réinitialiser la position de la caméra
func reset_position():
	position = Vector3(0, 30, -30)
	rotation_degrees = Vector3(-45, 0, 0)
	target_altitude = 30.0
	velocity = Vector3.ZERO
