extends ObjectInteractable

@export var cable: NodePath  # référence vers le CableTyro
@export var start_point: NodePath
@export var end_point: NodePath

func _ready():
	super._ready()
	
	# Configuration de base - le label sera dynamique
	set_interaction_config("Accrocher la tyrolienne", "ui_accept", false)

func get_interaction_label() -> String:
	var player = GlobalContext.player
	if player and player.is_in_zipline_state():
		return "Décrocher la tyrolienne"
	else:
		return "Accrocher la tyrolienne"

func object_interact() -> bool:
	var player = GlobalContext.player
	if not player:
		return false
	
	var cable_node = get_node_or_null(cable)
	var start = get_node_or_null(start_point)
	var end = get_node_or_null(end_point)

	if cable_node and start and end:
		player.start_zipline(cable_node, start, end)
		return true
	
	return false
