extends Camera3D

# Paramètres de mouvement
const BASE_SPEED = 10.0
const ACCELERATION = 30.0
const FRICTION = 8.0
const BASE_MAX_SPEED = 15.0
const TURBO_MULTIPLIER = 2.5
const ALTITUDE_SPEED_FACTOR = 0.3  # Facteur pour ajuster vitesse selon altitude

# Paramètres d'altitude (zoom)
const MIN_ALTITUDE = 10.0
const MAX_ALTITUDE = 80.0
const ZOOM_SPEED = 5.0

# Variables de mouvement
var velocity = Vector3.ZERO
var target_altitude = 30.0

func _ready():
	# Configuration pour caméra perspective avec vue inclinée
	projection = PROJECTION_PERSPECTIVE
	fov = 75.0
	
	# Position et orientation initiales
	#position = Vector3(0, 30, -30)
	#rotation_degrees = Vector3(-45, 0, 0)
	target_altitude = position.y

func _input(event):
	if not current:
		return
		
	# Gestion du zoom avec la molette (altitude du drone)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()

func _physics_process(delta):
	if not current:
		return
		
	# Calculer la direction de mouvement basée sur les inputs
	var input_direction = Vector3.ZERO
	
	if Input.is_action_pressed("move_forward"):
		input_direction += Vector3.FORWARD
	if Input.is_action_pressed("move_back"):
		input_direction += Vector3.BACK
	if Input.is_action_pressed("move_left"):
		input_direction += Vector3.LEFT
	if Input.is_action_pressed("move_right"):
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
	
	# Mode turbo avec Shift
	var max_speed = BASE_MAX_SPEED * altitude_factor
	if Input.is_action_pressed("turbo"):
		max_speed *= TURBO_MULTIPLIER
	
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
	
	# Gestion smooth de l'altitude (zoom)
	if abs(position.y - target_altitude) > 0.1:
		position.y = lerp(position.y, target_altitude, ZOOM_SPEED * delta)

func zoom_in():
	target_altitude = max(MIN_ALTITUDE, target_altitude - ZOOM_SPEED)

func zoom_out():
	target_altitude = min(MAX_ALTITUDE, target_altitude + ZOOM_SPEED)

# Méthode pour réinitialiser la position de la caméra
func reset_position():
	position = Vector3(0, 30, -30)
	rotation_degrees = Vector3(-45, 0, 0)
	target_altitude = 30.0
	velocity = Vector3.ZERO
