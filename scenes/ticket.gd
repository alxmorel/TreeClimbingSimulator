extends ObjectInteractable

var ticket_data = {}

@onready var rigid_body = $".."
@onready var collision_shape = $"../CollisionShape3D"
@onready var mesh_instance = $"."

# État du ticket
var is_grabbed: bool = false
var original_parent: Node = null

func _ready():
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
	
	# Configurer l'interaction
	add_to_group("ticket")
	add_to_group("mesh_interact")  # Pour que l'aura fonctionne
	add_to_group("script_interact")  # Pour que l'interaction fonctionne
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

func object_interact() -> void:
	if is_grabbed:
		print("🎫 Ticket déjà ramassé")
		return
	
	print("🎫 Interaction avec le ticket: ", ticket_data.get("numero", "inconnu"))
	print("🎫 Position du ticket: ", global_position)
	_grab_ticket()

# ===== SYSTÈME DE GRAB =====
func _grab_ticket():
	if is_grabbed:
		return
		
	is_grabbed = true
	original_parent = get_parent()
	
	# Désactiver la physique du RigidBody
	if rigid_body:
		rigid_body.freeze = true
		rigid_body.set_gravity_scale(0)
	
	# Informer le joueur qu'il a le ticket
	if GlobalContext.player:
		GlobalContext.player._grab_ticket(self)
	
	print("🎫 Ticket ramassé!")

func _release_ticket():
	if not is_grabbed:
		return
		
	is_grabbed = false
	
	# Réactiver la physique
	if rigid_body:
		rigid_body.freeze = false
		rigid_body.set_gravity_scale(0.5)
	
	print("🎫 Ticket relâché!")

# Méthode pour que le ticket devienne interactable
func _on_area_3d_input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int):
	if event is InputEventMouseButton and event.pressed:
		print(get_ticket_info())
