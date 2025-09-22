extends ObjectInteractable

@export var cable: NodePath  # référence vers le CableTyro
@export var start_point: NodePath
@export var end_point: NodePath

func get_interaction_label() -> String:
	var player = GlobalContext.player
	if player and player.current_state == player.State.ZIPLINE:
		return "Décrocher la tyrolienne"
	else:
		return "Accrocher la tyrolienne"

func object_interact() -> void:
	var player = GlobalContext.player
	if not player:
		return
	
	var cable_node = get_node_or_null(cable)
	var start = get_node_or_null(start_point)
	var end = get_node_or_null(end_point)

	if cable_node and start and end:
		player.start_zipline(cable_node, start, end)
