extends ObjectInteractable
@onready var sub_viewport = $"../SubViewport"
@onready var ecran_mesh = $".."

@onready var cash_register_ui: Control = null
@export var ticket_printer: Node3D

func _ready():
	# Configurer les groupes d'interaction
	add_to_group("ordinateur")
	add_to_group("script_interact")  # L'ordinateur contient les scripts d'interaction
	
	# Le mesh de l'écran doit être dans mesh_interact pour l'aura
	if ecran_mesh:
		ecran_mesh.add_to_group("mesh_interact")
	
	# attendre la fin du frame pour que le SubViewport contienne l'UI
	await get_tree().process_frame

	if sub_viewport and sub_viewport.get_child_count() > 0:
		cash_register_ui = sub_viewport.get_child(0) as Control
		cash_register_ui.connect("ticket_ready_to_print", _on_ticket_ready_to_print)
	else:
		print("❌ CashRegisterUI non trouvé dans le SubViewport")

func _input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if not cash_register_ui:
		return

	# Transformer le clic 3D sur le mesh en position 2D relative au SubViewport
	var local_pos = ecran_mesh.global_transform.affine_inverse() * event_position
	var plane_size = ecran_mesh.mesh.size
	var uv = Vector2(local_pos.x, local_pos.z) + plane_size / 2
	uv /= plane_size
	var mouse2D = uv * Vector2(sub_viewport.size)

	event.position = mouse2D
	sub_viewport.push_input(event)

func _on_ticket_ready_to_print(ticket_data: Dictionary):
		_create_ticket(ticket_data)

func _create_ticket(ticket_data: Dictionary):
	var ticket_scene = preload("res://scenes/Ticket.tscn")
	var ticket = ticket_scene.instantiate()
	
	# Le script est maintenant sur le MeshInstance, pas sur le nœud racine
	var ticket_script = ticket.get_node("MeshInstance")
	if ticket_script:
		ticket_script.set_ticket_data(ticket_data.type_personne, ticket_data.duree, ticket_data.parcours)
		print("🎫 Script de ticket trouvé et configuré!")
	else:
		push_error("🎫 ERREUR: Script de ticket non trouvé!")
	
	get_tree().current_scene.add_child(ticket)
	
	# Position de sortie du ticket
	var ticket_spawn_position: Vector3
	if ticket_printer:
		ticket_spawn_position = ticket_printer.global_position + Vector3(0, 0.2, 0)
		print("🎫 Utilisation du ticket_printer défini")
	else:
		# Position par défaut devant l'ordinateur
		ticket_spawn_position = global_position + Vector3(0.3, 0.3, 0.4)
		print("🎫 Utilisation de la position par défaut")
	
	ticket.global_position = ticket_spawn_position
	print("🎫 Position du ticket: ", ticket_spawn_position)
	
	# Donner une petite impulsion au RigidBody du ticket pour qu'il "sorte" de l'ordinateur
	# Le ticket est maintenant un RigidBody3D directement
	if ticket is RigidBody3D:
		ticket.apply_impulse(Vector3(0.5, 1.0, 0.2), Vector3.ZERO)
		print("🎫 Ticket imprimé et éjecté à la position: ", ticket.global_position)
		
		# Log après un court délai pour voir où il tombe
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(ticket):
			print("🎫 Position du ticket après 2s: ", ticket.global_position)
	else:
		push_error("🎫 ERREUR: Le ticket n'est pas un RigidBody3D!")

func get_camera_travel_params() -> Dictionary:
	return {
		"offset": Vector3(0, 1.5, 1.0), # ajuster selon l’écran
		"duration": 0.8,
		"look_at": ecran_mesh.global_position
	}

func get_interaction_label() -> String:
	var player = GlobalContext.player
	if player and player.current_state == player.State.ORDINATEUR:
		return "Quitter l'ordinateur"
	else:
		return "Utiliser l'ordinateur"

func object_interact() -> void:
	var player = GlobalContext.player
	if not player:
		return

	if player.current_state == player.State.ORDINATEUR:
		_exit_computer()
	else:
		_enter_computer()

func _enter_computer():
	var player = GlobalContext.player
	if not player:
		return
	
	# Vérifier qu'on n'est pas déjà en mode ordinateur
	if player.current_state == player.State.ORDINATEUR:
		print("🔒 Déjà en mode ordinateur")
		return
		
	player.current_state = player.State.ORDINATEUR
	GlobalContext.input_active = true
	GlobalContext.active_subviewport = sub_viewport
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Activer l'input sur le SubViewport
	sub_viewport.gui_disable_input = false
	
	# Masquer l'UI d'interaction du joueur
	if GlobalContext.ui_context:
		GlobalContext.ui_context.reset()
	
	# Masquer l'aura d'interaction si elle existe
	if player.last_aura_mesh:
		player.last_aura_mesh.visible = false
	
	# Réinitialiser la position de la souris pour le hover
	last_mouse_position = Vector2.ZERO
	
	# Afficher un message de confirmation
	if cash_register_ui:
		print("📱 Interface de caisse enregistreuse activée!")
		print("🖱️ La souris contrôle maintenant directement l'interface")
		print("🎯 Cliquez n'importe où sur l'écran pour interagir")
		print("✨ Hover des boutons activé!")
		print("⌨️ Appuyez sur E ou Échap pour quitter")
	
	print("📱 Entrée dans l'ordinateur")

func _exit_computer():
	var player = GlobalContext.player
	if not player:
		return
	
	# Vérifier qu'on est bien en mode ordinateur
	if player.current_state != player.State.ORDINATEUR:
		print("🔒 Pas en mode ordinateur")
		return
		
	player.current_state = player.State.NORMAL
	GlobalContext.input_active = false
	GlobalContext.active_subviewport = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Désactiver l'input sur le SubViewport
	sub_viewport.gui_disable_input = true
	
	# Restaurer la caméra
	player.restore_camera_to_player()
	
	# Masquer l'aura d'interaction au cas où
	if player.last_aura_mesh:
		player.last_aura_mesh.visible = false
	
	# Masquer le curseur de débogage
	if cash_register_ui and cash_register_ui.has_method("hide_debug_cursor"):
		cash_register_ui.hide_debug_cursor()
	
	print("📱 Sortie de l'ordinateur - retour au jeu normal")

func _handle_viewport_click(mouse_pos: Vector2, camera: Camera3D):
	# Nouveau système : calculer la projection de la souris sur l'interface
	var ui_pos = _calculate_screen_projection(mouse_pos, camera)
	
	if ui_pos != Vector2(-1, -1):  # Position valide
		_send_click_event(ui_pos)
	else:
		print("⚠️ Souris en dehors de la zone de l'écran")

func _debug_viewport_projection(mouse_pos: Vector2, camera: Camera3D):
	# Afficher le curseur de débogage
	var ui_pos = _calculate_screen_projection(mouse_pos, camera)
	
	if ui_pos != Vector2(-1, -1) and cash_register_ui:
		if cash_register_ui.has_method("debug_mouse_projection"):
			cash_register_ui.debug_mouse_projection(ui_pos)
	else:
		# Masquer le curseur si en dehors
		if cash_register_ui and cash_register_ui.has_method("hide_debug_cursor"):
			cash_register_ui.hide_debug_cursor()

func _handle_mouse_motion(mouse_pos: Vector2, camera: Camera3D):
	# Gérer les mouvements de souris pour le hover des boutons
	var ui_pos = _calculate_screen_projection(mouse_pos, camera)
	
	if ui_pos != Vector2(-1, -1):  # Position valide
		_send_motion_event(ui_pos)

var last_mouse_position: Vector2 = Vector2.ZERO

func _send_motion_event(pos: Vector2):
	if not sub_viewport:
		return
	
	# Calculer le mouvement relatif pour un hover plus fluide
	var relative_motion = pos - last_mouse_position
	last_mouse_position = pos
	
	# Créer un événement de mouvement de souris
	var motion_event = InputEventMouseMotion.new()
	motion_event.position = pos
	motion_event.relative = relative_motion
	
	# Envoyer l'événement au SubViewport
	sub_viewport.push_input(motion_event)
	
	# Optionnel : log pour déboguer le hover
	# print("🖱️ Motion event sent - pos: ", pos, " relative: ", relative_motion)

func _calculate_screen_projection(mouse_pos: Vector2, camera: Camera3D) -> Vector2:
	if not ecran_mesh or not sub_viewport:
		return Vector2(-1, -1)
	
	# Nouvelle approche : utiliser un raycast depuis la position de la souris
	# pour déterminer précisément où on frappe l'écran
	
	# Projeter un ray depuis la caméra vers la position de la souris
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 100.0  # Distance suffisante
	
	# Faire un raycast vers l'écran de l'ordinateur
	var space_state = camera.get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.collision_mask = 0xFFFFFFFF  # Tous les layers
	
	var result = space_state.intersect_ray(params)
	
	if not result:
		return Vector2(-1, -1)
	
	var collider = result.get("collider")
	if not collider or not collider.is_in_group("ordinateur"):
		return Vector2(-1, -1)
	
	# Point d'intersection 3D sur l'écran
	var hit_position = result.get("position")
	
	# Convertir ce point 3D en coordonnées 2D de l'interface
	var ui_pos = _convert_3d_hit_to_2d_interface(hit_position)
	
	print("🎯 Ray hit à: ", hit_position)
	print("🖱️ Mouse: ", mouse_pos)
	print("🎯 UI pos finale: ", ui_pos)
	
	return ui_pos

func _convert_3d_hit_to_2d_interface(hit_position: Vector3) -> Vector2:
	if not ecran_mesh or not sub_viewport:
		return Vector2(-1, -1)
	
	# Transformer le point 3D en coordonnées locales de l'écran
	var local_pos = ecran_mesh.global_transform.affine_inverse() * hit_position
	
	# Obtenir la taille du mesh de l'écran
	var mesh_size = Vector2(2.0, 2.0)  # Valeur par défaut pour PlaneMesh
	if ecran_mesh.mesh and ecran_mesh.mesh is PlaneMesh:
		mesh_size = ecran_mesh.mesh.size
	
	# Convertir en coordonnées UV (0-1)
	# L'écran est dans le plan XY local, Z=0
	var uv = Vector2(
		(local_pos.x + mesh_size.x / 2.0) / mesh_size.x,
		(local_pos.y + mesh_size.y / 2.0) / mesh_size.y
	)
	
	# Ajuster l'orientation selon l'écran (tester différentes orientations)
	uv.y = 1.0 - uv.y  # Inverser Y pour correspondre aux coordonnées UI
	
	# Vérifier si on est dans les limites de l'écran
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2(-1, -1)
	
	# Convertir en coordonnées de pixels du SubViewport
	var screen_pos = Vector2(
		uv.x * sub_viewport.size.x,
		uv.y * sub_viewport.size.y
	)
	
	print("📍 Local hit: ", local_pos)
	print("📏 Mesh size: ", mesh_size)
	print("🗺️ UV: ", uv)
	print("📺 Viewport size: ", sub_viewport.size)
	
	return screen_pos

func _get_screen_corners_3d() -> Array:
	# Calculer les 4 coins de l'écran en coordonnées 3D mondiales
	if not ecran_mesh:
		return []
	
	var mesh_size = Vector2(2.0, 2.0)  # Valeur par défaut pour PlaneMesh
	if ecran_mesh.mesh and ecran_mesh.mesh is PlaneMesh:
		mesh_size = ecran_mesh.mesh.size
	
	var half_x = mesh_size.x / 2.0
	var half_y = mesh_size.y / 2.0
	
	# Coins en coordonnées locales (ajustés pour l'orientation de l'écran)
	var local_corners = [
		Vector3(-half_x, half_y, 0),   # haut gauche
		Vector3(half_x, half_y, 0),    # haut droite  
		Vector3(half_x, -half_y, 0),   # bas droite
		Vector3(-half_x, -half_y, 0)   # bas gauche
	]
	
	# Convertir en coordonnées mondiales
	var world_corners = []
	for corner in local_corners:
		world_corners.append(ecran_mesh.global_transform * corner)
	
	return world_corners

func _send_click_event(pos: Vector2):
	if not sub_viewport:
		return
	
	# Créer un événement de clic souris
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = pos
	
	# Envoyer l'événement au SubViewport
	sub_viewport.push_input(click_event)
	
	# Créer aussi l'événement de relâchement
	var release_event = InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = pos
	
	sub_viewport.push_input(release_event)
	
	print("✅ Événement de clic envoyé à: ", pos)
