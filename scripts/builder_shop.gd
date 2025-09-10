extends Control

@export var builder_manager: Node
@export var placement_manager: Node3D
@export var tab_container: Control
@export var tab_buttons_container: HBoxContainer

var object_buttons = []
var current_category = "decorations"

# Définition des catégories et objets
var categories = {
	"decorations": {
		"name": "Décorations",
		"icon": "🌿",
		"objects": []
	},
	"structures": {
		"name": "Structures", 
		"icon": "🏢",
		"objects": []
	},
	"utilitaires": {
		"name": "Utilitaires",
		"icon": "🔧", 
		"objects": []
	},
	"modules": {
		"name": "Modules",
		"icon": "🎯",
		"objects": []
	}
}

func _ready():
	# Attendre que tous les nœuds soient prêts
	await get_tree().process_frame
	
	# Vérifier et initialiser les références si nécessaire
	if not builder_manager:
		builder_manager = get_node_or_null("../../BuilderManager")
	if not placement_manager:
		placement_manager = get_node_or_null("../../PlacementManager")
	if not tab_container:
		tab_container = get_node_or_null("ShopPanel/VBoxContainer/MarginContainer/TabContainer")
	if not tab_buttons_container:
		tab_buttons_container = get_node_or_null("ShopPanel/VBoxContainer/TabButtonsContainer")
	
	# Vérifier que toutes les références sont valides
	if not tab_container:
		print("Erreur: tab_container non trouvé dans BuilderShop")
		return
	if not tab_buttons_container:
		print("Erreur: tab_buttons_container non trouvé dans BuilderShop")
		return
	if not builder_manager:
		print("Erreur: builder_manager non trouvé dans BuilderShop")
		return
	
	print("BuilderShop initialisé avec ", builder_manager.available_objects.size(), " objets")
	
	# Initialiser les catégories et l'interface
	initialize_categories()
	create_tab_interface()
	populate_current_category()
	
	# Activer le premier onglet par défaut
	set_default_active_tab()

func initialize_categories():
	# Distribuer les objets existants dans les catégories appropriées
	if not builder_manager or not builder_manager.available_objects:
		return
		
	# Vider d'abord toutes les catégories
	for category_key in categories.keys():
		categories[category_key].objects.clear()
		
	for obj_data in builder_manager.available_objects:
		var category = get_object_category(obj_data.name)
		categories[category].objects.append(obj_data)
	
	# Afficher un résumé succinct
	print("Catégories initialisées:")
	for category_key in categories.keys():
		var category = categories[category_key]
		print("  ", category.icon, " ", category.name, ": ", category.objects.size(), " objet(s)")

func get_object_category(object_name: String) -> String:
	# Classifier les objets selon leur nom
	var name_lower = object_name.to_lower()
	
	# Décorations (avec les objets existants explicitement listés)
	if name_lower in ["arbre", "rocher", "buisson", "lanterne", "fanion"]:
		return "decorations"
	
	# Structures
	elif name_lower in ["guichet", "local matériel", "consignes", "buvette", "local_materiel"]:
		return "structures"
	
	# Utilitaires  
	elif name_lower in ["toilettes", "banc", "table", "poubelle", "lampadaire"]:
		return "utilitaires"
	
	# Modules
	elif name_lower in ["parcours", "tyrolienne", "module", "pont", "module départ rudimentaire"]:
		return "modules"
	
	# Par défaut, tout va dans Décorations
	else:
		return "decorations"

func create_tab_interface():
	if not tab_buttons_container:
		return
		
	# Vider les boutons d'onglets existants
	for child in tab_buttons_container.get_children():
		child.queue_free()
	
	# Créer un bouton pour chaque catégorie
	for category_key in categories.keys():
		var category = categories[category_key]
		var tab_button = create_tab_button(category_key, category.name, category.icon)
		tab_buttons_container.add_child(tab_button)

func create_tab_button(category_key: String, category_name: String, icon: String) -> Button:
	var button = Button.new()
	button.text = icon + " " + category_name
	button.custom_minimum_size = Vector2(140, 40)
	button.toggle_mode = true
	button.button_group = create_button_group_if_needed()
	
	# Style pour les onglets
	apply_tab_button_style(button, category_key == current_category)
	
	# Connecter le signal
	button.pressed.connect(_on_tab_selected.bind(category_key))
	
	return button

var tab_button_group: ButtonGroup

func create_button_group_if_needed() -> ButtonGroup:
	if not tab_button_group:
		tab_button_group = ButtonGroup.new()
	return tab_button_group

func apply_tab_button_style(button: Button, is_active: bool):
	var style_normal = StyleBoxFlat.new()
	var style_pressed = StyleBoxFlat.new()
	
	if is_active:
		style_normal.bg_color = Color(0.62, 0.46, 0.34, 1)
		style_normal.border_color = Color(0.4, 0.28, 0.2, 1.0)
	else:
		style_normal.bg_color = Color(0.15, 0.15, 0.15, 0.8)
		style_normal.border_color = Color(0.4, 0.4, 0.4, 1.0)
	
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	
	style_pressed.bg_color = Color(0.3, 0.6, 0.9, 0.9)
	style_pressed.border_color = Color(0.4, 0.8, 1.0, 1.0)
	style_pressed.border_width_left = 2
	style_pressed.border_width_right = 2
	style_pressed.border_width_top = 2
	style_pressed.border_width_bottom = 2
	style_pressed.corner_radius_top_left = 8
	style_pressed.corner_radius_top_right = 8
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("hover", style_pressed)

func _on_tab_selected(category_key: String):
	current_category = category_key
	populate_current_category()
	update_tab_button_styles()

func update_tab_button_styles():
	if not tab_buttons_container:
		return
		
	var i = 0
	for category_key in categories.keys():
		if i < tab_buttons_container.get_child_count():
			var button = tab_buttons_container.get_child(i)
			apply_tab_button_style(button, category_key == current_category)
		i += 1

func set_default_active_tab():
	if not tab_buttons_container or tab_buttons_container.get_child_count() == 0:
		return
		
	# Activer le premier bouton (Décorations)
	var first_button = tab_buttons_container.get_child(0)
	if first_button:
		first_button.button_pressed = true

func populate_current_category():
	if not tab_container:
		print("ERREUR: tab_container est null dans populate_current_category")
		return
	
	print("Affichage catégorie: ", current_category, " (", categories[current_category].objects.size(), " objets)")
	
	# Vider le contenu actuel
	for child in tab_container.get_children():
		child.queue_free()
	
	# Attendre que les enfants soient vraiment supprimés
	await get_tree().process_frame
	
	object_buttons.clear()
	
	# Créer le GridContainer directement dans le TabContainer
	var grid_container = GridContainer.new()
	grid_container.columns = 4
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_container.add_theme_constant_override("h_separation", 15)
	grid_container.add_theme_constant_override("v_separation", 15)
	grid_container.name = "GridContainer_" + current_category
	
	tab_container.add_child(grid_container)
	
	# Ajouter les objets de la catégorie actuelle
	var category_objects = categories[current_category].objects
	
	for i in range(category_objects.size()):
		var obj_data = category_objects[i]
		var button = create_object_button(obj_data, i)
		grid_container.add_child(button)
		object_buttons.append(button)

func create_object_button(obj_data: Dictionary, index: int) -> Button:
	var button = Button.new()
	var icon = obj_data.get("icon", "📦")
	button.text = icon  # Seulement l'icône, pas de nom ni de prix
	button.custom_minimum_size = Vector2(80, 80)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.name = "Button_" + obj_data.name
	
	# S'assurer que le bouton est visible
	button.visible = true
	button.modulate = Color.WHITE
	
	# Style du bouton
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.95, 0.95, 0.95, 0.8)
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(1, 1, 1, 1.0)
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.3, 0.3, 0.3, 0.8)
	style_hover.border_color = Color(0.7, 0.7, 0.7, 1.0)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.1, 0.4, 0.1, 0.8)
	style_pressed.border_color = Color(0.2, 0.8, 0.2, 1.0)
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	# Connecter le signal
	button.pressed.connect(_on_object_button_pressed.bind(index))
	
	return button

func _on_object_button_pressed(index: int):
	var category_objects = categories[current_category].objects
	if index >= category_objects.size():
		return
		
	var obj_data = category_objects[index]
	
	# Vérifier si le joueur a assez d'argent
	if not builder_manager.can_afford(obj_data.price):
		print("Pas assez d'argent pour acheter: ", obj_data.name)
		return
	
	# Démarrer le placement
	if placement_manager:
		placement_manager.start_placement(obj_data)
		print("Placement démarré pour: ", obj_data.name)

func _process(_delta):
	# Vérifications de sécurité avant de mettre à jour
	if not builder_manager:
		return
		
	# Mettre à jour l'état des boutons selon l'argent disponible
	var category_objects = categories[current_category].objects
	if object_buttons.size() > 0 and category_objects.size() > 0:
		for i in range(min(object_buttons.size(), category_objects.size())):
			var button = object_buttons[i]
			var obj_data = category_objects[i]
			var can_afford = builder_manager.can_afford(obj_data.price)
			
			button.disabled = not can_afford
			if not can_afford:
				button.modulate = Color(0.5, 0.5, 0.5, 1.0)
			else:
				button.modulate = Color(1.0, 1.0, 1.0, 1.0)
