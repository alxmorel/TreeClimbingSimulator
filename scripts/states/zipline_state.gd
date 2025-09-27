class_name ZiplineState
extends State

var zipline_start: Node3D = null
var zipline_end: Node3D = null
var zipline_direction: Vector3 = Vector3.ZERO
var zipline_speed: float = 8.0
var zipline_moving: bool = false

func enter() -> void:
	print("Entrée dans ZiplineState")
	player.velocity = Vector3.ZERO
	zipline_moving = false

func exit() -> void:
	print("Sortie de ZiplineState")
	zipline_start = null
	zipline_end = null
	zipline_direction = Vector3.ZERO
	zipline_moving = false

func physics_process(delta: float) -> void:
	player.velocity = Vector3.ZERO

	# 🔹 Si le joueur n'a pas encore commencé à glisser
	if not zipline_moving:
		# Vérifier interaction en continu
		player._check_interaction()

		# Début du mouvement uniquement si le joueur appuie sur "up"
		if Input.is_action_just_pressed("up"):
			print("[Tyro] Début zipline movement")
			zipline_moving = true

		# Bloquer le mouvement normal avant de démarrer
		player.move_and_slide()
		return

	# --- Déplacement le long du câble ---
	if zipline_moving:
		var closest_index = 0
		var min_dist_sq = INF
		for i in range(player.cable_tyro.joints.size()):
			var joint_pos = player.cable_tyro.joints[i].global_position
			var dist_sq = player.global_position.distance_squared_to(joint_pos)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest_index = i

		var next_index = clamp(closest_index + 1, 0, player.cable_tyro.joints.size() - 1)
		var joint_a = player.cable_tyro.joints[closest_index].global_position
		var joint_b = player.cable_tyro.joints[next_index].global_position
		var segment_dir = joint_b - joint_a
		var t_segment = 0.0
		if segment_dir.length() > 0.001:
			t_segment = ((player.global_position - joint_a).dot(segment_dir)) / segment_dir.length_squared()
			t_segment = clamp(t_segment, 0, 1)

		var cable_pos = joint_a.lerp(joint_b, t_segment)
		var cable_offset = Vector3(0, -1, 0)
		player.global_position = cable_pos + cable_offset

		# Calcul eased speed
		var total_distance = (zipline_end.global_position - zipline_start.global_position).length()
		var travelled = (player.global_position - zipline_start.global_position).length()
		var t = clamp(travelled / total_distance, 0, 1)

		var start_speed = 0.83
		var peak_speed  = 8.33
		var end_speed   = 2.78
		var eased_speed: float
		if t < 0.2:
			eased_speed = lerp(start_speed, peak_speed, t / 0.2)
		elif t < 0.8:
			eased_speed = peak_speed
		else:
			eased_speed = lerp(peak_speed, end_speed, (t - 0.8) / 0.2)

		player.global_position += zipline_direction * eased_speed * delta

		# Limiter entre start et end
		var to_start = zipline_start.global_position - player.global_position
		var to_end   = zipline_end.global_position - player.global_position
		if zipline_direction.dot(to_start) > 0:
			player.global_position = zipline_start.global_position
		elif zipline_direction.dot(to_end) < 0:
			player.global_position = zipline_end.global_position
			zipline_moving = false
			print("[Tyro] Fin zipline movement - joueur à la fin, attente interaction")

		player.move_and_slide()

func handle_input(event: InputEvent) -> void:
	# 🔹 Sortie : touche "interact" pour quitter la tyrolienne si immobile
	if Input.is_action_just_pressed("interact") and not zipline_moving:
		print("[Tyro] Interact pressed - exiting zipline")
		_exit_zipline()
	
	if Input.is_action_just_pressed("ui_cancel"): # touche Échap
		_exit_zipline()

func _exit_zipline() -> void:
	state_machine.change_state("normal")

func setup_zipline(cable: Node, start: Node3D, end: Node3D) -> void:
	zipline_start = start
	zipline_end = end
	zipline_direction = (end.global_position - start.global_position).normalized()

	# Chercher le joint le plus proche sur le cable_tyro
	var closest_index = 0
	var min_dist_sq = INF
	for i in range(player.cable_tyro.joints.size()):
		var joint_pos = player.cable_tyro.joints[i].global_position
		var dist_sq = player.global_position.distance_squared_to(joint_pos)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_index = i

	# Interpoler légèrement vers le joint suivant pour une position initiale plus naturelle
	var next_index = clamp(closest_index + 1, 0, player.cable_tyro.joints.size() - 1)
	var joint_a = player.cable_tyro.joints[closest_index].global_position
	var joint_b = player.cable_tyro.joints[next_index].global_position
	var t_segment = 0.5  # juste au milieu du segment pour démarrer
	var cable_pos = joint_a.lerp(joint_b, t_segment)

	# Décalage vertical pour être sous le câble
	var cable_offset = Vector3(0, -1, 0)
	player.global_position = cable_pos + cable_offset

	# Bloquer mouvements normaux
	player.velocity = Vector3.ZERO
	zipline_moving = false

	# Orienter la caméra dans l'axe de la tyrolienne
	var forward = zipline_direction
	var basis = Basis().looking_at(forward, Vector3.UP)
	player.head.global_transform.basis = basis
	player.camera.global_transform.basis = basis
	
	# 🔹 Vérifier l'UI une fois au début
	player._check_interaction()
