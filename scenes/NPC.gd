extends CharacterBody3D
class_name NPC

@export var data: Personne
@export var speed: float = 3.0
@export var gravity: float = 9.8
@export var walk_speed: float = 2.0
@export var sprint_speed: float = 5.0
@export var current_context: String = "achat_billeterie"

@export var interaction_data: InteractionData

var npc_state_machine: NPCStateMachine
var interaction_component: ObjectInteractable

@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree

@onready var label_3d = $Label3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D

@onready var body = $Skeleton3D/Body
@onready var head = $Skeleton3D/Head
@onready var bottoms = $Skeleton3D/Bottoms
@onready var tops = $Skeleton3D/Tops


var is_talking: bool = false
var stored_speed: float = 0.0

var y_velocity: float = 0.0
var t_bob: float = 0.0

# Taille de référence du modèle importé à scale = 1
const BASE_HEIGHT := 1.75
const MAX_STEP_HEIGHT := 0.4


# Durées possibles et formules possibles
var ticket_phrase: String = ""

var politesses_intro =  ["Bonjour", "Salut", "Hello", "Yo", "Coucou","Salut salut", "Hello hello", "Bonjour vous allez bien ?", "", "Hey"]
var verbes = [
	"J'aimerais",
	"J'aimerais faire",
	"Je voudrais", 
	"Je souhaiterais", 
	"Je pense prendre", 
	"On voudrait", 
	"Nous cherchons", 
	"Nous aimerions faire",
	"Ce serait possible de prendre", 
	"Soyons fou" ,
	"Je pense partir sur",
	"Est ce que ce serait possible",
	"Vous me mettez",
	"Je suis ici pour",
	"Je vais choisir",
	""
]
var objets = [
	"une entrée", "un ticket", "un pass", "une formule", "un billet"
]
var durees = ["journée", "demi-journée"]
var formules = ["parcours simple", "parcours sensation"]
var politesse = ["s'il vous plaît", "merci", "mister", "merci beaucoup", "merci bien", "merci d'avance", "svp", "stp", "s'il te plait", "frère", "merciii", "c'est carré", "le sang", "frérot", "tié un tigre"]
var phrases = [
	"%s %s %s %s pour le %s %s", 
	"%s %s %s %s et le %s %s",
	"%s %s %s %s, vous me mettez le %s %s",
	"%s %s %s %s votre %s %s",
	"%s %s %s %s avec le %s %s",
	"%s %s %s %s et pour le parcours... allez le %s %s",
	"%s %s %s %s et %s %s",
	"%s %s %s %s et un %s %s"
]

#var templates = [
	#"%s %s %s pour le %s %s",
	#"%s %s %s %s %s",
	#"%s %s la %s, vous me mettez le %s %s",
	#"%s %s pour le %s %s, %s",
	#"%s %s %s et %s pour le %s %s"
#]

func get_random_ticket_phrase() -> String:
	var intro = politesses_intro[randi() % politesses_intro.size()]
	var verbe = verbes[randi() % verbes.size()]
	var objet = objets[randi() % objets.size()]
	var duree = durees[randi() % durees.size()]
	var formule = formules[randi() % formules.size()]
	var politesse_finale = politesse[randi() % politesse.size()]
	
	var phrase = phrases[randi() % phrases.size()]
	
	return phrase % [intro, verbe, objet, duree, formule, politesse_finale]



func _ready():
	# Initialiser ObjectInteractable
	_setup_npc_state_machine()
	_setup_interaction_component()

	if data:
		apply_style(data)
		_set_height(data.taille)

	ticket_phrase = get_random_ticket_phrase()
	
	# Rendre le NPC interactable
	add_to_group("npc")
	
	print("[NPC] _ready called, data =", data)
	print("👤 NPC groupes: ", get_groups())

	_snap_to_ground_safe()
	
	# 🔹 S'assurer que l'anim_tree est actif
	if anim_tree:
		anim_tree.active = true
		print("[NPC] AnimationTree activé =", anim_tree.active)
	else:
		push_error("[NPC] Aucun AnimationTree trouvé !")


func _setup_npc_state_machine():
	npc_state_machine = NPCStateMachine.new(self)
	
	# Ajouter les états
	npc_state_machine.add_state("seeking_ticket", SeekingTicketState.new())
	npc_state_machine.add_state("waiting_for_ticket", WaitingForTicketState.new())
	npc_state_machine.add_state("waiting_for_equipment", WaitingForEquipmentState.new())  # NOUVEAU
	npc_state_machine.add_state("equipment_fitting", EquipmentFittingState.new())  # NOUVEAU
	npc_state_machine.add_state("exploring_park", ExploringParkState.new())  # NOUVEAU

	# Démarrer dans l'état de recherche de ticket
	npc_state_machine.change_state("seeking_ticket")


func _setup_interaction_component():
	# Créer un composant ObjectInteractable
	interaction_component = ObjectInteractable.new()
	add_child(interaction_component)
	
	# Ne pas configurer de label statique - on utilisera la méthode dynamique du NPC
	interaction_component.set_interaction_config("", "ui_accept", false)


func get_interaction_label() -> String:
	var player = GlobalContext.player
	if not player:
		return "Parler à " + (data.nom if data else "Personne")
	
	var active_item = player.player_inventory.get_active_item()
	if  active_item:
		if active_item is Ticket and is_in_state("WaitingForTicketState"):
			return "Donner le ticket au client (E)"
		if active_item is Harnais and is_in_state("WaitingForEquipmentState"):
			return "Donner un harnais au client (E)"
		
	return "Parler à " + (data.nom if data else "Personne")


func get_camera_travel_params() -> Dictionary:
	# Retourner un dictionnaire vide pour pas d'animation de caméra
	return {}


func object_interact() -> bool:
	var player = GlobalContext.player
	if not player:
		print("🎫 Pas de joueur trouvé")
		return false
		
	# Arrêter le NPC temporairement
	if agent:
		stored_speed = speed
		speed = 0
		agent.set_target_position(global_position)
	
	print("🎫 Interaction avec NPC - État actuel:", get_current_state_name())
	
	#Logique simplifiée
	var active_item = player.player_inventory.get_active_item()
	
	# Vérifier si on peut donner un item
	if active_item and is_in_state("WaitingForTicketState") and active_item is Ticket:
		print("🎫 Tentative de donner le ticket au NPC")
		return player._give_ticket_to_npc(self)
	elif active_item and is_in_state("WaitingForEquipmentState") and active_item is Harnais:
		print("🎒 Tentative de donner un harnais au NPC")
		return player._give_harnais_to_npc(self)
	else:
		# Toujours démarrer le dialogue
		print("🎫 Démarrage du dialogue")
		_start_dialogue()
		return true
	
	

func _update_object_interaction_detection(is_detected: bool):
	if interaction_component:
		# Utiliser le label dynamique du NPC au lieu du label statique du composant
		if is_detected:
			# Appliquer l'effet stencil
			interaction_component._change_stencil(is_detected)
			
			# Afficher le label d'interaction dynamique
			if GlobalContext.ui_context:
				GlobalContext.ui_context.update_key_action("E")
				var label = get_interaction_label()  # Utiliser la méthode du NPC
				if label != "":
					GlobalContext.ui_context.update_content(label)
				else:
					GlobalContext.ui_context.update_content("Interagir")
		else:
			# Retirer l'effet stencil
			interaction_component._change_stencil(is_detected)

func can_interact(player: Node = null) -> bool:
	if interaction_component:
		return interaction_component.can_interact(player)
	return true

func trigger_interaction(player: Node = null) -> bool:
	if interaction_component:
		return interaction_component.trigger_interaction(player)
	return object_interact()


func _start_dialogue():
	print("🔍 DEBUG: _start_dialogue() appelé")
	is_talking = true
	
	#Toujours afficher quelque chose
	var dialogue_text = ""
	
	if is_in_state("WaitingForTicketState"):
		dialogue_text = ticket_phrase
	elif is_in_state("WaitingForEquipmentState"):
		dialogue_text = "Vous allez me chercher mon équipement ?"
	else:
		dialogue_text = "Bonjour !"
	
	print("🔍 DEBUG: Dialogue affiché: ", dialogue_text)
	$Label3D.text = dialogue_text
	
	#Masquer après un délai
	await get_tree().create_timer(5.0).timeout
	$Label3D.text = ""
	is_talking = false


# ===== SYSTÈME DE TICKETS =====
func receive_ticket(ticket: Node) -> bool:
	# Vérifier si le ticket correspond aux demandes du NPC
	if not ticket or not ticket.ticket_data:
		print("🎫 Ticket invalide")
		return false
	
	# Analyser la phrase du NPC pour déterminer ce qu'il veut
	var ticket_data = ticket.ticket_data
	var npc_phrase = ticket_phrase.to_lower()
	
	# Vérifier le type de personne basé sur les données du NPC
	var npc_type = data.tranche_age if data else "Adulte"
	
	# Vérifier la correspondance du type de personne
	var type_match = false
	match ticket_data.type:
		"Enfant":
			type_match = (npc_type == "Enfant")
		"Adulte":
			type_match = (npc_type == "Adulte")
		"Sénior":
			type_match = (npc_type == "Senior")
	
	# Vérifier la durée
	var wants_full_day = "journée" in npc_phrase and "demi" not in npc_phrase
	var wants_half_day = "demi-journée" in npc_phrase or "demi journée" in npc_phrase
	
	# Vérifier la formule
	var wants_standard = "simple" in npc_phrase or "standard" in npc_phrase
	var wants_sensation = "sensation" in npc_phrase
	
	# Vérifier la correspondance de la durée
	var duration_match = false
	match ticket_data.duree:
		"Journée":
			duration_match = wants_full_day
		"1/2 Journée":
			duration_match = wants_half_day
	
	# Vérifier la correspondance de la formule
	var formula_match = false
	match ticket_data.parcours:
		"Basic":
			formula_match = wants_standard
		"Sensation":
			formula_match = wants_sensation
	
	# Le ticket doit correspondre sur tous les critères
	if type_match and duration_match and formula_match:
		print("🎫 Le NPC accepte le ticket: ", ticket_data.numero)
		print("🎫 Correspondance - Type: ", ticket_data.type, " Durée: ", ticket_data.duree, " Formule: ", ticket_data.parcours)
		$Label3D.text = "Merci beaucoup! Voilà mon ticket: " + ticket_data.numero
		
		# CORRECTION : Remettre is_talking à false pour permettre le mouvement
		is_talking = false
		
		# Optionnel: faire réagir le NPC
		_react_to_ticket_received(ticket_data)
		
		 # Quitter la file AVANT la transition
		if ParkPointsManager.instance:
			var park_manager = ParkPointsManager.instance
			park_manager.leave_ticket_queue(get_instance_id())
			print("[NPC] Quitte la file d'attente AVANT la transition")
		
		if npc_state_machine:
			npc_state_machine.change_state("waiting_for_equipment")
		
		return true
	else:
		# Messages d'erreur plus spécifiques
		var rejection_messages = []
		if not type_match:
			rejection_messages.append("Ce n'est pas le bon type de ticket pour moi...")
		if not duration_match:
			rejection_messages.append("Ce n'est pas la bonne durée...")
		if not formula_match:
			rejection_messages.append("Ce n'est pas la bonne formule...")
		
		var final_message = rejection_messages[randi() % rejection_messages.size()] if rejection_messages.size() > 0 else "Ce ticket ne correspond pas à ma demande."
		$Label3D.text = final_message
		print("🎫 Le NPC refuse le ticket - Correspondance: Type=", type_match, " Durée=", duration_match, " Formule=", formula_match)
		return false
		
		

func _react_to_ticket_received(ticket_data: Dictionary):
	# Réaction du NPC au ticket reçu
	var reactions = [
		"Parfait! Merci beaucoup!",
		"Exactement ce qu'il me fallait!",
		"Super, je vais pouvoir profiter du parc!",
		"Merci, c'est génial!"
	]
	
	# Optionnel: arrêter le NPC ou changer son comportement
	if agent:
		agent.set_target_position(global_position)  # Arrêter le mouvement
	
	await get_tree().create_timer(3.0).timeout
	$Label3D.text = reactions[randi() % reactions.size()]
	await get_tree().create_timer(1.0).timeout
	$Label3D.text = ""

func _set_height(target_height: float) -> void:
	# Calcul du scale proportionnel à la taille désirée
	var correction := target_height / BASE_HEIGHT
	scale = Vector3.ONE * correction

func _snap_to_ground_safe():
	# On spawn le NPC un peu au-dessus du sol pour éviter qu'il soit "dans" le sol
	var offset_above_ground = BASE_HEIGHT * scale.y * 0.5 + 0.1
	var space_state = get_world_3d().direct_space_state
	var from = global_position + Vector3.UP * 5.0  # départ du raycast assez haut
	var to = global_position + Vector3.DOWN * 10.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y + offset_above_ground
		print("[NPC] Spawn snap au sol à ", result.position)
	else:
		print("[NPC] Aucun sol détecté sous le spawn, position conservée")



func _physics_process(delta):
	if not agent:
		return

	# --- Gravité ---
	if not is_on_floor():
		y_velocity -= gravity * delta
	else:
		y_velocity = 0.0

	var move_dir = Vector3.ZERO

	# --- Navigation ---
	if not is_talking and not agent.is_navigation_finished():
		var next_pos = agent.get_next_path_position()
		var dir = next_pos - global_position
		dir.y = 0  # mouvement horizontal uniquement
		if dir.length() > 0.05:
			move_dir = dir.normalized() * speed
			_rotate_towards(dir, delta)
			
	# --- Appliquer mouvement ---
	velocity.x = move_dir.x
	velocity.z = move_dir.z
	velocity.y = y_velocity
	
		# --- Step climbing ---
	if not snap_up_step(delta):
		move_and_slide()

	# --- Headbob ---
	if is_on_floor() and head:
		t_bob += delta * Vector3(velocity.x, 0, velocity.z).length()
		head.transform.origin = _headbob(t_bob)
		
	if npc_state_machine:
		npc_state_machine.physics_process(delta)

		

func snap_up_step(delta: float) -> bool:
	if not is_on_floor() or velocity.y > 0 or (velocity * Vector3(1,0,1)).length() == 0:
		return false

	var horizontal_velocity = velocity * Vector3(1,0,1)
	var expected_motion = horizontal_velocity * delta

	# 🔹 point de départ un peu au-dessus (2× la hauteur de marche pour être safe)
	var test_origin = global_transform.translated(expected_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
	var collision = KinematicCollision3D.new()

	# 🔹 descente de 2× la hauteur de marche
	if test_move(test_origin, Vector3(0, -MAX_STEP_HEIGHT * 2, 0), collision):
		var step_height = ((test_origin.origin + collision.get_travel()) - global_position).y

		# 🔹 rejet si trop petit ou trop grand
		if step_height <= 0.01 or step_height > MAX_STEP_HEIGHT:
			return false

		# 🔹 correction de position
		global_position = test_origin.origin + collision.get_travel()

		_apply_floor_snap()
		return true

	return false


# --- Rotation vers la direction horizontale ---
func _rotate_towards(dir: Vector3, delta: float) -> void:
	if dir.length() == 0:
		return
	dir = dir.normalized()

	# Calcul de l'angle désiré en Y
	var desired_angle = atan2(dir.x, dir.z)

	# Interpolation douce de l'angle
	var current_angle = rotation.y
	var lerp_speed = 6.0
	rotation.y = lerp_angle(current_angle, desired_angle, lerp_speed * delta)


func _apply_floor_snap():
	# Assure que le NPC reste collé au sol
	var space_state = get_world_3d().direct_space_state
	var from = global_position + Vector3.UP * 0.1
	var to = global_position + Vector3.DOWN * (MAX_STEP_HEIGHT + 0.1)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result = space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y + BASE_HEIGHT * scale.y * 0.5 + 0.01


func _headbob(time: float) -> Vector3:
	# Simple oscillation verticale et légère rotation
	var bob_amount = 0.05 * scale.y  # amplitude proportionnelle à la taille
	var bob_speed  = 8.0
	var y_offset = sin(time * bob_speed) * bob_amount
	return Vector3(0, y_offset, 0)


func apply_style(p: Personne):
	for part_name in ["Body", "Head", "Tops", "Bottoms", "Shoes", "Hair"]:
		if skeleton.has_node(part_name):
			var part = skeleton.get_node(part_name)
			var mat = part.get_active_material(0).duplicate()
			match part_name:
				"Body", "Head": mat.albedo_color = p.couleur_peau
				"Tops": mat.albedo_color = p.couleur_haut
				"Bottoms": mat.albedo_color = p.couleur_bas
				"Shoes": mat.albedo_color = p.couleur_chaussures
				"Hair": mat.albedo_color = p.couleur_cheveux
			part.set_surface_override_material(0, mat)

func is_in_state(state_name: String) -> bool:
	if not npc_state_machine or not npc_state_machine.current_state:
		return false
	
	var current_state_name = npc_state_machine.current_state.get_script().get_global_name()
	return current_state_name == state_name

func get_current_state_name() -> String:
	if not npc_state_machine or not npc_state_machine.current_state:
		return "unknown"
	
	return npc_state_machine.current_state.get_script().get_global_name()


func receive_harnais(harnais: Harnais) -> bool:
	# Vérifier si le NPC est dans le bon état
	if not is_in_state("WaitingForEquipmentState"):
		print("🎒 Le NPC n'est pas en attente d'équipement!")
		return false
	
	# Vérifier si le harnais correspond au type de personne
	var harnais_size = harnais.harnais_data.get("size", "Adulte")
	var npc_type = data.tranche_age if data else "Adulte"
	
	var size_match = false
	match npc_type:
		"Enfant":
			size_match = (harnais_size == "Enfant")
		"Adulte", "Senior":
			size_match = (harnais_size == "Adulte")
	
	if size_match:
		print("🎒 Le NPC accepte le harnais!")
		$Label3D.text = "Parfait! Merci pour le harnais!"
		
		# Détruire le harnais (il est maintenant "utilisé")
		harnais.queue_free()
		
		# Passer à l'état d'installation
		if npc_state_machine:
			npc_state_machine.change_state("equipment_fitting")
		
		return true
	else:
		print("🎒 Le NPC refuse le harnais - taille incorrecte!")
		$Label3D.text = "Ce harnais n'est pas de la bonne taille pour moi..."
		return false
