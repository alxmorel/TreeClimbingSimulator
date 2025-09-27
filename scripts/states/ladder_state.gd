class_name LadderState
extends State

func enter() -> void:
	print("Entrée dans LadderState")
	player.velocity = Vector3.ZERO

func exit() -> void:
	print("Sortie de LadderState")

func physics_process(delta: float) -> void:
	# Neutralise gravité normale
	player.velocity = Vector3.ZERO
	
	# Gestion de la vitesse
	var speed = player.SPRINT_SPEED if Input.is_action_pressed("sprint") else player.WALK_SPEED

	# --- Coller le joueur contre l'échelle ---
	var ladder_center = player.global_transform.origin  # ou position de l'Area3D
	var offset = (ladder_center - player.global_transform.origin)
	offset.y = 0
	if offset.length() > 0.1:
		player.velocity.x = offset.normalized().x * speed
		player.velocity.z = offset.normalized().z * speed
	else:
		player.velocity.x = 0
		player.velocity.z = 0

	# --- Déplacement vertical selon la caméra ---
	var climb_speed = 3.0
	var descend_speed = 1.5

	# Direction avant de la caméra (XZ seulement)
	var cam_forward = get_camera_forward()
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()

	# Monter ou descendre selon input
	if Input.is_action_pressed("up"):
		player.velocity += cam_forward * climb_speed
		player.velocity.y = climb_speed
		if Input.is_action_pressed("sprint"):
			player.velocity *= 1.2  # montée accélérée
	elif Input.is_action_pressed("down"):
		player.velocity += -cam_forward * climb_speed
		player.velocity.y = -climb_speed
		if Input.is_action_pressed("crouch"):
			player.velocity *= 1.5  # descente accélérée
	else:
		player.velocity.y = -descend_speed  # descente automatique

	# Appliquer le mouvement
	player.move_and_slide()

func handle_input(event: InputEvent) -> void:
	# Sortie de l'échelle si saut
	if Input.is_action_just_pressed("jump"):
		state_machine.change_state("normal")
		player.velocity.y = player.JUMP_VELOCITY
	
	# Gestion de la souris pour rotation de la caméra
	if event is InputEventMouseMotion:
		# Yaw : tourner le corps entier
		player.rotate_y(-event.relative.x * player.SENSITIVITY)

		# Pitch : système robuste sans gimbal lock
		var pitch_delta = -event.relative.y * player.SENSITIVITY
		player.head_pitch += pitch_delta
		
		# Limites très étendues (presque 180°)
		player.head_pitch = clamp(player.head_pitch, deg_to_rad(-89.5), deg_to_rad(89.5))
		
		# Appliquer la rotation
		player.head.rotation.x = player.head_pitch
