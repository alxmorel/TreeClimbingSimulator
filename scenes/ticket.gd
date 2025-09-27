extends ObjectInteractable
class_name Ticket

var print_animation_tween: Tween
var is_printing: bool = false

var ticket_data = {}

@onready var rigid_body = $"."
@onready var collision_shape = $CollisionShape3D
@onready var mesh_instance = $MeshInstance

# État du ticket
var is_grabbed: bool = false

func _ready():
	super._ready()
	
	# Configurer le ticket comme un objet physique léger
	if rigid_body:
		rigid_body.gravity_scale = 0.5
		rigid_body.mass = 0.1
		# Ajouter une légère rotation initiale pour un effet naturel
		rigid_body.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	else:
		push_error("🎫 ERREUR: RigidBody3D non trouvé dans le ticket!")
	
	# Vérifier que le MeshInstance3D existe
	if not mesh_instance:
		push_error("🎫 ERREUR: MeshInstance3D non trouvé dans le ticket!")
	
	# Configurer l'interaction avec le nouveau système
	add_to_group("ticket")
	set_interaction_config("Prendre le ticket (E)", "ui_accept", false)
	
	if interaction_data:
		interaction_data.requires_camera_animation = false
	
	print("🎫 Ticket créé et configuré - groupes: ", get_groups())
	

func set_ticket_data(type_personne: String, duree: String, parcours: String):
	ticket_data = {
		"type": type_personne,
		"duree": duree,
		"parcours": parcours,
		"timestamp": Time.get_datetime_string_from_system(),
		"numero": _generate_ticket_number()
	}
	print("🎫 Ticket créé avec les données: ", ticket_data)
	
	# Optionnel : changer la couleur du ticket selon le type
	_update_ticket_appearance()

func _generate_ticket_number() -> String:
	# Générer un numéro de ticket unique
	var random_num = randi_range(1000, 9999)
	return "T" + str(random_num)

func _update_ticket_appearance():
	if not mesh_instance:
		return
		
	# Changer la couleur selon le type de personne
	var material = mesh_instance.get_surface_override_material(0)
	if material:
		material = material.duplicate()
		
		match ticket_data.type:
			"Enfant":
				material.albedo_color = Color(0.9, 0.95, 1.0, 1)  # Bleu clair
			"Adulte":
				material.albedo_color = Color(0.95, 0.95, 0.85, 1)  # Blanc cassé
			"Sénior":
				material.albedo_color = Color(1.0, 0.95, 0.9, 1)  # Rose clair
				
		mesh_instance.set_surface_override_material(0, material)
		
		print("ticket color : ", material.albedo_color)

func get_ticket_info() -> String:
	if ticket_data.is_empty():
		return "Ticket vide"
	
	return "🎫 TICKET D'ENTRÉE 🎫\n" + \
		   "====================\n" + \
		   "N°: " + ticket_data.numero + "\n" + \
		   "Âge: " + ticket_data.type + "\n" + \
		   "Durée: " + ticket_data.duree + "\n" + \
		   "Formule: " + ticket_data.parcours + "\n" + \
		   "Heure: " + ticket_data.timestamp + "\n" + \
		   "====================\n" + \
		   "Parc d'Acrobranche 🌲"

# ===== MÉTHODES D'OBJECTINTERACTABLE =====
func get_interaction_label() -> String:
	if is_grabbed:
		return ""
	return "Prendre le ticket (E)"


func _has_been_used() -> bool:
	return is_grabbed

func object_interact() -> bool:
	if is_grabbed:
		print("🎫 Ticket déjà ramassé")
		return false
	
	print("🎫 Interaction avec le ticket: ", ticket_data.get("numero", "inconnu"))
	print("🎫 Position du ticket: ", global_position)
	_grab_ticket()
	return true

# ===== SYSTÈME DE GRAB =====
func _grab_ticket():
	if is_grabbed:
		return
		
	is_grabbed = true
	
	# Informer le joueur qu'il a le ticket (le joueur gère la physique)
	if GlobalContext.player:
		GlobalContext.player._grab_ticket(self)
	
	print("🎫 Ticket ramassé!")

func _release_ticket():
	if not is_grabbed:
		return
		
	is_grabbed = false
	
	# La physique est gérée par le joueur lors du release
	print("🎫 Ticket relâché!")

# Méthode pour que le ticket devienne interactable
func _on_area_3d_input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int):
	if event is InputEventMouseButton and event.pressed:
		print(get_ticket_info())


# Ajouter cette méthode pour l'animation d'opacité
func _animate_alpha(start_alpha: float, end_alpha: float, duration: float):
	if not mesh_instance:
		return
	
	var material = mesh_instance.get_surface_override_material(0)
	if not material:
		return
	
	# Dupliquer le matériau pour éviter de modifier l'original
	material = material.duplicate()
	mesh_instance.set_surface_override_material(0, material)
	
	# Créer un tween pour l'opacité
	print_animation_tween = create_tween()
	print_animation_tween.tween_method(_update_alpha, start_alpha, end_alpha, duration)
	print_animation_tween.set_ease(Tween.EASE_OUT)
	print_animation_tween.set_trans(Tween.TRANS_CUBIC)

func _update_alpha(alpha: float):
	if not mesh_instance:
		return
	
	var material = mesh_instance.get_surface_override_material(0)
	if material:
		var current_color = material.albedo_color
		material.albedo_color = Color(current_color.r, current_color.g, current_color.b, alpha)

# Modifier la méthode _can_interact_custom pour empêcher l'interaction pendant l'impression
func _can_interact_custom(player: Node = null) -> bool:
	return not is_grabbed and not is_printing

# Ajouter une méthode pour marquer le ticket comme en cours d'impression
func set_printing_state(printing: bool):
	is_printing = printing
	if printing:
		# Désactiver la physique pendant l'impression
		if rigid_body:
			rigid_body.freeze = true
			rigid_body.gravity_scale = 0
			rigid_body.lock_rotation = true
	else:
		# Réactiver la physique après l'impression
		if rigid_body:
			rigid_body.freeze = false
			rigid_body.gravity_scale = 0.5
			rigid_body.lock_rotation = false
