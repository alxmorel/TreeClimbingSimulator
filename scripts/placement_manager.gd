extends Node3D

@export var builder_manager: Node
@export var builder_camera: Camera3D
@export var terrain: Node3D
@export var grid_system: Node3D

var is_placing = false
var is_editing_mode = false  # Distingue le mode édition du mode placement initial
var current_ghost_object: Node3D = null
var current_object_data: Dictionary = {}
var placed_objects_parent: Node3D
var raycast: RayCast3D

# Système de gestion des dépendances (version simplifiée intégrée)
var dependencies: Dictionary = {}  # { "objet_id": [dépendances] }
var reverse_dependencies: Dictionary = {}  # { "objet_id": [objets_dépendants] }
var next_object_id: int = 0

# Système de placement sur arbres pour les modules d'accrobranche
var tree_placement_mode = false
var current_target_tree: Node3D = null
var tree_detection_raycast: RayCast3D
var tree_orientation_raycast: RayCast3D

# Feedback visuel
var ghost_material: StandardMaterial3D
var valid_material: StandardMaterial3D
var invalid_material: StandardMaterial3D

func _ready():
	# Attendre que tous les nœuds soient prêts
	await get_tree().process_frame
	
	# Vérifier et initialiser les références si nécessaire
	if not builder_manager:
		builder_manager = get_node_or_null("../BuilderManager")
	if not builder_camera:
		builder_camera = get_node_or_null("../BuilderCamera")
	if not terrain:
		terrain = get_node_or_null("../Terrain3D")
	if not grid_system:
		grid_system = get_node_or_null("../GridSystem")
	
	# Vérifier que les références critiques sont valides
	if not builder_camera:
		print("Erreur: builder_camera non trouvé dans PlacementManager")
		return
	if not builder_manager:
		print("Erreur: builder_manager non trouvé dans PlacementManager")
		return
	
	# Créer le parent pour les objets placés
	placed_objects_parent = Node3D.new()
	placed_objects_parent.name = "PlacedObjects"
	get_tree().current_scene.add_child(placed_objects_parent)
	
	# Système de dépendances intégré - pas d'initialisation externe nécessaire
	print("Système de dépendances intégré initialisé")
	
	# Créer le raycast pour détecter le terrain
	raycast = RayCast3D.new()
	raycast.collision_mask = 1  # Layer du terrain
	raycast.target_position = Vector3(0, -1000, 0)
	add_child(raycast)
	
	# Créer les raycasts pour la détection d'arbres
	tree_detection_raycast = RayCast3D.new()
	tree_detection_raycast.collision_mask = 0xFFFFFFFF  # Tous les layers
	tree_detection_raycast.target_position = Vector3(0, -1000, 0)
	add_child(tree_detection_raycast)
	
	tree_orientation_raycast = RayCast3D.new()
	tree_orientation_raycast.collision_mask = 0xFFFFFFFF  # Tous les layers
	tree_orientation_raycast.target_position = Vector3(0, -1000, 0)
	add_child(tree_orientation_raycast)
	
	# Créer les matériaux pour le feedback visuel
	setup_materials()



func setup_materials():
	# Matériau ghost par défaut (transparent)
	ghost_material = StandardMaterial3D.new()
	ghost_material.albedo_color = Color(1, 1, 1, 0.5)
	ghost_material.flags_transparent = true
	
	# Matériau valide (vert transparent)
	valid_material = StandardMaterial3D.new()
	valid_material.albedo_color = Color(0, 1, 0, 0.7)
	valid_material.flags_transparent = true
	valid_material.emission_enabled = true
	valid_material.emission = Color(0, 0.3, 0)
	
	# Matériau invalide (rouge transparent)
	invalid_material = StandardMaterial3D.new()
	invalid_material.albedo_color = Color(1, 0, 0, 0.7)
	invalid_material.flags_transparent = true
	invalid_material.emission_enabled = true
	invalid_material.emission = Color(0.3, 0, 0)

func start_placement(object_data: Dictionary, is_editing: bool = false):
	# Vérifications de sécurité
	if not builder_camera:
		print("Erreur: builder_camera non disponible pour le placement")
		return
	if not builder_manager:
		print("Erreur: builder_manager non disponible pour le placement")
		return
		
	if is_placing:
		cancel_placement()
	
	current_object_data = object_data
	is_placing = true
	is_editing_mode = is_editing
	
	# Vérifier si c'est un module d'accrobranche
	tree_placement_mode = object_data.get("type") == "tree_module"
	if tree_placement_mode:
		print("Mode placement sur arbre activé pour: ", object_data.name)
	
	# Charger et instancier l'objet ghost
	var scene = load(object_data.scene_path)
	if scene:
		current_ghost_object = scene.instantiate()
		add_child(current_ghost_object)
		
		# Désactiver la physique pour le ghost
		disable_physics_for_ghost(current_ghost_object)
		
		# Appliquer le matériau ghost à tous les MeshInstance3D
		apply_ghost_material(current_ghost_object, ghost_material)
		
		if is_editing:
			print("Mode édition activé pour: ", object_data.name)
		else:
			print("Mode placement initial activé pour: ", object_data.name)
	else:
		print("Erreur: impossible de charger la scène: ", object_data.scene_path)
		is_placing = false

# Ajouter un effet bouncy cartoonesque lors du spawn
func add_bouncy_spawn_effect(object: Node3D):
	if not object:
		return
	
	# Sauvegarder la position et l'échelle finales
	var final_position = object.global_position
	var final_scale = object.scale
	
	# Position de départ : plus haut dans les airs
	var start_position = final_position + Vector3(0, 5, 0)
	object.global_position = start_position
	
	# Échelle de départ : très petite
	object.scale = Vector3(0.1, 0.1, 0.1)
	
	# Rotation aléatoire lors de la chute pour plus de dynamisme
	var random_rotation = randf() * 360.0
	object.rotation_degrees.y += random_rotation
	
	# Créer un Tween pour l'animation
	var tween = create_tween()
	tween.set_parallel(true)  # Permet plusieurs animations simultanées
	
	# Animation de chute avec rebond (easing bounce)
	var position_tween = tween.tween_property(object, "global_position", final_position, 0.6)
	position_tween.set_ease(Tween.EASE_OUT)
	position_tween.set_trans(Tween.TRANS_BOUNCE)
	
	# Animation de l'échelle avec effet "pop"
	var scale_tween = tween.tween_property(object, "scale", final_scale * 1.2, 0.3)
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.set_trans(Tween.TRANS_BACK)
	
	# Deuxième phase : retour à l'échelle normale avec effet élastique (enchaînée)
	var scale_back_tween = tween.tween_property(object, "scale", final_scale, 0.15)
	scale_back_tween.set_delay(0.3)
	scale_back_tween.set_ease(Tween.EASE_IN_OUT)
	scale_back_tween.set_trans(Tween.TRANS_ELASTIC)
	
	# Callback quand l'objet touche le sol pour ajouter du dynamisme
	tween.tween_callback(func():
		add_impact_effect(object, final_position)
	).set_delay(0.6)

# Ajouter un effet d'impact cartoonesque quand l'objet touche le sol
func add_impact_effect(object: Node3D, impact_position: Vector3):
	# Petit tremblement de l'objet
	var shake_tween = create_tween()
	shake_tween.set_loops(3)
	var original_position = object.global_position
	
	shake_tween.tween_property(object, "global_position", original_position + Vector3(0.1, 0, 0), 0.02)
	shake_tween.tween_property(object, "global_position", original_position + Vector3(-0.1, 0, 0), 0.02)
	shake_tween.tween_property(object, "global_position", original_position, 0.02)
	
	# Effet de "squash" temporaire (aplatissement)
	var squash_tween = create_tween()
	squash_tween.set_parallel(true)
	
	var original_scale = object.scale
	squash_tween.tween_property(object, "scale", Vector3(original_scale.x * 1.1, original_scale.y * 0.8, original_scale.z * 1.1), 0.1)
	squash_tween.tween_property(object, "scale", original_scale, 0.1).set_delay(0.1)

func cancel_placement():
	if current_ghost_object:
		# Si on était en mode édition, restaurer l'objet original
		if is_editing_mode and current_ghost_object.has_meta("original_object_data"):
			print("Mode édition annulé - restauration de l'objet original")
			restore_original_object()
		else:
			# Mode placement normal, juste supprimer le ghost
			print("Mode placement normal annulé")
			current_ghost_object.queue_free()
		
		current_ghost_object = null
	
	# Réinitialiser tous les états
	is_placing = false
	is_editing_mode = false
	tree_placement_mode = false
	current_target_tree = null
	current_object_data = {}
	
	# Masquer la grille dynamique
	if grid_system and grid_system.has_method("hide_grid"):
		grid_system.hide_grid()
	
	# Nettoyer les métadonnées temporaires (current_ghost_object est déjà null à ce point)
	# Le nettoyage est fait dans restore_original_object() et restore_dependent_objects_after_editing()
	
	print("Placement annulé - retour au mode normal")

# Fonction de debug pour lister tous les objets placés
func debug_list_placed_objects():
	if not placed_objects_parent:
		print("Debug: placed_objects_parent n'existe pas")
		return
	
	print("Debug: Liste des objets dans placed_objects_parent:")
	for child in placed_objects_parent.get_children():
		print("  - ", child.name, " (Type: ", child.get_class(), ")")
		if child.has_meta("object_data"):
			var obj_data = child.get_meta("object_data")
			print("    object_data: ", obj_data)
		if child.has_meta("is_tree"):
			print("    is_tree: true")
		if child.has_meta("is_tree_module"):
			print("    is_tree_module: true")

# Fonction pour vérifier si on clique sur un objet placé
func check_object_selection(mouse_pos: Vector2) -> Node:
	if not builder_camera or not builder_camera.current:
		print("Debug: Pas de caméra builder disponible")
		return null
	
	# Créer un rayon depuis la caméra vers la position de la souris
	var from = builder_camera.project_ray_origin(mouse_pos)
	var ray_direction = builder_camera.project_ray_normal(mouse_pos)
	
	# Raycast pour détecter les objets
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, from + ray_direction * 1000.0)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	if result and result.collider:
		var clicked_object = result.collider
		print("Debug: Objet cliqué: ", clicked_object.name, " Type: ", clicked_object.get_class())
		
		# Vérifier si c'est un objet placé par le builder
		if is_placed_builder_object(clicked_object):
			print("Debug: Objet reconnu comme objet du builder - sélectionné pour édition")
			return clicked_object
		else:
			print("Debug: Objet non reconnu comme objet du builder")
	
	# Si aucun objet n'est détecté par raycast, essayer de trouver l'objet le plus proche
	print("Debug: Aucun objet détecté par raycast, recherche alternative...")
	var nearest_object = find_nearest_object_at_mouse_pos(mouse_pos)
	if nearest_object:
		print("Debug: Objet trouvé par recherche alternative: ", nearest_object.name)
		if is_placed_builder_object(nearest_object):
			print("Debug: Objet alternatif reconnu comme objet du builder - sélectionné pour édition")
			return nearest_object
		else:
			print("Debug: Objet alternatif non reconnu comme objet du builder")
	
	return null

# Fonction pour trouver l'objet le plus proche de la position de la souris
func find_nearest_object_at_mouse_pos(mouse_pos: Vector2) -> Node:
	if not builder_camera or not builder_camera.current:
		return null
	
	# Créer un rayon depuis la caméra vers la position de la souris
	var from = builder_camera.project_ray_origin(mouse_pos)
	var ray_direction = builder_camera.project_ray_normal(mouse_pos)
	
	# Projeter le rayon sur un plan horizontal à la hauteur moyenne des objets
	var plane_height = 5.0  # Hauteur moyenne des objets
	var plane_normal = Vector3(0, 1, 0)
	var plane_point = Vector3(0, plane_height, 0)
	
	var intersection = ray_intersect_plane(from, ray_direction, plane_point, plane_normal)
	if not intersection:
		return null
	
	# Chercher l'objet le plus proche de ce point
	var nearest_object: Node = null
	var nearest_distance = 999999.0
	
	if placed_objects_parent:
		for child in placed_objects_parent.get_children():
			if is_placed_builder_object(child):
				var distance = child.global_position.distance_to(intersection)
				if distance < nearest_distance and distance < 10.0:  # Limite de 10 unités
					nearest_distance = distance
					nearest_object = child
	
	return nearest_object

# Fonction pour vérifier si un objet a été placé par le builder
func is_placed_builder_object(obj: Node) -> bool:
	print("Debug: Vérification de l'objet: ", obj.name, " Type: ", obj.get_class())
	
	# Ignorer les objets du terrain et du sol
	if obj.name in ["GroundPlane", "Terrain3D"] or obj.get_class() in ["StaticBody3D", "Terrain3D"]:
		print("Debug: Objet ignoré (terrain/sol)")
		return false
	
	# Vérifier les métadonnées du builder
	if obj.has_meta("object_data"):
		var object_data = obj.get_meta("object_data")
		print("Debug: Objet a meta object_data - type: ", object_data.get("type", "inconnu"))
		# Vérifier si c'est un arbre via object_data
		if object_data.get("type") == "tree" or "tree" in object_data.get("name", "").to_lower():
			print("Debug: Objet reconnu comme arbre par object_data")
		return true
	if obj.has_meta("is_tree_module"):
		print("Debug: Objet a meta is_tree_module")
		return true
	if obj.has_meta("is_tree"):
		print("Debug: Objet a meta is_tree")
		return true
	
	# Vérifier si c'est un arbre (par nom ou type)
	if obj.name.to_lower().contains("tree") or obj.name.to_lower().contains("arbre"):
		print("Debug: Objet reconnu comme arbre par nom")
		return true
	
	# Vérifier si l'objet est directement dans le parent des objets placés
	if placed_objects_parent and obj.get_parent() == placed_objects_parent:
		print("Debug: Objet est directement dans placed_objects_parent")
		return true
	
	# Vérifier si l'objet est un descendant du parent des objets placés
	if placed_objects_parent and placed_objects_parent.is_ancestor_of(obj):
		print("Debug: Objet est descendant de placed_objects_parent")
		return true
	
	# Vérifier si l'objet est un ancêtre du parent des objets placés
	if placed_objects_parent and obj.is_ancestor_of(placed_objects_parent):
		print("Debug: Objet est ancêtre de placed_objects_parent")
		return true
	
	print("Debug: Objet non reconnu comme objet du builder")
	return false

# Fonction pour commencer l'édition d'un objet placé
func start_object_editing(placed_object: Node):
	# Sauvegarder les données de l'objet original pour restauration en cas d'annulation
	var original_object_data = {
		"position": placed_object.global_position,
		"rotation": placed_object.global_rotation,
		"object_data": placed_object.get_meta("object_data") if placed_object.has_meta("object_data") else {},
		"is_tree_module": placed_object.has_meta("is_tree_module"),
		"attached_tree": placed_object.get_meta("attached_tree") if placed_object.has_meta("attached_tree") else null
	}
	
	# Vérifier si l'objet a des dépendants
	var dependent_objects = get_dependent_objects(placed_object)
	
	# Sauvegarder les informations des dépendants AVANT de les supprimer (si il y en a)
	var dependent_positions = {}
	if dependent_objects.size() > 0:
		print("Objet ", placed_object.name, " a ", dependent_objects.size(), " dépendant(s) - déplacement en cascade activé")
		
		for dep_obj in dependent_objects:
			if is_instance_valid(dep_obj):  # Vérifier que l'objet est toujours valide
				dependent_positions[dep_obj.name] = {
					"position": dep_obj.global_position,
					"rotation": dep_obj.global_rotation,
					"object_data": dep_obj.get_meta("object_data") if dep_obj.has_meta("object_data") else {},
					"is_tree_module": dep_obj.has_meta("is_tree_module"),
					"attached_tree": dep_obj.get_meta("attached_tree") if dep_obj.has_meta("attached_tree") else null
				}
		
		# Supprimer temporairement les dépendants de la scène
		for dep_obj in dependent_objects:
			if is_instance_valid(dep_obj):
				dep_obj.queue_free()
		
		print("Mode déplacement en cascade activé - les dépendants suivront l'objet principal")
	
	# Sauvegarder les informations de l'objet
	var object_data = {}
	if placed_object.has_meta("object_data"):
		object_data = placed_object.get_meta("object_data")
	else:
		# Créer des données par défaut basées sur le type d'objet
		object_data = {
			"name": placed_object.name,
			"type": "custom" if placed_object.has_meta("is_tree_module") else "structure"
		}
	
	# Vérifier que object_data contient un scene_path
	if not object_data.has("scene_path") or object_data.scene_path == "":
		print("Erreur: object_data ne contient pas de scene_path pour l'objet: ", placed_object.name)
		print("object_data: ", object_data)
		return
	
	# Sauvegarder la position et rotation actuelles
	var original_position = placed_object.global_position
	var original_rotation = placed_object.global_rotation
	
	# Supprimer l'objet de la scène immédiatement
	placed_object.get_parent().remove_child(placed_object)
	# Ne pas utiliser queue_free() immédiatement pour éviter les conflits de timing
	# L'objet sera supprimé définitivement dans attempt_place_object
	
	# Démarrer le placement en mode édition
	start_placement(object_data, true)  # true = mode édition
	
	# Vérifier que le ghost a été créé correctement
	if not current_ghost_object:
		print("Erreur: Impossible de créer le ghost pour l'édition de l'objet: ", placed_object.name)
		return
	
	# Positionner le ghost à l'ancienne position
	if current_ghost_object:
		current_ghost_object.global_position = original_position
		current_ghost_object.global_rotation = original_rotation
		
		# Stocker les données originales pour restauration en cas d'annulation
		current_ghost_object.set_meta("original_object_data", original_object_data)
		
		# Stocker les informations des dépendants si il y en a
		if dependent_positions.size() > 0:
			current_ghost_object.set_meta("dependent_objects_data", dependent_positions)
			current_ghost_object.set_meta("has_dependents", true)
			print("Informations des dépendants stockées sur le ghost")
		
		# Si c'était un module d'accrobranche, réactiver le mode placement sur arbre
		if object_data.get("type") == "tree_module":
			tree_placement_mode = true
			print("Mode placement sur arbre réactivé pour l'édition du module")
			# Chercher l'arbre le plus proche pour le mode placement sur arbre
			var mouse_pos = get_viewport().get_mouse_position()
			var from = builder_camera.project_ray_origin(mouse_pos)
			var ray_direction = builder_camera.project_ray_normal(mouse_pos)
			var nearest_tree = find_nearest_tree(from, ray_direction)
			if nearest_tree:
				current_target_tree = nearest_tree
				print("Arbre ciblé pour l'édition: ", nearest_tree.name)
			else:
				print("Aucun arbre trouvé pour l'édition du module")

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Vérifier si le clic a lieu sur l'UI de la boutique
			if is_click_on_ui(event.position):
				print("Clic sur l'UI détecté - placement ignoré")
				return
			
			if is_placing and current_ghost_object:
				# Mode placement/édition actif : placer l'objet
				attempt_place_object()
			else:
				# Mode normal : vérifier si on clique sur un objet placé
				print("Debug: Tentative de sélection d'objet...")
				debug_list_placed_objects()  # Debug: lister les objets disponibles
				var clicked_object = check_object_selection(event.position)
				if clicked_object:
					# Si on a cliqué sur un objet, le mettre en mode édition
					start_object_editing(clicked_object)
					print("Objet sélectionné pour édition: ", clicked_object.name)
				else:
					print("Debug: Aucun objet sélectionné")
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if is_placing and current_ghost_object:
				# Clic droit pour désélectionner
				cancel_placement()
				print("Désélection par clic droit")
	
	# Gestion des touches clavier
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if is_placing and current_ghost_object:
				# Échap pour annuler le placement/édition
				cancel_placement()
				print("Placement/édition annulé par Échap")

func _process(_delta):
	# Vérifications de sécurité
	if not is_placing or not current_ghost_object:
		return
	if not builder_camera or not builder_camera.current:
		return
	
	# Vérifier que l'objet ghost est bien dans l'arbre de la scène
	if not current_ghost_object.is_inside_tree():
		return
	
	# Limiter la fréquence de mise à jour pour éviter les va-et-vient
	if Engine.get_process_frames() % 3 == 0:  # Mise à jour tous les 3 frames
		update_ghost_position()
		update_ghost_feedback()

func update_ghost_position():
	if not current_ghost_object or not builder_camera:
		return
	
	# Vérifier que l'objet ghost est bien dans l'arbre de la scène
	if not current_ghost_object.is_inside_tree():
		return
		
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = builder_camera
	
	# Créer un rayon depuis la caméra vers la position de la souris
	var from = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	if tree_placement_mode:
		# Mode placement sur arbre pour les modules d'accrobranche
		update_tree_placement_position(from, ray_direction)
	else:
		# Mode placement normal sur le terrain
		update_normal_placement_position(from, ray_direction)

func update_tree_placement_position(from: Vector3, ray_direction: Vector3):
	# Détecter l'arbre le plus proche du raycast de la souris
	var nearest_tree = find_nearest_tree(from, ray_direction)
	
	if nearest_tree:
		current_target_tree = nearest_tree
		var tree_position = nearest_tree.global_position
		
		# Obtenir la hauteur du terrain à la base de l'arbre
		var terrain_height = get_terrain_height_at_position(tree_position)
		
		# Positionner le module à la base de l'arbre, légèrement au-dessus du terrain
		var module_position = Vector3(tree_position.x, terrain_height + 0.5, tree_position.z)
		current_ghost_object.global_position = module_position
		
		# Orienter le module autour de l'arbre pivot
		var mouse_pos = get_viewport().get_mouse_position()
		orient_module_around_tree_pivot(tree_position, module_position, mouse_pos)
		
		# Mettre à jour la position de grille
		if grid_system and grid_system.has_method("get_nearest_cell"):
			var grid_pos = grid_system.get_nearest_cell(module_position)
			current_ghost_object.set_meta("grid_position", grid_pos)
	else:
		# Aucun arbre trouvé, réinitialiser current_target_tree et ne pas positionner le module
		current_target_tree = null
		print("Aucun arbre trouvé - module ne peut pas être placé")

func update_normal_placement_position(from: Vector3, ray_direction: Vector3):
	# Calculer la position sur un plan horizontal (Y=0) d'abord
	var target_position: Vector3
	if abs(ray_direction.y) > 0.001:  # Éviter division par zéro
		var ground_y = 0.0
		var t = (ground_y - from.y) / ray_direction.y
		if t > 0:  # Ray pointe vers le bas
			target_position = from + ray_direction * t
		else:
			# Si le ray pointe vers le haut, utiliser une distance fixe
			target_position = from + ray_direction * 50.0
			target_position.y = 0
	else:
		# Direction horizontale, projeter à distance fixe
		target_position = from + ray_direction * 50.0
		target_position.y = 0
	
	# Récupérer la hauteur du terrain à la position exacte du curseur
	var terrain_height = get_terrain_height_at_position(target_position)
	target_position.y = terrain_height
	
	# Positionner le ghost à la position exacte du curseur (placement libre)
	current_ghost_object.global_position = target_position
	
	# Garder la référence à la grille pour la validation, mais sans forcer l'accrochage
	if grid_system and grid_system.has_method("get_nearest_cell"):
		var grid_pos = grid_system.get_nearest_cell(target_position)
		current_ghost_object.set_meta("grid_position", grid_pos)
		
		# Mettre à jour la grille dynamique autour du ghost (pour l'affichage)
		if grid_system and grid_system.has_method("update_dynamic_grid") and current_ghost_object.is_inside_tree():
			grid_system.update_dynamic_grid(target_position)

func update_ghost_feedback():
	if not current_ghost_object:
		return
	
	var is_valid_position = false
	
	if tree_placement_mode:
		# Pour les modules d'accrobranche, vérifier qu'un arbre est ciblé ET qu'aucun module n'est déjà présent
		if current_target_tree:
			# Vérifier que le module est bien positionné sur l'arbre
			var distance_to_tree = current_ghost_object.global_position.distance_to(current_target_tree.global_position)
			if distance_to_tree > 2.0:
				is_valid_position = false
				print("Module invalide - trop loin de l'arbre (distance: ", distance_to_tree, ")")
			else:
				# Vérifier qu'aucun module d'accrobranche n'est déjà présent sur cet arbre
				is_valid_position = not is_tree_already_occupied(current_target_tree)
				if is_valid_position:
					print("Module valide sur l'arbre: ", current_target_tree.name, " (distance: ", distance_to_tree, ")")
				else:
					print("Module invalide - arbre déjà occupé: ", current_target_tree.name)
		else:
			is_valid_position = false
			print("Module invalide - aucun arbre ciblé")
	else:
		# Mode placement normal
		if grid_system and current_ghost_object.has_meta("grid_position"):
			var grid_pos = current_ghost_object.get_meta("grid_position")
			is_valid_position = grid_system.can_place_at(grid_pos)
		else:
			# Fallback : ancien système de validation
			is_valid_position = check_valid_placement_position()
	
	if is_valid_position:
		apply_ghost_material(current_ghost_object, valid_material)
	else:
		apply_ghost_material(current_ghost_object, invalid_material)

func check_valid_placement_position() -> bool:
	if not current_ghost_object:
		return false
	
	# Vérifier si l'objet n'est pas en collision avec d'autres objets
	var ghost_pos = current_ghost_object.global_position
	
	# Vérifier la proximité avec d'autres objets placés
	for child in placed_objects_parent.get_children():
		var distance = ghost_pos.distance_to(child.global_position)
		if distance < 3.0:  # Distance minimum entre objets
			return false
	
	# Autres vérifications possibles (limites du terrain, etc.)
	return true

func attempt_place_object():
	if not current_ghost_object:
		print("Erreur: Pas d'objet ghost disponible")
		return
		
	var is_valid = false
	var grid_pos: Vector2i
	
	if tree_placement_mode:
		# Pour les modules d'accrobranche, vérifier qu'un arbre est ciblé ET qu'aucun module n'est déjà présent
		if not current_target_tree:
			print("Erreur: Aucun arbre ciblé pour le module d'accrobranche - placement impossible")
			return
		
		# Vérifier que le module est bien positionné sur l'arbre (distance < 2 unités)
		var distance_to_tree = current_ghost_object.global_position.distance_to(current_target_tree.global_position)
		if distance_to_tree > 2.0:
			print("Erreur: Module trop loin de l'arbre ciblé (distance: ", distance_to_tree, ") - placement impossible")
			return
		
		# Vérifier qu'aucun module d'accrobranche n'est déjà présent sur cet arbre
		is_valid = not is_tree_already_occupied(current_target_tree)
		if not is_valid:
			print("Erreur: Un module d'accrobranche est déjà présent sur cet arbre - placement impossible")
			return
		
		print("Module d'accrobranche validé pour placement sur l'arbre: ", current_target_tree.name)
	else:
		# Mode placement normal
		if grid_system and current_ghost_object.has_meta("grid_position"):
			grid_pos = current_ghost_object.get_meta("grid_position")
			is_valid = grid_system.can_place_at(grid_pos)
		else:
			is_valid = check_valid_placement_position()
	
	if not is_valid:
		print("Position invalide pour le placement")
		return
	
	# Vérifier si le joueur a assez d'argent
	if not builder_manager.spend_money(current_object_data.price):
		print("Pas assez d'argent pour placer l'objet")
		return
	
	# Utiliser la position exacte du ghost
	var placement_position = current_ghost_object.global_position
	
	# Debug simplifié
	print("Placement de: ", current_object_data.name, " à la position: ", placement_position)
	
	if is_editing_mode:
		# En mode édition, transformer le ghost en objet final
		# L'ancien objet a déjà été retiré de la scène dans start_object_editing
		
		print("Transformation du ghost en objet final en mode édition")
		
		# Le ghost devient l'objet final
		var final_object = current_ghost_object
		
		# Retirer le ghost de son parent actuel (PlacementManager)
		remove_child(final_object)
		
		# Ajouter à la scène des objets placés
		if placed_objects_parent:
			placed_objects_parent.add_child(final_object)
		else:
			# Fallback: ajouter directement à la scène principale
			get_tree().current_scene.add_child(final_object)
		
		# Marquer l'objet avec les métadonnées du builder
		final_object.set_meta("object_data", current_object_data)
		
		# Marquer spécifiquement les arbres
		if current_object_data.get("type") == "tree" or "tree" in current_object_data.get("name", "").to_lower():
			final_object.set_meta("is_tree", true)
			print("Arbre marqué avec métadonnée is_tree en mode édition: ", final_object.name)
		
		# Marquer l'objet comme module d'accrobranche si nécessaire
		if tree_placement_mode:
			final_object.set_meta("is_tree_module", true)
			final_object.set_meta("attached_tree", current_target_tree)
			
			# Enregistrer la dépendance du module vers l'arbre
			if current_target_tree:
				register_dependency(final_object, current_target_tree, "attached_to_tree")
				print("Dépendance enregistrée: Module ", final_object.name, " attaché à l'arbre ", current_target_tree.name)
		
		# S'assurer que l'objet est visible et restaurer les matériaux normaux
		final_object.visible = true
		restore_normal_materials(final_object)
		
		# Attendre un frame pour que l'objet soit complètement initialisé
		await get_tree().process_frame
		
		# La position est déjà correcte (celle du ghost)
		print("Objet déplacé: ", current_object_data.name, " à la position: ", final_object.global_position)
		
		# Ajouter l'effet bouncy au spawn
		add_bouncy_spawn_effect(final_object)
		
		# Marquer la cellule comme occupée dans la grille
		if grid_system and final_object.has_meta("grid_position"):
			var final_grid_pos = final_object.get_meta("grid_position")
			grid_system.place_object(final_grid_pos, final_object)
		
		# Nettoyer les métadonnées temporaires
		final_object.set_meta("original_object_data", null)
		final_object.set_meta("dependent_objects_data", null)
		
		# Réinitialiser current_ghost_object car il est maintenant l'objet final
		current_ghost_object = null
	else:
		# Mode placement initial - créer un nouvel objet
		var final_scene = load(current_object_data.scene_path)
		if final_scene:
			var final_object = final_scene.instantiate()
			
			# S'assurer que l'objet est visible
			final_object.visible = true
			
			# Ajouter à la scène AVANT de définir la position
			if placed_objects_parent:
				placed_objects_parent.add_child(final_object)
			else:
				# Fallback: ajouter directement à la scène principale
				get_tree().current_scene.add_child(final_object)
			
			# Marquer l'objet avec les métadonnées du builder
			final_object.set_meta("object_data", current_object_data)
			
			# Marquer spécifiquement les arbres
			if current_object_data.get("type") == "tree" or "tree" in current_object_data.get("name", "").to_lower():
				final_object.set_meta("is_tree", true)
				print("Arbre marqué avec métadonnée is_tree: ", final_object.name)
			
			# Marquer l'objet comme module d'accrobranche si nécessaire
			if tree_placement_mode:
				final_object.set_meta("is_tree_module", true)
				final_object.set_meta("attached_tree", current_target_tree)
				
				# Enregistrer la dépendance du module vers l'arbre
				if current_target_tree:
					register_dependency(final_object, current_target_tree, "attached_to_tree")
					print("Dépendance enregistrée: Module ", final_object.name, " attaché à l'arbre ", current_target_tree.name)
			
			# Attendre un frame pour que l'objet soit complètement initialisé
			await get_tree().process_frame
			
			# MAINTENANT définir la position (après l'ajout à la scène)
			final_object.global_position = placement_position
			final_object.global_rotation = current_ghost_object.global_rotation
			
			# Si la position n'a pas été appliquée correctement, forcer avec transform
			if final_object.global_position.distance_to(placement_position) > 0.1:
				final_object.global_transform.origin = placement_position
				
				# Si ça ne marche toujours pas, essayer position locale
				if final_object.global_position.distance_to(placement_position) > 0.1:
					final_object.position = placement_position
			
			print("Objet placé: ", current_object_data.name, " à la position: ", final_object.global_position)
			
			# Ajouter l'effet bouncy au spawn
			add_bouncy_spawn_effect(final_object)
			
			# Marquer la cellule comme occupée dans la grille
			if grid_system and current_ghost_object.has_meta("grid_position"):
				var final_grid_pos = current_ghost_object.get_meta("grid_position")
				grid_system.place_object(final_grid_pos, final_object)
		else:
			print("Erreur: Impossible de charger la scène pour le placement: ", current_object_data.scene_path)
	
	# Si on était en mode édition, quitter après le placement
	if is_editing_mode:
		# En mode édition, le ghost a été transformé en objet final
		# current_ghost_object est maintenant null
		
		# Restaurer les dépendants si nécessaire
		restore_dependent_objects_after_editing()
		
		# Réinitialiser les états (current_ghost_object est déjà null)
		is_placing = false
		is_editing_mode = false
		tree_placement_mode = false
		current_target_tree = null
		current_object_data = {}
		
		# Masquer la grille dynamique après placement
		if grid_system and grid_system.has_method("hide_grid"):
			grid_system.hide_grid()
		
		print("Mode édition terminé après placement - objet déplacé")
	else:
		# Continuer le placement du même objet (mode placement initial)
		# (Le ghost reste actif pour placer d'autres instances)
		print("Mode placement initial continué - ghost actif pour d'autres placements")

func apply_ghost_material(node: Node3D, material: Material):
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var surface_count = mesh_instance.get_surface_override_material_count()
		if surface_count == 0:
			surface_count = mesh_instance.mesh.get_surface_count() if mesh_instance.mesh else 1
		
		for i in range(surface_count):
			mesh_instance.set_surface_override_material(i, material)
	
	# Appliquer récursivement aux enfants
	for child in node.get_children():
		apply_ghost_material(child, material)

# Fonction pour restaurer les matériaux normaux d'un objet
func restore_normal_materials(node: Node3D):
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var surface_count = mesh_instance.get_surface_override_material_count()
		
		# Supprimer tous les matériaux override pour restaurer les matériaux originaux
		for i in range(surface_count):
			mesh_instance.set_surface_override_material(i, null)
	
	# Appliquer récursivement aux enfants
	for child in node.get_children():
		restore_normal_materials(child)

# Fonction pour obtenir la hauteur du terrain à une position donnée
func get_terrain_height_at_position(world_pos: Vector3) -> float:
	var space_state = get_world_3d().direct_space_state
	var raycast_from = Vector3(world_pos.x, 200, world_pos.z)
	var raycast_to = Vector3(world_pos.x, -50, world_pos.z)
	
	var query = PhysicsRayQueryParameters3D.create(raycast_from, raycast_to)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y
	else:
		return 0.0

# Fonction pour trouver l'arbre le plus proche du raycast
func find_nearest_tree(from: Vector3, ray_direction: Vector3) -> Node3D:
	var nearest_tree: Node3D = null
	var nearest_distance = 999999.0
	
	# Parcourir tous les nœuds de la scène pour trouver les arbres
	var scene_root = get_tree().current_scene
	var trees = find_trees_in_scene(scene_root)
	
	# Si aucun arbre n'est trouvé, retourner null
	if trees.size() == 0:
		return null
	
	# Créer un plan horizontal à la hauteur du terrain (Y=0)
	var plane_normal = Vector3(0, 1, 0)
	var plane_point = Vector3(0, 0, 0)
	
	# Intersecter le ray avec le plan horizontal du terrain
	var ray_plane_intersection = ray_intersect_plane(from, ray_direction, plane_point, plane_normal)
	if not ray_plane_intersection:
		return null
	
	var ray_ground_point = ray_plane_intersection
	
	# Trouver l'arbre le plus proche du point d'intersection
	for i in range(trees.size()):
		var tree = trees[i]
		# Utiliser la position réelle de l'arbre au niveau du terrain
		var tree_ground_pos = Vector3(tree.global_position.x, 0, tree.global_position.z)
		var distance = ray_ground_point.distance_to(tree_ground_pos)
		
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_tree = tree
	
	# Ne retourner l'arbre que s'il est suffisamment proche (dans un rayon de 5 cases de grille)
	var max_detection_distance = 20.0  # 5 cases * 4 unités par case
	if nearest_tree and nearest_distance < max_detection_distance:
		return nearest_tree
	
	return null

# Fonction pour trouver tous les arbres dans la scène
func find_trees_in_scene(node: Node) -> Array[Node3D]:
	var trees: Array[Node3D] = []
	
	# Vérifier si ce nœud est un arbre
	if is_tree_node(node) and node is Node3D:
		trees.append(node as Node3D)
	
	# Parcourir récursivement les enfants
	for child in node.get_children():
		var child_trees = find_trees_in_scene(child)
		trees.append_array(child_trees)
	
	# Rechercher spécifiquement dans le système Terrain3D
	var terrain3d = find_terrain3d_in_scene(node)
	if terrain3d:
		var terrain_trees = find_trees_in_terrain3d(terrain3d)
		trees.append_array(terrain_trees)
	
	return trees

# Fonction pour trouver le système Terrain3D dans la scène
func find_terrain3d_in_scene(node: Node) -> Node3D:
	if node is Node3D and node.name == "Terrain3D":
		return node
	
	for child in node.get_children():
		var result = find_terrain3d_in_scene(child)
		if result:
			return result
	
	return null

# Fonction pour trouver les arbres dans le système Terrain3D
func find_trees_in_terrain3d(terrain3d: Node3D) -> Array[Node3D]:
	var trees: Array[Node3D] = []
	
	# Parcourir les enfants du Terrain3D pour trouver les instances d'arbres
	for child in terrain3d.get_children():
		if child.name == "Instances" or "instance" in child.name.to_lower():
			var instance_trees = find_trees_in_instances(child)
			trees.append_array(instance_trees)
	
	return trees

# Fonction pour trouver les arbres dans les instances Terrain3D
func find_trees_in_instances(instances_node: Node) -> Array[Node3D]:
	var trees: Array[Node3D] = []
	
	for child in instances_node.get_children():
		# Vérifier si c'est une instance d'arbre ET que c'est un Node3D
		if is_tree_instance(child) and child is Node3D:
			trees.append(child as Node3D)
	
	return trees

# Fonction pour vérifier si un nœud est une instance d'arbre
func is_tree_instance(node: Node) -> bool:
	# Vérifier par le nom du fichier de scène
	if node.scene_file_path and "tree" in node.scene_file_path.to_lower():
		return true
	
	# Vérifier par le nom du nœud
	if node.name and "tree" in node.name.to_lower():
		return true
	
	# Vérifier par les métadonnées Terrain3D
	if node.has_meta("terrain3d_mesh_name") and "tree" in str(node.get_meta("terrain3d_mesh_name")).to_lower():
		return true
	
	return false

# Fonction pour vérifier si un nœud est un arbre
func is_tree_node(node: Node) -> bool:
	# Vérifier par le nom du fichier de scène
	if node.scene_file_path and "tree" in node.scene_file_path.to_lower():
		return true
	
	# Vérifier par le nom du nœud
	if node.name and "tree" in node.name.to_lower():
		return true
	
	# Vérifier par les métadonnées ou tags
	if node.has_meta("is_tree"):
		return node.get_meta("is_tree")
	
	return false

# Fonction pour calculer l'intersection d'un ray avec un plan
func ray_intersect_plane(ray_origin: Vector3, ray_direction: Vector3, plane_point: Vector3, plane_normal: Vector3) -> Vector3:
	var denom = ray_direction.dot(plane_normal)
	if abs(denom) < 0.0001:
		return Vector3.ZERO  # Ray parallèle au plan
	
	var t = (plane_point - ray_origin).dot(plane_normal) / denom
	if t < 0:
		return Vector3.ZERO  # Intersection derrière le ray
	
	return ray_origin + ray_direction * t

# Fonction pour orienter le module autour de l'arbre pivot
func orient_module_around_tree_pivot(tree_position: Vector3, module_position: Vector3, mouse_screen_pos: Vector2):
	# Obtenir la caméra builder
	var camera = builder_camera
	if not camera:
		return
	
	# Projeter la position de l'arbre sur l'écran
	var tree_screen_pos = camera.unproject_position(tree_position)
	
	# Calculer le vecteur de la souris par rapport à l'arbre sur l'écran
	var mouse_to_tree = mouse_screen_pos - tree_screen_pos
	
	# Calculer l'angle de la souris autour de l'arbre (dans le plan horizontal)
	var angle = atan2(mouse_to_tree.x, mouse_to_tree.y)
	
	# Ajuster l'angle pour une orientation plus naturelle
	# L'angle 0 pointe vers le haut de l'écran, nous voulons que le module pointe vers la souris
	angle += PI  # Rotation de 180 degrés pour corriger l'orientation
	

	
	# Appliquer la rotation au module
	current_ghost_object.rotation.y = angle



# Fonction pour vérifier si un arbre est déjà occupé par un module d'accrobranche
func is_tree_already_occupied(tree: Node3D) -> bool:
	# Vérifier dans les objets déjà placés
	for child in placed_objects_parent.get_children():
		# Vérifier si c'est un module d'accrobranche
		if child.has_meta("is_tree_module") or (child.has_meta("object_data") and child.get_meta("object_data").get("type") == "tree_module"):
			# Vérifier si ce module est proche de l'arbre (dans un rayon de 2 unités)
			var distance = child.global_position.distance_to(tree.global_position)
			if distance < 2.0:
				# En mode édition, ignorer l'objet qui est en cours d'édition
				if is_editing_mode and current_ghost_object and current_ghost_object.has_meta("original_object_data"):
					var original_data = current_ghost_object.get_meta("original_object_data")
					# Si c'est le même objet (même position), l'ignorer
					if child.global_position.distance_to(original_data.position) < 0.1:
						continue
				return true
	
	return false

# Fonction pour désactiver la physique d'un objet ghost
func disable_physics_for_ghost(node: Node3D):
	# Désactiver RigidBody3D
	if node is RigidBody3D:
		var rigid_body = node as RigidBody3D
		rigid_body.freeze = true
		rigid_body.gravity_scale = 0
		rigid_body.set_collision_layer(0)
		rigid_body.set_collision_mask(0)
	
	# Désactiver CharacterBody3D
	elif node is CharacterBody3D:
		var char_body = node as CharacterBody3D
		char_body.set_collision_layer(0)
		char_body.set_collision_mask(0)
	
	# Désactiver StaticBody3D
	elif node is StaticBody3D:
		var static_body = node as StaticBody3D
		static_body.set_collision_layer(0)
		static_body.set_collision_mask(0)
	
	# Désactiver les CollisionShape3D directement
	for child in node.get_children():
		if child is CollisionShape3D:
			child.disabled = true
		else:
			disable_physics_for_ghost(child)

# Fonction pour restaurer l'objet original en cas d'annulation
func restore_original_object():
	if not current_ghost_object or not current_ghost_object.has_meta("original_object_data"):
		return
	
	var original_data = current_ghost_object.get_meta("original_object_data")
	
	# L'objet original a été supprimé, nous devons le recréer
	print("Restauration de l'objet: ", original_data.object_data.get("name", "Inconnu"))
	
	# Charger la scène de l'objet original
	var original_scene = load(original_data.object_data.scene_path)
	if original_scene:
		var restored_object = original_scene.instantiate()
		
		# Restaurer les métadonnées
		if original_data.object_data.size() > 0:
			restored_object.set_meta("object_data", original_data.object_data)
		if original_data.is_tree_module:
			restored_object.set_meta("is_tree_module", true)
		if original_data.attached_tree:
			restored_object.set_meta("attached_tree", original_data.attached_tree)
		
		# Ajouter à la scène
		placed_objects_parent.add_child(restored_object)
		
		# Restaurer la position et rotation originales
		restored_object.global_position = original_data.position
		restored_object.global_rotation = original_data.rotation
		
		# Réenregistrer les dépendances si nécessaire
		if original_data.is_tree_module and original_data.attached_tree:
			# Vérifier que l'arbre attaché existe toujours
			if is_instance_valid(original_data.attached_tree):
				register_dependency(restored_object, original_data.attached_tree, "attached_to_tree")
				print("Dépendance réenregistrée pour l'objet restauré")
		
		print("Objet restauré: ", restored_object.name, " à la position: ", restored_object.global_position)
		
		# Supprimer complètement le ghost après restauration
		if current_ghost_object:
			current_ghost_object.queue_free()
			current_ghost_object = null
		
		# Réinitialiser les états
		is_placing = false
		is_editing_mode = false
		tree_placement_mode = false
		current_target_tree = null
		current_object_data = {}
		
		print("Ghost supprimé et mode édition quitté")
	else:
		print("Erreur: Impossible de charger la scène pour restaurer l'objet: ", original_data.object_data.get("name", "Inconnu"))

# Fonction pour restaurer les dépendants après édition
func restore_dependent_objects_after_editing():
	# Cette fonction sera appelée après le placement en mode édition
	# pour restaurer les objets dépendants à leurs nouvelles positions
	
	if not current_ghost_object or not current_ghost_object.has_meta("dependent_objects_data"):
		return
	
	var dependent_objects_data = current_ghost_object.get_meta("dependent_objects_data")
	var final_object_position = current_ghost_object.global_position
	var final_object_rotation = current_ghost_object.global_rotation
	
	print("Restauration de ", dependent_objects_data.size(), " objet(s) dépendant(s)")
	
	for dependent_name in dependent_objects_data:
		var dep_data = dependent_objects_data[dependent_name]
		
		# Charger la scène de l'objet dépendant
		var dependent_scene = load(dep_data.object_data.scene_path)
		if dependent_scene:
			var dependent_object = dependent_scene.instantiate()
			
			# Restaurer les métadonnées
			if dep_data.object_data.size() > 0:
				dependent_object.set_meta("object_data", dep_data.object_data)
			if dep_data.is_tree_module:
				dependent_object.set_meta("is_tree_module", true)
			if dep_data.attached_tree:
				dependent_object.set_meta("attached_tree", dep_data.attached_tree)
			
			# Ajouter à la scène
			placed_objects_parent.add_child(dependent_object)
			
			# Positionner l'objet dépendant par rapport à la nouvelle position de l'objet principal
			var relative_offset = dep_data.position - final_object_position
			dependent_object.global_position = final_object_position + relative_offset
			dependent_object.global_rotation = dep_data.rotation
			
			# Réenregistrer la dépendance avec l'objet final placé
			# L'objet final sera l'objet qui vient d'être placé
			print("Dépendance restaurée pour: ", dependent_name)
			
			print("Objet dépendant restauré: ", dependent_name, " à la position: ", dependent_object.global_position)
		else:
			print("Erreur: Impossible de charger la scène pour l'objet dépendant: ", dependent_name)
	
	# Nettoyer les métadonnées temporaires
	current_ghost_object.set_meta("dependent_objects_data", null)

# === FONCTIONS DE GESTION DES DÉPENDANCES INTÉGRÉES ===

# Générer un ID unique pour un objet
func generate_object_id() -> String:
	next_object_id += 1
	return "obj_" + str(next_object_id)

# Obtenir l'ID d'un objet
func get_object_id(obj: Node) -> String:
	if obj.has_meta("dependency_id"):
		return obj.get_meta("dependency_id")
	return ""

# Définir l'ID d'un objet
func set_object_id(obj: Node, id: String):
	obj.set_meta("dependency_id", id)

# Enregistrer une dépendance entre deux objets
func register_dependency(dependent_object: Node, dependency_object: Node, dependency_type: String = "attached"):
	var dependent_id = get_object_id(dependent_object)
	var dependency_id = get_object_id(dependency_object)
	
	if not dependent_id:
		dependent_id = generate_object_id()
		set_object_id(dependent_object, dependent_id)
	
	if not dependency_id:
		dependency_id = generate_object_id()
		set_object_id(dependency_object, dependency_id)
	
	# Ajouter la dépendance
	if not dependencies.has(dependent_id):
		dependencies[dependent_id] = []
	
	var dependency_info = {
		"object": dependency_object,
		"type": dependency_type,
		"id": dependency_id
	}
	
	dependencies[dependent_id].append(dependency_info)
	
	# Ajouter la dépendance inverse
	if not reverse_dependencies.has(dependency_id):
		reverse_dependencies[dependency_id] = []
	
	reverse_dependencies[dependency_id].append({
		"object": dependent_object,
		"type": dependency_type,
		"id": dependency_id
	})
	
	print("Dépendance enregistrée: ", dependent_object.name, " -> ", dependency_object.name, " (", dependency_type, ")")

# Obtenir tous les objets dépendants d'un objet donné
func get_dependent_objects(object: Node) -> Array:
	var object_id = get_object_id(object)
	if not object_id or not reverse_dependencies.has(object_id):
		return []
	
	var dependents = []
	for dep_info in reverse_dependencies[object_id]:
		dependents.append(dep_info.object)
	
	return dependents

# Fonction utilitaire pour trouver un nœud par métadonnée
func get_node_by_meta(meta_key: String, meta_value: String) -> Node:
	# Chercher dans la scène (peut être optimisé)
	var scene_root = get_tree().current_scene
	return find_node_by_meta_recursive(scene_root, meta_key, meta_value)

# Fonction récursive pour trouver un nœud par métadonnée
func find_node_by_meta_recursive(node: Node, meta_key: String, meta_value: String) -> Node:
	if node.has_meta(meta_key) and node.get_meta(meta_key) == meta_value:
		return node
	
	for child in node.get_children():
		var result = find_node_by_meta_recursive(child, meta_key, meta_value)
		if result:
			return result
	
	return null

# Fonction pour vérifier si un clic a lieu sur l'UI de la boutique
func is_click_on_ui(mouse_position: Vector2) -> bool:
	# Trouver le nœud BuilderShop
	var builder_shop = find_builder_shop_node()
	if not builder_shop:
		return false
	
	# Vérifier si la position de la souris est dans les limites de BuilderShop
	if builder_shop.visible and builder_shop.get_global_rect().has_point(mouse_position):
		print("Clic détecté sur BuilderShop à la position: ", mouse_position)
		return true
	
	return false

# Fonction pour trouver le nœud BuilderShop dans la scène
func find_builder_shop_node() -> Control:
	var scene_root = get_tree().current_scene
	return find_builder_shop_recursive(scene_root)

# Fonction récursive pour trouver BuilderShop
func find_builder_shop_recursive(node: Node) -> Control:
	if node is Control and node.name == "BuilderShop":
		return node as Control
	
	for child in node.get_children():
		var result = find_builder_shop_recursive(child)
		if result:
			return result
	
	return null
