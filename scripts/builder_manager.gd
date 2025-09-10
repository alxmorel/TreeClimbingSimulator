extends Node

signal builder_mode_changed(is_active: bool)

@export var player_camera: Camera3D
@export var builder_camera: Camera3D
@export var player_controller: CharacterBody3D
@export var builder_ui: CanvasLayer
@export var placement_manager: Node3D
@export var grid_system: Node3D

var is_builder_mode = false
var game_manager: Node  # Référence au GameManager

# Données des objets disponibles
var available_objects = [
	# Décorations
	{
		"name": "Arbre",
		"price": 50,
		"scene_path": "res://assets/models/tree/tree.blend",
		"icon": "🌳"
	},
	{
		"name": "Rocher",
		"price": 25,
		"scene_path": "res://assets/models/RockA.tscn",
		"icon": "🪨"
	},
	{
		"name": "Buisson",
		"price": 15,
		"scene_path": "res://assets/models/RockB.tscn",  # Temporaire - à remplacer
		"icon": "🌿"
	},
	# Structures
	{
		"name": "Guichet",
		"price": 200,
		"scene_path": "res://assets/models/RockC.tscn",  # Temporaire - à remplacer
		"icon": "🏪"
	},
	{
		"name": "Buvette",
		"price": 300,
		"scene_path": "res://assets/models/Tunnel.tscn",  # Temporaire - à remplacer
		"icon": "☕"
	},
	# Utilitaires
	{
		"name": "Banc",
		"price": 80,
		"scene_path": "res://assets/models/RockA.tscn",  # Temporaire - à remplacer
		"icon": "🪑"
	},
	{
		"name": "Poubelle",
		"price": 40,
		"scene_path": "res://assets/models/RockB.tscn",  # Temporaire - à remplacer
		"icon": "🗑️"
	},
	# Modules d'accrobranche
	{
		"name": "Module Départ Rudimentaire",
		"price": 150,
		"scene_path": "res://assets/models/module/départ_rudimentaire.glb",
		"icon": "🎯",
		"type": "tree_module"
	}
]

func _ready():
	# Attendre que tous les nœuds soient prêts
	await get_tree().process_frame
	
	# Vérifier que toutes les références sont correctes
	if not player_camera:
		player_camera = get_node_or_null("../CharacterBody3D/Camera3D")
	if not builder_camera:
		builder_camera = get_node_or_null("../BuilderCamera")
	if not player_controller:
		player_controller = get_node_or_null("../CharacterBody3D")
	if not builder_ui:
		builder_ui = get_node_or_null("../BuilderUI")
	if not placement_manager:
		placement_manager = get_node_or_null("../PlacementManager")
	if not grid_system:
		grid_system = get_node_or_null("../GridSystem")
	if not game_manager:
		game_manager = get_node_or_null("../GameManager")
	
	# S'assurer que le mode builder est désactivé au démarrage
	set_builder_mode(false)

func _unhandled_input(event):
	if Input.is_action_just_pressed("builder_mode"):
		toggle_builder_mode()
		get_viewport().set_input_as_handled()
	elif Input.is_action_just_pressed("ui_cancel") and is_builder_mode:
		if placement_manager and placement_manager.has_method("cancel_placement") and placement_manager.is_placing:
			placement_manager.cancel_placement()
			get_viewport().set_input_as_handled()

func toggle_builder_mode():
	set_builder_mode(not is_builder_mode)

func set_builder_mode(active: bool):
	is_builder_mode = active
	
	# Vérifier que toutes les références sont valides
	if not player_camera or not builder_camera or not player_controller or not builder_ui:
		print("Erreur: Références manquantes dans BuilderManager")
		return
	
	if is_builder_mode:
		# Activer le mode builder
		player_camera.current = false
		builder_camera.current = true
		player_controller.set_physics_process(false)
		builder_ui.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# Afficher la grille
		if grid_system and grid_system.has_method("show_grid"):
			grid_system.show_grid()
		
		print("Mode builder activé")
	else:
		# Revenir au mode jeu normal
		builder_camera.current = false
		player_camera.current = true
		player_controller.set_physics_process(true)
		builder_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# Masquer la grille
		if grid_system and grid_system.has_method("hide_grid"):
			grid_system.hide_grid()
		
		# Annuler le placement en cours si nécessaire
		if placement_manager and placement_manager.has_method("cancel_placement") and placement_manager.is_placing:
			placement_manager.cancel_placement()
		print("Mode builder désactivé")
	
	builder_mode_changed.emit(is_builder_mode)

func can_afford(price: int) -> bool:
	if game_manager and game_manager.has_method("can_afford"):
		return game_manager.can_afford(price)
	return false

func spend_money(amount: int) -> bool:
	if game_manager and game_manager.has_method("spend_money"):
		var success = game_manager.spend_money(amount)
		if success:
			# Ajouter de l'expérience pour l'achat
			game_manager.add_experience(amount / 2)  # XP = moitié du prix
		return success
	return false

func get_money() -> int:
	if game_manager and game_manager.has_method("get_money"):
		return game_manager.get_money()
	return 0
