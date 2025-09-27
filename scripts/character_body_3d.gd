extends CharacterBody3D

@export var data: Personne
@export var raycast : RayCast3D

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

# --- State Machine ---
var state_machine: StateMachine

# ===== SYSTÈME DE TICKETS =====
var held_ticket: Node = null
var ticket_ui_position: Vector3 = Vector3(0.2, -0.1, -0.6)  # Position relative à la caméra (légèrement à droite et en bas du centre)

# Animation du ticket
var ticket_animating: bool = false
var ticket_start_transform: Transform3D
var ticket_target_transform: Transform3D
var ticket_animation_t: float = 0.0
var ticket_animation_duration: float = 1.0

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
	
	# Initialiser la State Machine
	_setup_state_machine()
	
	 # Récupérer toutes les Area3D marquées comme ladder
	for ladder_area in get_tree().get_nodes_in_group("Ladders"):
		ladder_area.connect("body_entered", Callable(self, "_on_ladder_area_body_entered"))
		ladder_area.connect("body_exited", Callable(self, "_on_ladder_area_body_exited"))

func _physics_process(delta):
	# Gestion de l'animation du ticket
	if ticket_animating and held_ticket:
		ticket_animation_t += delta / ticket_animation_duration
		ticket_animation_t = clamp(ticket_animation_t, 0, 1)
		
		var ticket_rigidbody = held_ticket
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
			if state_machine.get_current_state_name() != "ordinateur":
				GlobalContext.input_active = false
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

			# Si une interaction était en attente et qu'on n'est pas en mode ordinateur
			if GlobalContext.pending_interaction and state_machine.get_current_state_name() != "ordinateur":
				GlobalContext.pending_interaction.object_interact()
				GlobalContext.pending_interaction = null

	# --- Bloquer gameplay si input texte actif ---
	if GlobalContext.input_active:
		return
	
	# Déléguer la logique à la state machine
	if state_machine:
		state_machine.physics_process(delta)
	

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
	state_machine.change_state("zipline")
	var zipline_state = state_machine.states["zipline"] as ZiplineState
	zipline_state.setup_zipline(cable, start, end)
	

func travel_camera_to(target_node: ObjectInteractable) -> void:
	if camera_traveling:
		return

	var params = target_node.get_camera_travel_params()
	
	# Vérifier si le dictionnaire est vide (nouveau système)
	if params.is_empty():
		print("⚠️ Aucun paramètre de caméra trouvé pour: ", target_node.name)
		return
	
	# Support des deux formats (ancien et nouveau)
	var offset = params.get("offset", Vector3.ZERO)
	var duration = params.get("duration", 0.8)
	var look_at = params.get("look_at", target_node.global_position + Vector3(0, 1, 0))

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
	
	# Déléguer la gestion des inputs à la state machine
	if state_machine:
		state_machine.handle_input(event)

func _setup_state_machine():
	state_machine = StateMachine.new(self)
	
	# Créer et ajouter tous les états
	state_machine.add_state("normal", NormalState.new())
	state_machine.add_state("ladder", LadderState.new())
	state_machine.add_state("zipline", ZiplineState.new())
	state_machine.add_state("ordinateur", OrdinateurState.new())
	
	# Démarrer dans l'état normal
	state_machine.start("normal")

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
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider is ObjectInteractable or collider is NPC:
			#var object : ObjectInteractable = collider as ObjectInteractable
			if collider.has_method("_update_object_interaction_detection"):
				collider._update_object_interaction_detection(true)

			#Afficher le log seulement si c'est un nouveau collider
			if collider != last_detected_collider:
				last_detected_collider = collider
			
			return
	elif last_detected_collider != null :
		if last_detected_collider.has_method("_update_object_interaction_detection"):
			last_detected_collider._update_object_interaction_detection(false)
	
	# Rien d'interactif → masquer UI
	if GlobalContext.ui_context:
		GlobalContext.ui_context.reset()
	
	# Réinitialiser le dernier collider détecté
	last_detected_collider = null


func _perform_interaction() -> void:
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider is ObjectInteractable:
			# Déclenche l'interaction
			collider.object_interact()

			# Si l'objet supporte un déplacement de caméra, on le fait
			if collider.has_method("get_camera_travel_params") && collider.interaction_data.requires_camera_animation:
				travel_camera_to(collider)
				GlobalContext.pending_interaction = collider
		elif collider is NPC:
			# Déclenche l'interaction
			collider.object_interact()

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
		state_machine.change_state("ladder")

func _on_ladder_area_body_exited(body):
	if body == self:
		state_machine.change_state("normal")

func ease_out_cubic(t: float) -> float:
	var f = t - 1.0
	return f * f * f + 1.0

#Sotie d'interraction avec un objet pour reprendre un controle normale du joueur
func restore_camera_to_player():
	# Arrêter tout travel de caméra en cours
	camera_traveling = false
	camera_travel_t = 0.0
	camera_return_requested = false

	# Restaurer la position et rotation de la caméra par rapport à la tête
	camera.transform = Transform3D.IDENTITY
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO

	# Restaurer le contrôle et la souris
	GlobalContext.input_active = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Méthodes publiques pour que les états puissent changer d'état
func change_to_normal_state():
	state_machine.change_state("normal")

func change_to_ladder_state():
	state_machine.change_state("ladder")

func change_to_zipline_state():
	state_machine.change_state("zipline")

func change_to_ordinateur_state():
	state_machine.change_state("ordinateur")

# Méthode pour récupérer l'état actuel (pour compatibilité avec les anciens scripts)
func get_current_state_name() -> String:
	if state_machine:
		return state_machine.get_current_state_name()
	return "normal"

# Méthodes de vérification d'état pour faciliter les interactions
func is_in_normal_state() -> bool:
	return get_current_state_name() == "normal"

func is_in_ladder_state() -> bool:
	return get_current_state_name() == "ladder"

func is_in_zipline_state() -> bool:
	return get_current_state_name() == "zipline"

func is_in_ordinateur_state() -> bool:
	return get_current_state_name() == "ordinateur"

# ===== SYSTÈME DE TICKETS =====
func _grab_ticket(ticket_rigidbody: RigidBody3D) -> void:
	if held_ticket:
		return
	
	# Le ticket est directement le RigidBody3D qui contient le script
	if not ticket_rigidbody or not ticket_rigidbody is RigidBody3D:
		push_error("🎫 ERREUR: Le ticket n'est pas un RigidBody3D!")
		return
	
	held_ticket = ticket_rigidbody  # On garde une référence au RigidBody3D
		
	# 1. DÉSACTIVER COMPLÈTEMENT LA PHYSIQUE avant d'attacher
	ticket_rigidbody.set_freeze_mode(RigidBody3D.FREEZE_MODE_KINEMATIC)
	ticket_rigidbody.freeze = true
	ticket_rigidbody.gravity_scale = 0
	ticket_rigidbody.lock_rotation = true
	
	# 2. Sauvegarder la position mondiale AVANT de détacher
	var world_position = ticket_rigidbody.global_position
	var world_rotation = ticket_rigidbody.global_rotation
	var world_scale = ticket_rigidbody.scale
	
	# 3. Détacher du monde
	if ticket_rigidbody.get_parent():
		ticket_rigidbody.get_parent().remove_child(ticket_rigidbody)
	
	# 4. Attacher à la caméra
	camera.add_child(ticket_rigidbody)
	
	# 5. Repositionner le ticket à sa position mondiale dans l'espace de la caméra
	ticket_rigidbody.global_position = world_position
	ticket_rigidbody.global_rotation = world_rotation
	ticket_rigidbody.scale = world_scale
	
	# 6. Sauvegarder la position initiale dans l'espace de la caméra pour l'animation
	ticket_start_transform = ticket_rigidbody.transform  # Position locale dans la caméra
	
	# 7. Position cible finale (centre de l'écran dans l'espace de la caméra)
	var ticket_basis = Basis()
	ticket_basis = ticket_basis.rotated(Vector3.UP, deg_to_rad(15))  # Légère rotation sur Y
	ticket_basis = ticket_basis.rotated(Vector3.RIGHT, deg_to_rad(-10))  # Légère inclinaison
	ticket_target_transform = Transform3D(ticket_basis, ticket_ui_position)
	#ticket_target_transform.basis = ticket_target_transform.basis.scaled(Vector3(0.6, 0.6, 0.6))
	
	# 8. Démarrer l'animation
	ticket_animating = true
	ticket_animation_t = 0.0


func _release_ticket() -> void:
	if not held_ticket:
		return
	
	var ticket_rigidbody = held_ticket
	held_ticket = null
	
	# 1. Sauvegarder la position actuelle du ticket dans l'espace monde
	var current_world_position = ticket_rigidbody.global_position
	var current_world_rotation = ticket_rigidbody.global_rotation
	var current_scale = ticket_rigidbody.scale
	
	# 2. Détacher de la caméra
	if ticket_rigidbody and ticket_rigidbody.get_parent() == camera:
		camera.remove_child(ticket_rigidbody)
	
	# 3. Remettre dans le monde
	if ticket_rigidbody:
		get_tree().current_scene.add_child(ticket_rigidbody)
		
		# 4. Repositionner le ticket à sa position actuelle (pas devant le joueur)
		ticket_rigidbody.global_position = current_world_position
		ticket_rigidbody.global_rotation = current_world_rotation
		ticket_rigidbody.scale = current_scale
		
		# 5. RÉACTIVER LA PHYSIQUE COMPLÈTEMENT
		ticket_rigidbody.freeze = false
		ticket_rigidbody.set_freeze_mode(RigidBody3D.FREEZE_MODE_KINEMATIC)
		ticket_rigidbody.gravity_scale = 1.0
		ticket_rigidbody.lock_rotation = false
	
	# 7. Réactiver via le script aussi
	if ticket_rigidbody.has_method("_release_ticket"):
		ticket_rigidbody._release_ticket()
	
	
func _give_ticket_to_npc(npc: Node) -> bool:
	if not held_ticket:
		return false
	
	if not npc.has_method("receive_ticket"):
		return false
	
	var ticket_rigidbody = held_ticket
	held_ticket = null
	
	# Retirer le ticket de la caméra
	if ticket_rigidbody and ticket_rigidbody.get_parent() == camera:
		camera.remove_child(ticket_rigidbody)
	
	# Donner le ticket au NPC (on donne le RigidBody3D qui contient le script)
	var success = npc.receive_ticket(ticket_rigidbody)
	
	if success:
		return true
	else:
		# Remettre le ticket en main si échec
		if ticket_rigidbody:
			camera.add_child(ticket_rigidbody)
			# Appliquer la même rotation et position que lors du grab initial
			var ticket_basis = Basis()
			ticket_basis = ticket_basis.rotated(Vector3.UP, deg_to_rad(15))  # Légère rotation sur Y
			ticket_basis = ticket_basis.rotated(Vector3.RIGHT, deg_to_rad(-10))  # Légère inclinaison
			ticket_rigidbody.transform = Transform3D(ticket_basis, ticket_ui_position)
			#ticket_rigidbody.scale = Vector3(0.6, 0.6, 0.6)
		held_ticket = ticket_rigidbody
		return false

func _update_ticket_forward_position() -> void:
	# Met à jour la position du ticket pour qu'il reste toujours devant le joueur
	if not held_ticket:
		return
		
	var ticket_rigidbody = held_ticket
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
	#ticket_rigidbody.scale = Vector3(0.6, 0.6, 0.6)
