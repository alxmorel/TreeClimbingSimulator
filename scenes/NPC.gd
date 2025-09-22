extends CharacterBody3D
class_name NPC

@export var data: Personne
@export var speed: float = 3.0
@export var gravity: float = 9.8
@export var walk_speed: float = 2.0
@export var sprint_speed: float = 5.0
@export var current_context: String = "achat_billeterie"

@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree

@onready var label_3d = $Label3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var head = $Skeleton3D/Head

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
	"%s %s %s votre %s %s",
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
	if data:
		apply_style(data)
		_set_height(data.taille)

	ticket_phrase = get_random_ticket_phrase()
	
	
	print("[NPC] _ready called, data =", data)

	_snap_to_ground_safe()
	call_deferred("_setup_target")
	
	# 🔹 S'assurer que l'anim_tree est actif
	if anim_tree:
		anim_tree.active = true
		print("[NPC] AnimationTree activé =", anim_tree.active)
	else:
		push_error("[NPC] Aucun AnimationTree trouvé !")


func get_interaction_label() -> String:
	# Le texte affiché quand le joueur regarde le NPC
	return "Parler à " + (data.nom if data else "Personne")

func object_interact() -> void:
	# Arrêter le NPC
	if agent:
		stored_speed = speed
		speed = 0
		agent.set_target_position(global_position) # stop navigation

	is_talking = true
	
	# ✅ Si le NPC est arrivé à la billeterie
	if GlobalContext.target_billeterie and global_position.distance_to(GlobalContext.target_billeterie.global_position) < 2:
		$Label3D.text = ticket_phrase

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


func _setup_target():
	print("[NPC] Setup target")
	var current_scene = get_tree().current_scene

	var nav_region = current_scene.get_node_or_null("NavigationRegion3D")
	if nav_region:
		agent.set_navigation_map(nav_region.get_navigation_map())

	if GlobalContext.target_billeterie:
		agent.target_position = GlobalContext.target_billeterie.global_position
		print("[NPC] TargetBilleterie found at ", GlobalContext.target_billeterie.global_position)
	else:
		push_error("[NPC] TargetBilleterie introuvable dans la scène !")


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
		
	# 🔹 Faire regarder le Label3D vers le joueur
	#if GlobalContext.player and label_3d and label_3d.text.length() > 0:
		#var player_pos = GlobalContext.player.global_transform.origin
#
		## Faire regarder le Label3D vers le joueur
		#label_3d.look_at(player_pos, Vector3.UP)
#
		## Correction pour que la face avant du Label3D (-Z) soit visible
		#label_3d.rotate_y(deg_to_rad(180))

		

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
