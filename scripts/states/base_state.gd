class_name State
extends RefCounted

var state_machine: StateMachine
var player: CharacterBody3D

# Méthodes virtuelles à override dans les états spécifiques
func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_process(delta: float) -> void:
	pass

func handle_input(event: InputEvent) -> void:
	pass

# Méthodes utilitaires communes à tous les états
func get_input_direction() -> Vector3:
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var horizontal_dir = Vector3(-input_dir.x, 0, -input_dir.y)
	horizontal_dir = (player.transform.basis * horizontal_dir)
	horizontal_dir.y = 0
	return horizontal_dir.normalized()

func get_camera_forward() -> Vector3:
	return -player.head.global_transform.basis.z

func apply_gravity(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y -= player.GRAVITY * delta

func apply_horizontal_movement(direction: Vector3, speed: float, delta: float) -> void:
	if player.is_on_floor():
		if direction:
			player.velocity.x = direction.x * speed
			player.velocity.z = direction.z * speed
		else:
			player.velocity.x = lerp(player.velocity.x, 0.0, delta * 7.0)
			player.velocity.z = lerp(player.velocity.z, 0.0, delta * 7.0)
	else:
		player.velocity.x = lerp(player.velocity.x, direction.x * speed, delta * 3.0)
		player.velocity.z = lerp(player.velocity.z, direction.z * speed, delta * 3.0)

func update_head_bob(delta: float) -> void:
	player.t_bob += delta * Vector3(player.velocity.x, 0, player.velocity.z).length() * float(player.is_on_floor())
	player.camera.transform.origin = player._headbob(player.t_bob)

func update_fov(delta: float) -> void:
	var velocity_clamped = clamp(Vector3(player.velocity.x, 0, player.velocity.z).length(), 0.5, player.SPRINT_SPEED * 2)
	var target_fov = player.BASE_FOV + player.FOV_CHANGE * velocity_clamped
	player.camera.fov = lerp(player.camera.fov, target_fov, delta * 8.0)
