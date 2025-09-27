class_name OrdinateurState
extends State

func enter() -> void:
	print("Entrée dans OrdinateurState")
	# Bloquer le mouvement du player
	player.velocity = Vector3.ZERO

func exit() -> void:
	print("Sortie de OrdinateurState")

func physics_process(delta: float) -> void:
	# Bloquer le mouvement du player
	player.velocity = Vector3.ZERO
	player.move_and_slide()

	# Gestion de l'interaction avec l'interface via raycast
	_handle_computer_interaction()

func handle_input(event: InputEvent) -> void:
	# Bloquer les mouvements de souris
	if event is InputEventMouseMotion:
		player.get_viewport().set_input_as_handled()
		return
	
	# Sortir de l'ordinateur via la touche E
	if Input.is_action_just_pressed("interact"):
		var ordinateur = player.get_tree().get_first_node_in_group("ordinateur")
		if ordinateur and ordinateur.has_method("_exit_computer"):
			ordinateur._exit_computer()
	
	# Sortir de l'ordinateur via Échap
	if Input.is_action_just_pressed("ui_cancel"):
		var ordinateur = player.get_tree().get_first_node_in_group("ordinateur")
		if ordinateur and ordinateur.has_method("_exit_computer"):
			ordinateur._exit_computer()

func _handle_computer_interaction():
	# Cette fonction gère l'interaction avec l'interface de l'ordinateur via raycast
	if not GlobalContext.active_subviewport:
		return
	
	# Envoyer les mouvements de souris pour le hover
	_send_mouse_motion_to_interface()
	
	# Détecter uniquement les clics souris pour l'interface (pas E)
	if Input.is_action_just_pressed("click"):
		_perform_computer_click()

func _perform_computer_click():
	# Nouveau système : projeter la souris sur la zone de l'écran visible dans la caméra
	if not GlobalContext.active_subviewport:
		return
	
	var ordinateur = player.get_tree().get_first_node_in_group("ordinateur")
	if not ordinateur or not ordinateur.has_method("_handle_viewport_click"):
		return
	
	var viewport = player.get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	
	ordinateur._handle_viewport_click(mouse_pos, player.camera)


func _send_mouse_motion_to_interface():
	# Envoyer les mouvements de souris pour activer le hover des boutons
	if not GlobalContext.active_subviewport:
		return
	
	var ordinateur = player.get_tree().get_first_node_in_group("ordinateur")
	if not ordinateur or not ordinateur.has_method("_handle_mouse_motion"):
		return
	
	var viewport = player.get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	
	ordinateur._handle_mouse_motion(mouse_pos, player.camera)
