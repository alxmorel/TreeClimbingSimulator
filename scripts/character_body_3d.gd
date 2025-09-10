extends CharacterBody3D

@export var camera : Camera3D

const WALK_SPEED = 3.0
const RUN_SPEED = 15.0
const JUMP_VELOCITY = 7

var input_dir : Vector2 = Vector2.ZERO
var is_running : bool

func _input(event):
	if event is InputEventMouseMotion:
		camera.rotation.y = lerp(camera.rotation.y, camera.rotation.y - event.relative.x * 0.05, 0.1)
		camera.rotation.x = lerp(camera.rotation.x, camera.rotation.x - event.relative.y * 0.05, 0.1)
		
	if event.is_action_pressed("sprint"):
		is_running = true
	
	if event.is_action_released("sprint"):
		is_running = false

	input_dir = Input.get_vector("left", "right", "forward", "backward")

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := (camera.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed = RUN_SPEED if is_running else WALK_SPEED

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
 
