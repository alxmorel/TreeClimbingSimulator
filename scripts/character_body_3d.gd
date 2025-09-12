extends CharacterBody3D

# --- Movement constants ---
var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.8
const GRAVITY = 9.8
const SENSITIVITY = 0.004

# --- Head bob ---
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob = 0.0

# --- FOV ---
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# --- Step climbing ---
const MAX_STEP_HEIGHT = 0.4

# --- Ladder ---
enum State {
	NORMAL,
	LADDER
}
var current_state = State.NORMAL
var ladder_velocity = Vector3.ZERO

@onready var head = $Head
@onready var camera = $Head/Camera3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	 # Récupérer toutes les Area3D marquées comme ladder
	for ladder_area in get_tree().get_nodes_in_group("Ladders"):
		ladder_area.connect("body_entered", Callable(self, "_on_ladder_area_body_entered"))
		ladder_area.connect("body_exited", Callable(self, "_on_ladder_area_body_exited"))


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))

func _physics_process(delta):
	# --- Handle speed ---
	speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED

	# --- Get input ---
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var horizontal_dir = Vector3(input_dir.x, 0, input_dir.y)
	horizontal_dir = (head.transform.basis * horizontal_dir)
	horizontal_dir.y = 0
	horizontal_dir = horizontal_dir.normalized()
	
	
	if current_state == State.LADDER:
		# Neutralise gravité normale
		velocity = Vector3.ZERO

		# --- Coller le joueur contre l'échelle ---
		var ladder_center = global_transform.origin  # ou position de l'Area3D
		var offset = (ladder_center - global_transform.origin)
		offset.y = 0
		if offset.length() > 0.1:
			velocity.x = offset.normalized().x * speed
			velocity.z = offset.normalized().z * speed
		else:
			velocity.x = 0
			velocity.z = 0

		# --- Déplacement vertical selon la caméra ---
		var climb_speed = 3.0
		var descend_speed = 1.5

		# Direction avant de la caméra (XZ seulement)
		var cam_forward = -head.global_transform.basis.z
		cam_forward.y = 0
		cam_forward = cam_forward.normalized()

		# Monter ou descendre selon input
		if Input.is_action_pressed("up"):
			velocity += cam_forward * climb_speed
			velocity.y = climb_speed
			if Input.is_action_pressed("sprint"):
				velocity *= 1.2  # montée accélérée
		elif Input.is_action_pressed("down"):
			velocity += -cam_forward * climb_speed
			velocity.y = -climb_speed
			if Input.is_action_pressed("crouch"):
				velocity *= 1.5  # descente accélérée
		else:
			velocity.y = -descend_speed  # descente automatique

		# Appliquer le mouvement
		move_and_slide()

		# Sortie de l'échelle si saut
		if Input.is_action_just_pressed("jump"):
			current_state = State.NORMAL
			velocity.y = JUMP_VELOCITY

		return


	# --- Normal gravity & jumping ---
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	# --- Horizontal movement ---
	var direction = (head.transform.basis * transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, 0.0, delta * 7.0)
			velocity.z = lerp(velocity.z, 0.0, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)

	# --- Head bob ---
	t_bob += delta * Vector3(velocity.x, 0, velocity.z).length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)

	# --- FOV ---
	var velocity_clamped = clamp(Vector3(velocity.x, 0, velocity.z).length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	# --- Step climbing ---
	if not snap_up_step(delta):
		move_and_slide()


func snap_up_step(delta: float) -> bool:
	if not is_on_floor() or velocity.y > 0 or (velocity * Vector3(1,0,1)).length() == 0:
		return false

	var expected_motion = velocity * Vector3(1,0,1) * delta
	var test_origin = global_transform.translated(expected_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))

	var collision = KinematicCollision3D.new()
	if test_move(test_origin, Vector3(0, -MAX_STEP_HEIGHT * 2, 0), collision):
		var step_height = ((test_origin.origin + collision.get_travel()) - global_position).y
		if step_height <= 0.01 or step_height > MAX_STEP_HEIGHT:
			return false
		global_position = test_origin.origin + collision.get_travel()
		apply_floor_snap()
		return true

	return false

# --- Head bob function ---
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

# --- Ladder detection ---
func _on_ladder_area_body_entered(body):
	
	print("Body entered in ladder area 3D")

	if body == self:
		current_state = State.LADDER

func _on_ladder_area_body_exited(body):
	
	print("Body exited ladder area 3D")
	
	if body == self:
		current_state = State.NORMAL
