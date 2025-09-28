# scripts/harnais.gd
extends ObjectInteractable
class_name Harnais

@onready var rigid_body = $"."

@export var harnais_data: Dictionary = {}

var original_parent: Node
var original_position: Vector3
var original_rotation: Vector3

func _ready():
	super._ready()
	
	if rigid_body:
		# Configurer la physique
		rigid_body.gravity_scale = 1.0
		rigid_body.lock_rotation = false
	else:
		push_error("🎒 ERREUR: RigidBody3D non trouvé dans le harnais!")
		
	# Créer les données du harnais
	_create_harnais_data()
	
	# Configurer l'interaction
	_setup_interaction()

func _create_harnais_data():
	harnais_data = {
		"type": "Harnais",
		"size": "Adulte",  # Adulte/Enfant
		"color": Color(0.2, 0.2, 0.2),  # Couleur par défaut
		"weight": 2.5,  # Poids en kg
		"timestamp": Time.get_datetime_string_from_system()
	}

func _setup_interaction():
	# Configurer l'interaction via la classe parent
	set_interaction_config("Prendre le harnais (E)", "ui_accept", false)
	set_stencil_glow(Color.ORANGE, 0.8)

# CORRECTION : Surcharger la méthode object_interact()
func object_interact() -> bool:
	if can_be_picked_up():
		_pick_up_harnais()
		return true
	else:
		print("🎒 Inventaire plein!")
		return false

func can_be_picked_up() -> bool:
	# Vérifier si le joueur peut prendre ce harnais
	var player = GlobalContext.player
	if not player:
		return false
	
	# Utiliser l'inventaire UI pour la capacité
	return not player.player_inventory.is_full()

func get_interaction_label() -> String:
	if can_be_picked_up():
		return "Prendre le harnais (E)"
	else:
		return "Inventaire plein"

func _pick_up_harnais():
	var player = GlobalContext.player
	if player:
		player._grab_harnais(self)

func _release_harnais():
	# Remettre le harnais dans le monde
	rigid_body.gravity_scale = 1.0
	rigid_body.lock_rotation = false
	
	# Remettre dans la scène
	if original_parent:
		original_parent.add_child(self)
		global_position = original_position
		global_rotation = original_rotation

func get_display_name() -> String:
	var size = harnais_data.get("size", "Adulte")
	return "Harnais " + size

func get_item_key() -> String:
	return harnais_data.get("size", "Adulte") + "_" + harnais_data.get("type", "Harnais")
