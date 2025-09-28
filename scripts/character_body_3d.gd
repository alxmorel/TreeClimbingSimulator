extends CharacterBody3D

@export var data: Personne
@export var raycast : RayCast3D

@onready var skeleton = $Skeleton3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var telephone_avis_ui = $"../TelephoneUI/telephone_avis_ui"

@onready var head = $Skeleton3D/HeadCam
@onready var camera = $Skeleton3D/HeadCam/Camera3D
@onready var cable_tyro = %CableTyro

@onready var player_inventory: PlayerInventory = $PlayerInventory

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
	
	# Connecter signaux de l'inventaire
	player_inventory.active_item_changed.connect(_on_active_item_changed)

	
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
	if not player_inventory:
		print("🎫 ERREUR: Inventaire UI non initialisé!")
		return
	
	if player_inventory.is_full():
		print("🎫 Inventaire plein!")
		return
	
	# Le ticket est directement le RigidBody3D qui contient le script
	if not ticket_rigidbody or not ticket_rigidbody is RigidBody3D:
		push_error("🎫 ERREUR: Le ticket n'est pas un RigidBody3D!")
		return
	
	# NOUVEAU : D'abord détacher le ticket du monde
	# Détacher de la scène AVANT d'ajouter à l'inventaire
	ticket_rigidbody.get_parent().remove_child(ticket_rigidbody)
	
	# Maintenant ajouter à l'inventaire
	if player_inventory.add_item(ticket_rigidbody):
		print("🎫 Ticket ajouté à l'inventaire UI!")
	else:
		print("🎫 Impossible d'ajouter le ticket à l'inventaire!")


func _release_item() -> void:
	if not player_inventory:
		return
	
	# Récupérer l'item actif
	var active_item = player_inventory.get_active_item()
	if not active_item:
		print("🎫 Aucun item actif à lâcher!")
		return
	
	# Retirer de l'inventaire UI
	var item = player_inventory.remove_item(player_inventory.active_slot_index)
	if item:
		# Utiliser la fonction de drop
		player_inventory._drop_item_from_camera(item)
		print("🎫 Item drop dans le monde!")
	

func _give_ticket_to_npc(npc: Node) -> bool:
	if not player_inventory:
		return false
	
	# Récupérer l'item actif
	var active_item = player_inventory.get_active_item()
	if not active_item or not active_item is Ticket:
		print("🎫 Aucun ticket actif à donner!")
		return false
	
	# NOUVEAU : Vérifier d'abord si le NPC accepte le ticket
	if npc.receive_ticket(active_item):
		# Le NPC accepte, maintenant retirer de l'inventaire
		var ticket = player_inventory.remove_item(player_inventory.active_slot_index)
		if ticket:
			# NOUVEAU : Détacher le ticket de la caméra avant de le donner
			if ticket.get_parent() == camera:
				camera.remove_child(ticket)
			
			print("🎫 Ticket donné au NPC via l'inventaire UI!")
			return true
	else:
		# Le NPC refuse, ne pas retirer de l'inventaire
		print("🎫 Le NPC refuse le ticket!")
		return false
	
	return false


func _grab_harnais(harnais: Harnais):
	if not player_inventory:
		print("🎒 ERREUR: Inventaire UI non initialisé!")
		return false
	
	if player_inventory.is_full():
		print("🎒 Inventaire plein!")
		return false
	
	# Détacher de la scène AVANT d'ajouter à l'inventaire
	harnais.get_parent().remove_child(harnais)
	
	# Maintenant ajouter à l'inventaire
	if player_inventory.add_item(harnais):
		print("🎒 Harnais ajouté à l'inventaire UI!")
		return true
	
	return false
		
	
func _give_harnais_to_npc(npc: NPC) -> bool:
	if not player_inventory:
		return false
	
	# Récupérer l'item actif
	var active_item = player_inventory.get_active_item()
	if not active_item or not active_item is Harnais:
		print("🎒 Aucun harnais actif à donner!")
		return false
	
	# NOUVEAU : Vérifier d'abord si le NPC accepte le harnais
	if npc.receive_harnais(active_item):
		# Le NPC accepte, maintenant retirer de l'inventaire
		var harnais = player_inventory.remove_item(player_inventory.active_slot_index)
		if harnais:
			# NOUVEAU : Détacher le harnais de la caméra avant de le donner
			if harnais.get_parent() == camera:
				camera.remove_child(harnais)
			
			print("🎒 Harnais donné au NPC via l'inventaire UI!")
			return true
	else:
		# Le NPC refuse, ne pas retirer de l'inventaire
		print("🎒 Le NPC refuse le harnais!")
		return false
	
	return false

func _on_active_item_changed(item: Node, slot_index: int):
	# Déléguer à l'inventaire
	player_inventory._on_active_item_changed(item, slot_index)
