extends CharacterBody3D

@export var data: Personne
@onready var skeleton = $Skeleton3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var telephone_avis_ui = $"../TelephoneUI/telephone_avis_ui"

@onready var head = $Skeleton3D/HeadCam
@onready var camera = $Skeleton3D/HeadCam/Camera3D
@onready var cable_tyro = %CableTyro

# --- Movement constants ---
var speed
const WALK_SPEED = 3.0
const SPRINT_SPEED = 7.0
const JUMP_VELOCITY = 4.8
const GRAVITY = 9.8
const SENSITIVITY = 0.004

# --- Head bob ---
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob = 0.0

# --- Rotation robuste de la tête ---
var head_pitch: float = 0.0  # Stockage séparé de l'angle de pitch

# --- FOV ---
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# --- Step climbing ---
const MAX_STEP_HEIGHT = 0.4

# --- Ladder ---
enum State {
	NORMAL,
	LADDER,
	ZIPLINE,
	ORDINATEUR
}

# ===== SYSTÈME DE TICKETS =====
var held_ticket: Node = null
var ticket_ui_position: Vector3 = Vector3(0.4, -0.3, -1.0)  # Position relative à la caméra (légèrement à droite et en bas du centre)

# Animation du ticket
var ticket_animating: bool = false
var ticket_start_transform: Transform3D
var ticket_target_transform: Transform3D
var ticket_animation_t: float = 0.0
var ticket_animation_duration: float = 1.0

var current_state = State.NORMAL
var ladder_velocity = Vector3.ZERO

var last_aura_mesh: MeshInstance3D = null 
var interact_distance = 3.0

var camera_traveling: bool = false
var camera_start_transform: Transform3D
var camera_target_transform: Transform3D
var camera_travel_t: float = 0.0
var camera_travel_duration: float = 0.8
var camera_target_look_at: Vector3

var camera_original_transform: Transform3D
var camera_original_look_at: Vector3

var camera_return_requested: bool = false


var zipline_start: Node3D = null
var zipline_end: Node3D = null
var zipline_direction: Vector3 = Vector3.ZERO
var zipline_speed: float = 8.0
var zipline_moving: bool = false

var phone_visible: bool = false


func _ready():
	if data:
		apply_style(data)
		play_idle()
	GlobalContext.player = self
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Initialiser la rotation de tête
	head_pitch = head.rotation.x
	
	# S'assurer que la tête et la caméra gardent leur orientation initiale
	# Pas de reset - on garde l'orientation de spawn
	
	 # Récupérer toutes les Area3D marquées comme ladder
	for ladder_area in get_tree().get_nodes_in_group("Ladders"):
		ladder_area.connect("body_entered", Callable(self, "_on_ladder_area_body_entered"))
		ladder_area.connect("body_exited", Callable(self, "_on_ladder_area_body_exited"))

func _physics_process(delta):
	# Gestion de l'animation du ticket
	if ticket_animating and held_ticket:
		ticket_animation_t += delta / ticket_animation_duration
		ticket_animation_t = clamp(ticket_animation_t, 0, 1)
		
		var ticket_rigidbody = held_ticket.get_parent()
		if ticket_rigidbody:
			# Animation fluide vers la position cible (utilisation des transforms locaux)
			var eased_t = ease_out_cubic(ticket_animation_t)
			ticket_rigidbody.transform = ticket_start_transform.interpolate_with(ticket_target_transform, eased_t)
			
			if ticket_animation_t >= 1.0:
				ticket_animating = false
				# Animation terminée - le ticket est déjà attaché à la caméra
				print("🎫 Animation terminée - ticket au centre de l'écran et suit parfaitement la caméra")
	
	# Mise à jour continue pour que le ticket reste toujours devant le joueur
	if held_ticket and not ticket_animating:
		_update_ticket_forward_position()
	
	if camera_traveling:
		camera_travel_t += delta / camera_travel_duration
		camera_travel_t = clamp(camera_travel_t, 0, 1)

		# Lerp position
		camera.global_transform.origin = camera_start_transform.origin.lerp(camera_target_transform.origin, camera_travel_t)

		# Slerp orientation vers le look_at
		var desired_forward = (camera_target_look_at - camera.global_transform.origin).normalized()
		var new_basis = Basis().looking_at(desired_forward, Vector3.UP)
		camera.global_transform.basis = camera_start_transform.basis.slerp(new_basis, camera_travel_t)

		if camera_travel_t >= 1.0:
			camera_traveling = false

			# --- Ne restaurer input & souris que si on n'est PAS en mode ordinateur ---
			if current_state != State.ORDINATEUR:
				GlobalContext.input_active = false
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

			# Si une interaction était en attente et qu'on n'est pas en mode ordinateur
			if GlobalContext.pending_interaction and current_state != State.ORDINATEUR:
				GlobalContext.pending_interaction.object_interact()
				GlobalContext.pending_interaction = null

	# --- Bloquer gameplay si input texte actif ---
	if GlobalContext.input_active:
		return
		
	# --- Handle speed ---
	speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED

	# --- Get input ---
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var horizontal_dir = Vector3(-input_dir.x, 0, -input_dir.y) # 🔹 inversion des axes clavier
	horizontal_dir = (transform.basis * horizontal_dir) # Utiliser la base du corps, pas de la tête
	horizontal_dir.y = 0
	horizontal_dir = horizontal_dir.normalized()
	
	
	if current_state == State.ZIPLINE:
		velocity = Vector3.ZERO

		# 🔹 Si le joueur n'a pas encore commencé à glisser
		if not zipline_moving:
			# Vérifier interaction en continu
			_check_interaction()

			# Début du mouvement uniquement si le joueur appuie sur "up"
			if Input.is_action_just_pressed("up"):
				print("[Tyro] Début zipline movement")
				zipline_moving = true

			# Bloquer le mouvement normal avant de démarrer
			move_and_slide()
			return

		# --- Déplacement le long du câble ---
		if zipline_moving:
			var closest_index = 0
			var min_dist_sq = INF
			for i in range(cable_tyro.joints.size()):
				var joint_pos = cable_tyro.joints[i].global_position
				var dist_sq = global_position.distance_squared_to(joint_pos)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_index = i

			var next_index = clamp(closest_index + 1, 0, cable_tyro.joints.size() - 1)
			var joint_a = cable_tyro.joints[closest_index].global_position
			var joint_b = cable_tyro.joints[next_index].global_position
			var segment_dir = joint_b - joint_a
			var t_segment = 0.0
			if segment_dir.length() > 0.001:
				t_segment = ((global_position - joint_a).dot(segment_dir)) / segment_dir.length_squared()
				t_segment = clamp(t_segment, 0, 1)

			var cable_pos = joint_a.lerp(joint_b, t_segment)
			var cable_offset = Vector3(0, -1, 0)
			global_position = cable_pos + cable_offset

			# Calcul eased speed
			var total_distance = (zipline_end.global_position - zipline_start.global_position).length()
			var travelled = (global_position - zipline_start.global_position).length()
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

			global_position += zipline_direction * eased_speed * delta

			# Limiter entre start et end
			var to_start = zipline_start.global_position - global_position
			var to_end   = zipline_end.global_position - global_position
			if zipline_direction.dot(to_start) > 0:
				global_position = zipline_start.global_position
			elif zipline_direction.dot(to_end) < 0:
				global_position = zipline_end.global_position
				zipline_moving = false
				print("[Tyro] Fin zipline movement - joueur à la fin, attente interaction")

			move_and_slide()

		# 🔹 Sortie : touche "interact" pour quitter la tyrolienne si immobile
		if Input.is_action_just_pressed("interact") and not zipline_moving:
			print("[Tyro] Interact pressed - exiting zipline")
			_exit_zipline()

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

	
	if current_state == State.ORDINATEUR:
		# Bloquer le mouvement du player
		velocity = Vector3.ZERO
		move_and_slide()

		# Gestion de l'interaction avec l'interface via raycast
		_handle_computer_interaction()

		return
		

	# --- Normal gravity & jumping ---
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	# --- Horizontal movement ---
	var direction = (transform.basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()


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
		
	# --- Interaction Raycast (sauf en mode ordinateur) ---
	if current_state != State.ORDINATEUR:
		_check_interaction()


func apply_style(p: Personne):
	# Corps
	var body = skeleton.get_node("Body") if skeleton.has_node("Body") else null
	if body:
		var mat = body.get_active_material(0).duplicate()
		mat.albedo_color = p.couleur_peau
		body.set_surface_override_material(0, mat)
	
	var head = skeleton.get_node("Head") if skeleton.has_node("Head") else null
	if head:	
		var mat = head.get_active_material(0).duplicate()
		mat.albedo_color = p.couleur_peau
		body.set_surface_override_material(0, mat)	
		
	# Haut
	var top = skeleton.get_node("Tops") if skeleton.has_node("Tops") else null
	if top:
		var mat = top.get_active_material(0).duplicate()
		mat.albedo_color = p.couleur_haut
		top.set_surface_override_material(0, mat)
	# Bas
	var bottom = skeleton.get_node("Bottoms") if skeleton.has_node("Bottoms") else null
	if bottom:
		var mat = bottom.get_active_material(0).duplicate()
		mat.albedo_color = p.couleur_bas
		bottom.set_surface_override_material(0, mat)
	# Chaussures
	var shoes = skeleton.get_node("Shoes") if skeleton.has_node("Shoes") else null
	if shoes:
		var mat = shoes.get_active_material(0).duplicate()
		mat.albedo_color = p.couleur_chaussures
		shoes.set_surface_override_material(0, mat)
	# Cheveux
	var hair = skeleton.get_node("Hair") if skeleton.has_node("Hair") else null
	if hair:
		var mat = hair.get_active_material(0).duplicate()
		mat.albedo_color = p.couleur_cheveux
		hair.set_surface_override_material(0, mat)


func start_zipline(cable: Node, start: Node3D, end: Node3D) -> void:
	current_state = State.ZIPLINE
	zipline_start = start
	zipline_end = end
	zipline_direction = (end.global_position - start.global_position).normalized()

	# Chercher le joint le plus proche sur le cable_tyro
	var closest_index = 0
	var min_dist_sq = INF
	for i in range(cable_tyro.joints.size()):
		var joint_pos = cable_tyro.joints[i].global_position
		var dist_sq = global_position.distance_squared_to(joint_pos)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_index = i

	# Interpoler légèrement vers le joint suivant pour une position initiale plus naturelle
	var next_index = clamp(closest_index + 1, 0, cable_tyro.joints.size() - 1)
	var joint_a = cable_tyro.joints[closest_index].global_position
	var joint_b = cable_tyro.joints[next_index].global_position
	var t_segment = 0.5  # juste au milieu du segment pour démarrer
	var cable_pos = joint_a.lerp(joint_b, t_segment)

	# Décalage vertical pour être sous le câble
	var cable_offset = Vector3(0, -1, 0)
	global_position = cable_pos + cable_offset

	# Bloquer mouvements normaux
	velocity = Vector3.ZERO
	zipline_moving = false

	# Orienter la caméra dans l'axe de la tyrolienne
	var forward = zipline_direction
	var basis = Basis().looking_at(forward, Vector3.UP)
	head.global_transform.basis = basis
	camera.global_transform.basis = basis
	
	# 🔹 Vérifier l’UI une fois au début
	_check_interaction()
	

func travel_camera_to(target_node: ObjectInteractable) -> void:
	if camera_traveling:
		return

	var params = target_node.get_camera_travel_params()
	var offset = params.offset
	var duration = params.duration
	var look_at = params.look_at

	# Stocker l'état original de la caméra (position relative à la tête)
	camera_original_transform = camera.transform  # Transform local, pas global
	camera_original_look_at = camera_target_look_at

	camera_start_transform = camera.global_transform

	# Calcul de la position finale
	var target_pos = target_node.global_transform.origin - target_node.global_transform.basis.z * offset.z
	target_pos.y += offset.y

	camera_target_transform = Transform3D(camera.global_transform.basis, target_pos)

	camera_travel_t = 0.0
	camera_traveling = true
	camera_travel_duration = duration
	camera_target_look_at = look_at
	camera_return_requested = false

	GlobalContext.input_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	print("📱 Caméra sauvegardée - transform local: ", camera_original_transform)


func play_idle():
	if anim_player.has_animation("Idle"):
		anim_player.play("Idle")

func _unhandled_input(event):
	# --- Bloquer gameplay si un input texte est actif ---
	if GlobalContext.input_active:
		if event is InputEventMouseMotion or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			return
	
	# --- Bloquer les mouvements de souris si on est en mode ordinateur ---
	if current_state == State.ORDINATEUR:
		if event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
			return
	
	if event is InputEventMouseMotion:
		# --- Yaw : tourner le corps entier ---
		rotate_y(-event.relative.x * SENSITIVITY)

		# --- Pitch : système robuste sans gimbal lock ---
		var pitch_delta = -event.relative.y * SENSITIVITY  # Inversion haut/bas souris
		head_pitch += pitch_delta
		
		# Limites très étendues (presque 180°)
		head_pitch = clamp(head_pitch, deg_to_rad(-89.5), deg_to_rad(89.5))
		
		# Appliquer la rotation tout en préservant l'orientation Y et Z initiales de la tête
		head.rotation.x = head_pitch
		# On utilise rotation.x directement pour éviter les resets de quaternions
	
	# --- Interaction / Quitter Tyrolienne ---
	if Input.is_action_just_pressed("interact"):
		if current_state == State.ZIPLINE:
			_exit_zipline()
		elif current_state == State.ORDINATEUR:
			# Sortir de l'ordinateur via la touche E
			var ordinateur = get_tree().get_first_node_in_group("ordinateur")
			if ordinateur and ordinateur.has_method("_exit_computer"):
				ordinateur._exit_computer()
		else:
			_perform_interaction()

	if Input.is_action_just_pressed("ui_cancel"): # touche Échap
		if current_state == State.ZIPLINE:
			_exit_zipline()
		elif current_state == State.ORDINATEUR:
			# Sortir de l'ordinateur via Échap
			var ordinateur = get_tree().get_first_node_in_group("ordinateur")
			if ordinateur and ordinateur.has_method("_exit_computer"):
				ordinateur._exit_computer()
	
	# Relâcher un ticket avec la touche G
	if Input.is_action_just_pressed("drop_ticket") and held_ticket:
		_release_ticket()
			
	if event.is_action_pressed("toggle_phone"):
		_toggle_phone()

func _exit_zipline() -> void:
	current_state = State.NORMAL
	velocity = Vector3.ZERO

func _toggle_phone():
	phone_visible = !phone_visible
	telephone_avis_ui.visible = phone_visible
	
	if phone_visible:
		GlobalContext.input_active = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if anim_player.has_animation("TakePhone"):
			anim_player.play("TakePhone")
	else:
		GlobalContext.input_active = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if anim_player.has_animation("PutPhone"):
			anim_player.play("PutPhone")


var last_detected_collider: Node = null  # Variable pour éviter le spam

func _check_interaction() -> void:
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_transform.origin
	var to = from + -camera.global_transform.basis.z * interact_distance

	var params = PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.exclude = [self]

	var result = space_state.intersect_ray(params)

	# Masquer l'aura par défaut
	if last_aura_mesh:
		last_aura_mesh.visible = false

	if result:
		var collider = result.get("collider")
		if collider:			
			# Afficher le log seulement si c'est un nouveau collider ou si c'est un ticket
			if collider != last_detected_collider or collider.name == "CollisionShape3D":
				last_detected_collider = collider
			
			if collider.is_in_group("interactable"):
				
				# 1. TROUVER LA RACINE DE LA SCÈNE INTERACTIVE
				var scene_root = _find_scene_root(collider)
				
				# 2. CHERCHER LE MESH pour l'aura d'abord
				var mesh_node: MeshInstance3D = null
				if scene_root:
					mesh_node = _find_mesh_interact(scene_root)

				# Créer l'aura si on a trouvé le mesh, mais pas pour le ticket tenu
				var is_held_ticket = false
				if held_ticket and scene_root:
					# Vérifier si l'objet détecté est le ticket actuellement tenu
					var ticket_parent = held_ticket.get_parent()
					if ticket_parent and (scene_root == ticket_parent or scene_root.is_ancestor_of(ticket_parent) or ticket_parent.is_ancestor_of(scene_root)):
						is_held_ticket = true
				
				if mesh_node and mesh_node.mesh and not is_held_ticket:
					if not last_aura_mesh:
						last_aura_mesh = MeshInstance3D.new()
						last_aura_mesh.mesh = mesh_node.mesh
						last_aura_mesh.material_override = preload("res://materials/InteractableAuraMaterial.tres")
						get_tree().current_scene.add_child(last_aura_mesh)

					# Positionner et afficher l'aura
					last_aura_mesh.global_transform = mesh_node.global_transform
					last_aura_mesh.visible = true

				# 3. CHERCHER LE SCRIPT pour l'interaction avec priorité
				var script_node: Node = null
				if scene_root:
					script_node = _find_script_interact_with_priority(scene_root)

				# Afficher le label depuis le script
				if GlobalContext.ui_context:
					GlobalContext.ui_context.update_key_action("E")
					if script_node and script_node.has_method("get_interaction_label"):
						var label = script_node.get_interaction_label()
						GlobalContext.ui_context.update_content(label)
					else:
						GlobalContext.ui_context.update_content("Interagir")
				return

	# Rien d'interactif → masquer UI
	if GlobalContext.ui_context:
		GlobalContext.ui_context.reset()
	
	# Réinitialiser le dernier collider détecté
	last_detected_collider = null

# Fonction pour trouver la racine de la scène interactive (remonte jusqu'à trouver un nœud sans parent interactable)
func _find_scene_root(node: Node) -> Node:
	var current = node
	# Remonter jusqu'à trouver la racine de l'objet interactable
	while current.get_parent() and current.get_parent() != get_tree().current_scene:
		var parent = current.get_parent()
		# Si le parent n'est plus dans le groupe interactable, on s'arrête
		if not parent.is_in_group("interactable") and not _has_interactable_child(parent):
			break
		current = parent
	return current

# Fonction pour vérifier si un nœud a des enfants interactables
func _has_interactable_child(node: Node) -> bool:
	for child in node.get_children():
		if child.is_in_group("interactable"):
			return true
	return false

# Fonction récursive pour chercher le mesh_interact dans la hiérarchie locale
func _find_mesh_interact(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.is_in_group("mesh_interact"):
		return node as MeshInstance3D
	
	# Chercher dans les enfants
	for child in node.get_children():
		var found = _find_mesh_interact(child)
		if found:
			return found
	return null

# Fonction récursive pour chercher le script_interact dans la hiérarchie locale
func _find_script_interact(node: Node) -> Node:
	if node.is_in_group("script_interact"):
		return node
	
	# Chercher dans les enfants
	for child in node.get_children():
		var found = _find_script_interact(child)
		if found:
			return found
	return null

# Fonction avec système de priorité pour éviter les conflits NPC/ordinateur
func _find_script_interact_with_priority(node: Node) -> Node:
	var all_candidates = []
	_collect_all_script_candidates(node, all_candidates)
	
	if all_candidates.is_empty():
		return null
	
	# Système de priorité :
	# 1. NPCs (priorité haute)
	# 2. Tickets (priorité moyenne)  
	# 3. Ordinateurs et autres (priorité basse)
	
	# Chercher d'abord les NPCs
	for candidate in all_candidates:
		if candidate.is_in_group("npc"):
			return candidate
	
	# Ensuite les tickets
	for candidate in all_candidates:
		if candidate.is_in_group("ticket"):
			return candidate
	
	# Enfin les autres (ordinateurs, etc.)
	return all_candidates[0]

func _collect_all_script_candidates(node: Node, candidates: Array) -> void:
	if node.is_in_group("script_interact"):
		candidates.append(node)
	
	# Chercher dans les enfants
	for child in node.get_children():
		_collect_all_script_candidates(child, candidates)


func _perform_interaction() -> void:
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_transform.origin
	var to = from + -camera.global_transform.basis.z * interact_distance

	var params = PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.exclude = [self]

	var result = space_state.intersect_ray(params)

	if result:
		var collider = result.get("collider")
		if collider and collider.is_in_group("interactable"):
			
			# Chercher le script dans la hiérarchie de la scène avec priorité
			var scene_root = _find_scene_root(collider)
			var script_node: Node = null
			if scene_root:
				script_node = _find_script_interact_with_priority(scene_root)

			if script_node:
				# Gestion spéciale pour les NPCs si on tient un ticket
				if script_node.has_method("receive_ticket") and held_ticket:
					_give_ticket_to_npc(script_node)
					return
				
				# Déclenche l'interaction
				if script_node.has_method("object_interact"):
					script_node.object_interact()
				else:
					print("⚠️ Pas de méthode object_interact sur: ", script_node.name)

				# Si l'objet supporte un déplacement de caméra, on le fait
				# SAUF pour l'ordinateur qui gère son propre état
				if script_node.has_method("get_camera_travel_params") and not script_node.is_in_group("ordinateur"):
					travel_camera_to(script_node)
					GlobalContext.pending_interaction = script_node
			else:
				print("⚠️ Aucun script trouvé pour l'interaction")


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
	if body == self:
		current_state = State.LADDER

func _on_ladder_area_body_exited(body):
	if body == self:
		current_state = State.NORMAL

func ease_out_cubic(t: float) -> float:
	var f = t - 1.0
	return f * f * f + 1.0

func _update_ticket_forward_position() -> void:
	# Met à jour la position du ticket pour qu'il reste toujours devant le joueur
	if not held_ticket:
		return
		
	var ticket_rigidbody = held_ticket.get_parent()
	if not ticket_rigidbody:
		return
	
	# Vérifier que le ticket est bien attaché à la caméra
	if ticket_rigidbody.get_parent() != camera:
		return
	
	# Le ticket doit toujours être au centre de l'écran, dans la direction "avant" de la caméra
	# Position locale dans l'espace de la caméra : devant (Z négatif)
	var ticket_basis = Basis()
	ticket_basis = ticket_basis.rotated(Vector3.UP, deg_to_rad(15))  # Légère rotation sur Y
	ticket_basis = ticket_basis.rotated(Vector3.RIGHT, deg_to_rad(-10))  # Légère inclinaison
	
	# Position fixe au centre de l'écran (devant la caméra) - forcer la mise à jour
	ticket_rigidbody.transform = Transform3D(ticket_basis, ticket_ui_position)
	ticket_rigidbody.scale = Vector3(0.3, 0.3, 0.3)


func restore_camera_to_player():
	# Arrêter tout travel de caméra en cours
	camera_traveling = false
	camera_travel_t = 0.0
	camera_return_requested = false

	# Restaurer la position et rotation de la caméra par rapport à la tête
	camera.transform = Transform3D.IDENTITY
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO

	# Restaurer aussi la rotation de la tête si elle a été modifiée
	# (garder une rotation neutre pour éviter les problèmes)
	# head.rotation.x = clamp(head.rotation.x, deg_to_rad(-40), deg_to_rad(60))

	# Restaurer le contrôle et la souris
	GlobalContext.input_active = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ===== SYSTÈME DE TICKETS =====
func _grab_ticket(ticket_script: Node) -> void:
	if held_ticket:
		return
	
	# Le ticket_script est le MeshInstance3D avec le script
	# Le ticket physique est son parent (RigidBody3D)
	var ticket_rigidbody = ticket_script.get_parent()
	
	held_ticket = ticket_script  # On garde une référence au script
		
	# 1. DÉSACTIVER COMPLÈTEMENT LA PHYSIQUE avant d'attacher
	if ticket_rigidbody is RigidBody3D:
		ticket_rigidbody.set_freeze_mode(RigidBody3D.FREEZE_MODE_KINEMATIC)
		ticket_rigidbody.freeze = true
		ticket_rigidbody.gravity_scale = 0
		ticket_rigidbody.lock_rotation = true
	
	# 2. Détacher du monde
	if ticket_rigidbody.get_parent():
		ticket_rigidbody.get_parent().remove_child(ticket_rigidbody)
	
	# 3. Attacher immédiatement à la caméra pour garantir le suivi parfait
	camera.add_child(ticket_rigidbody)
	
	# Sauvegarder la position initiale dans l'espace de la caméra pour l'animation
	ticket_start_transform = ticket_rigidbody.transform  # Position locale dans la caméra
	
	# Position cible finale (centre de l'écran dans l'espace de la caméra)
	var ticket_basis = Basis()
	ticket_basis = ticket_basis.rotated(Vector3.UP, deg_to_rad(15))  # Légère rotation sur Y
	ticket_basis = ticket_basis.rotated(Vector3.RIGHT, deg_to_rad(-10))  # Légère inclinaison
	ticket_target_transform = Transform3D(ticket_basis, ticket_ui_position)
	ticket_target_transform.basis = ticket_target_transform.basis.scaled(Vector3(0.3, 0.3, 0.3))
	
	# Démarrer l'animation
	ticket_animating = true
	ticket_animation_t = 0.0

func _release_ticket() -> void:
	if not held_ticket:
		return
	
	var ticket_script = held_ticket
	var ticket_rigidbody = ticket_script.get_parent()
	held_ticket = null
		
	# 1. Détacher de la caméra
	camera.remove_child(ticket_rigidbody)
	
	# 2. Remettre dans le monde
	get_tree().current_scene.add_child(ticket_rigidbody)
	
	# 3. Repositionner devant le joueur
	ticket_rigidbody.global_position = global_position + global_transform.basis.z * -1.0 + Vector3.UP * 1.0
	ticket_rigidbody.scale = Vector3.ONE  # Remettre à la taille normale
	
	# 4. RÉACTIVER LA PHYSIQUE COMPLÈTEMENT
	if ticket_rigidbody is RigidBody3D:
		ticket_rigidbody.freeze = false
		ticket_rigidbody.set_freeze_mode(RigidBody3D.FREEZE_MODE_STATIC)
		ticket_rigidbody.gravity_scale = 0.5
		ticket_rigidbody.lock_rotation = false
	
	# 5. Réactiver via le script aussi
	ticket_script._release_ticket()
	

func _give_ticket_to_npc(npc: Node) -> bool:
	if not held_ticket:
		return false
	
	if not npc.has_method("receive_ticket"):
		return false
	
	var ticket_script = held_ticket
	var ticket_rigidbody = ticket_script.get_parent()
	held_ticket = null
	
	# Retirer le ticket de la caméra
	camera.remove_child(ticket_rigidbody)
	
	# Donner le ticket au NPC (on donne le script, pas le RigidBody)
	var success = npc.receive_ticket(ticket_script)
	
	if success:
		return true
	else:
		# Remettre le ticket en main si échec
		camera.add_child(ticket_rigidbody)
		# Appliquer la même rotation et position que lors du grab initial
		var ticket_basis = Basis()
		ticket_basis = ticket_basis.rotated(Vector3.UP, deg_to_rad(15))  # Légère rotation sur Y
		ticket_basis = ticket_basis.rotated(Vector3.RIGHT, deg_to_rad(-10))  # Légère inclinaison
		ticket_rigidbody.transform = Transform3D(ticket_basis, ticket_ui_position)
		ticket_rigidbody.scale = Vector3(0.3, 0.3, 0.3)
		held_ticket = ticket_script
		return false

func _handle_computer_interaction():
	# Cette fonction gère l'interaction avec l'interface de l'ordinateur via raycast
	if not GlobalContext.active_subviewport:
		return
	
	# Afficher en temps réel la position de la souris sur l'interface
	_update_debug_cursor()
	
	# Envoyer les mouvements de souris pour le hover
	_send_mouse_motion_to_interface()
	
	# Détecter uniquement les clics souris pour l'interface (pas E)
	if Input.is_action_just_pressed("click"):
		_perform_computer_click()

func _perform_computer_click():
	# Nouveau système : projeter la souris sur la zone de l'écran visible dans la caméra
	if not GlobalContext.active_subviewport:
		return
	
	var ordinateur = get_tree().get_first_node_in_group("ordinateur")
	if not ordinateur or not ordinateur.has_method("_handle_viewport_click"):
		return
	
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	
	ordinateur._handle_viewport_click(mouse_pos, camera)

func _update_debug_cursor():
	# Mettre à jour le curseur de débogage avec le nouveau système
	if not GlobalContext.active_subviewport:
		return
	
	var ordinateur = get_tree().get_first_node_in_group("ordinateur")
	if not ordinateur or not ordinateur.has_method("_debug_viewport_projection"):
		return
	
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	
	ordinateur._debug_viewport_projection(mouse_pos, camera)

func _send_mouse_motion_to_interface():
	# Envoyer les mouvements de souris pour activer le hover des boutons
	if not GlobalContext.active_subviewport:
		return
	
	var ordinateur = get_tree().get_first_node_in_group("ordinateur")
	if not ordinateur or not ordinateur.has_method("_handle_mouse_motion"):
		return
	
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	
	ordinateur._handle_mouse_motion(mouse_pos, camera)
