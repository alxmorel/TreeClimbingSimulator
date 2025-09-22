extends Node

var ui_context: ContextComponent
var pending_interaction: Object = null
var input_active: bool = false
var player: CharacterBody3D = null

# TARGETS stockées globalement
var target_billeterie: Node3D = null

func _ready():
	_setup_target()

func _setup_target():
	var current_scene = get_tree().current_scene
	target_billeterie = current_scene.get_node_or_null("%TargetBilleterie")
	if target_billeterie:
		print("[GlobalContext] Target billeterie trouvée :", target_billeterie)
	else:
		push_warning("[GlobalContext] Target billeterie introuvable")
		
		
