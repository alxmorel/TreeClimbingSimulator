class_name NormalState
extends State

func enter() -> void:
	print("Entrée dans NormalState")

func exit() -> void:
	print("Sortie de NormalState")

func physics_process(delta: float) -> void:
	# Gestion de la vitesse
	var speed = player.SPRINT_SPEED if Input.is_action_pressed("sprint") else player.WALK_SPEED
	
	# Direction de mouvement
	var direction = get_input_direction()
	
	# Gravité et saut
	apply_gravity(delta)
	if player.is_on_floor() and Input.is_action_just_pressed("jump"):
		player.velocity.y = player.JUMP_VELOCITY
	
	# Mouvement horizontal
	apply_horizontal_movement(direction, speed, delta)
	
	# Head bob
	update_head_bob(delta)
	
	# FOV
	update_fov(delta)
	
	# Step climbing
	if not player.snap_up_step(delta):
		player.move_and_slide()
	
	# Vérification des interactions
	player._check_interaction()

func handle_input(event: InputEvent) -> void:
	# Gestion des interactions
	if Input.is_action_just_pressed("interact"):
		player._perform_interaction()
	
	# Relâcher un ticket avec la touche a
	if Input.is_action_just_pressed("drop_ticket") and player.held_ticket:
		player._release_ticket()
	
	# Toggle téléphone
	if event.is_action_pressed("toggle_phone"):
		player._toggle_phone()
	
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
