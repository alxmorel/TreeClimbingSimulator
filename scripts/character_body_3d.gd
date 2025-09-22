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

# --- FOV ---
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# --- Step climbing ---
const MAX_STEP_HEIGHT = 0.4

# --- Ladder ---
enum State {
	NORMAL,
	LADDER,
	ZIPLINE
}

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
	
	 # Récupérer toutes les Area3D marquées comme ladder
	for ladder_area in get_tree().get_nodes_in_group("Ladders"):
		ladder_area.connect("body_entered", Callable(self, "_on_ladder_area_body_entered"))
		ladder_area.connect("body_exited", Callable(self, "_on_ladder_area_body_exited"))

func _physics_process(delta):
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

			# --- Restaurer input & souris après l’animation ---
			GlobalContext.input_active = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

			# Si une interaction était en attente
			if GlobalContext.pending_interaction:
				GlobalContext.pending_interaction.object_interact()
				GlobalContext.pending_interaction = null

	# --- Bloquer gameplay si input texte actif ---
	if GlobalContext.input_active:
		return
		
	# --- Handle speed ---
	speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED

	# --- Get input ---
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var horizontal_dir = Vector3(input_dir.x, 0, -input_dir.y) # 🔹 inversion de Y ici
	horizontal_dir = (head.transform.basis * horizontal_dir)
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
		
	# --- Interaction Raycast ---
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

	# Stocker la position et rotation de la caméra avant de se déplacer
	camera_original_transform = camera.global_transform
	camera_original_look_at = camera_target_look_at  # ou camera.global_transform.origin + -camera.global_transform.basis.z

	camera_start_transform = camera.global_transform

	# Calcul de la position finale
	var target_pos = target_node.global_transform.origin - target_node.global_transform.basis.z * offset.z
	target_pos.y += offset.y

	camera_target_transform = Transform3D(camera.global_transform.basis, target_pos)

	camera_travel_t = 0.0
	camera_traveling = true
	camera_travel_duration = duration
	camera_target_look_at = look_at
	var camera_return_requested: bool = false

	GlobalContext.input_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func play_idle():
	if anim_player.has_animation("Idle"):
		anim_player.play("Idle")

func _unhandled_input(event):
	# --- Bloquer gameplay si un input texte est actif ---
	if GlobalContext.input_active:
		if event is InputEventMouseMotion or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			return
	
	if event is InputEventMouseMotion:
		# --- Yaw : tourner le corps entier ---
		rotate_y(-event.relative.x * SENSITIVITY)

		# --- Pitch : tourner la tête/caméra ---
		head.rotate_x(event.relative.y * SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-40), deg_to_rad(60))
	
	# --- Interaction / Quitter Tyrolienne ---
	if Input.is_action_just_pressed("interact"):
		if current_state == State.ZIPLINE:
			_exit_zipline()
		else:
			_perform_interaction()

	if Input.is_action_just_pressed("ui_cancel"): # touche Échap
		if current_state == State.ZIPLINE:
			_exit_zipline()
			
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
			if collider.is_in_group("interactable"):
				var obj = collider.get_parent()

				# Identifier le mesh parent du collider
				var mesh_node: MeshInstance3D = null
				if obj and obj is MeshInstance3D:
					mesh_node = obj as MeshInstance3D

				# Créer l'aura si elle n'existe pas encore et qu'on a le mesh
				if mesh_node and mesh_node.mesh:
					if not last_aura_mesh:
						last_aura_mesh = MeshInstance3D.new()
						last_aura_mesh.mesh = mesh_node.mesh
						last_aura_mesh.material_override = preload("res://materials/InteractableAuraMaterial.tres")
						get_tree().current_scene.add_child(last_aura_mesh)

					# Positionner et afficher l'aura
					last_aura_mesh.global_transform = mesh_node.global_transform
					last_aura_mesh.visible = true

				# Afficher le label venant de l'objet
				if GlobalContext.ui_context:
					GlobalContext.ui_context.update_key_action("E")
					if obj.has_method("get_interaction_label"):
						GlobalContext.ui_context.update_content(obj.get_interaction_label())
					else :
						GlobalContext.ui_context.update_content("Interagir")
				return

	# Rien d'interactif → masquer UI
	if GlobalContext.ui_context:
		GlobalContext.ui_context.reset()


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
			var obj = collider
			while obj and not obj.has_method("object_interact"):
				obj = obj.get_parent()

			if obj:
				# Déclenche l'interaction
				obj.object_interact()

				# Si l'objet supporte un déplacement de caméra, on le fait
				if obj.has_method("get_camera_travel_params"):
					travel_camera_to(obj)
					GlobalContext.pending_interaction = obj


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

func restore_camera_to_player():
	# Si la caméra est en train de voyager, on ignore
	if camera_traveling:
		return

	# Forcer la caméra à reprendre sa position et rotation d'origine
	camera.global_transform = camera_original_transform
	camera_target_look_at = camera_original_transform.origin + -camera_original_transform.basis.z

	# Restaurer immédiatement le contrôle et la souris
	GlobalContext.input_active = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Annuler tout travel en attente
	camera_travel_t = 0.0
	camera_traveling = false
	camera_return_requested = false
