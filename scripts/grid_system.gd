extends Node3D
class_name GridSystem

signal cell_state_changed(grid_x: int, grid_z: int, new_state: CellState)

enum CellState {
	FREE,      # Cellule libre (placement autorisé)
	OCCUPIED,  # Cellule occupée par un objet
	BLOCKED    # Cellule bloquée (obstacle, hors limites)
}

# Paramètres de la grille
const CELL_SIZE = 4.0  # Taille d'une cellule en unités Godot
const GRID_SIZE_X = 50  # Nombre de cellules en X
const GRID_SIZE_Z = 50  # Nombre de cellules en Z
const GRID_RADIUS = 5   # Rayon de la grille autour du ghost (en cellules)
const MAX_OPACITY = 0.6  # Opacité maximale de la grille

# Données de la grille
var grid_data: Array[Array] = []
var placed_objects: Dictionary = {}  # grid_pos -> objet placé

# Grille dynamique autour du ghost
var dynamic_grid_cells: Array[Node3D] = []  # Cellules visuelles dynamiques
var current_ghost_position: Vector2i = Vector2i(-999, -999)  # Position invalide par défaut

# Matériau pour la grille (bleu clair constant)
var grid_material: StandardMaterial3D

func _ready():
	# Attendre que le moteur soit prêt
	await get_tree().process_frame
	initialize_grid()
	create_grid_material()
	print("GridSystem prêt")

func initialize_grid():
	# Initialiser la grille de données
	grid_data.clear()
	for x in range(GRID_SIZE_X):
		var row: Array[CellState] = []
		for z in range(GRID_SIZE_Z):
			row.append(CellState.FREE)
		grid_data.append(row)
	
	print("Grille initialisée: ", GRID_SIZE_X, "x", GRID_SIZE_Z, " cellules")

func create_grid_material():
	# Matériau unique pour la grille (bleu clair constant)
	grid_material = StandardMaterial3D.new()
	grid_material.albedo_color = Color(0.5, 0.7, 1.0, MAX_OPACITY)  # Bleu clair
	grid_material.flags_transparent = true
	grid_material.flags_do_not_receive_shadows = true
	grid_material.flags_disable_ambient_light = true
	grid_material.no_depth_test = true
	grid_material.flags_unshaded = true
	grid_material.emission_enabled = true
	grid_material.emission = Color(0.3, 0.5, 0.8)  # Émission bleu clair
	grid_material.emission_energy = 0.5

# Convertir une position mondiale en coordonnées de grille
func world_to_grid(world_pos: Vector3) -> Vector2i:
	var grid_x = int(round(world_pos.x / CELL_SIZE))
	var grid_z = int(round(world_pos.z / CELL_SIZE))
	return Vector2i(grid_x + GRID_SIZE_X/2, grid_z + GRID_SIZE_Z/2)

# Convertir des coordonnées de grille en position mondiale (centre de cellule)
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var world_x = (grid_pos.x - GRID_SIZE_X/2) * CELL_SIZE
	var world_z = (grid_pos.y - GRID_SIZE_Z/2) * CELL_SIZE
	return Vector3(world_x, 0, world_z)

# Vérifier si une position de grille est valide
func is_valid_grid_position(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < GRID_SIZE_X and grid_pos.y >= 0 and grid_pos.y < GRID_SIZE_Z

# Obtenir l'état d'une cellule
func get_cell_state(grid_pos: Vector2i) -> CellState:
	if not is_valid_grid_position(grid_pos):
		return CellState.BLOCKED
	return grid_data[grid_pos.x][grid_pos.y]

# Définir l'état d'une cellule
func set_cell_state(grid_pos: Vector2i, state: CellState):
	if not is_valid_grid_position(grid_pos):
		return
	
	var old_state = grid_data[grid_pos.x][grid_pos.y]
	if old_state != state:
		grid_data[grid_pos.x][grid_pos.y] = state
		cell_state_changed.emit(grid_pos.x, grid_pos.y, state)

# Vérifier si une cellule peut accueillir un placement
func can_place_at(grid_pos: Vector2i) -> bool:
	return get_cell_state(grid_pos) == CellState.FREE

# Placer un objet sur la grille
func place_object(grid_pos: Vector2i, object: Node3D) -> bool:
	if not can_place_at(grid_pos):
		return false
	
	set_cell_state(grid_pos, CellState.OCCUPIED)
	placed_objects[str(grid_pos)] = object
	
	# Mettre à jour la position de l'objet pour qu'il soit centré sur la cellule
	var world_pos = grid_to_world(grid_pos)
	object.global_position = Vector3(world_pos.x, object.global_position.y, world_pos.z)
	
	return true

# Supprimer un objet de la grille
func remove_object(grid_pos: Vector2i):
	if is_valid_grid_position(grid_pos):
		set_cell_state(grid_pos, CellState.FREE)
		placed_objects.erase(str(grid_pos))

# Obtenir l'objet placé à une position
func get_object_at(grid_pos: Vector2i) -> Node3D:
	return placed_objects.get(str(grid_pos))

# Montrer la grille dynamique autour d'une position
func show_grid():
	# Ne rien faire - la grille sera mise à jour dynamiquement via update_dynamic_grid()
	print("Grille dynamique activée")

# Masquer la grille dynamique
func hide_grid():
	clear_dynamic_grid()
	print("Grille dynamique masquée")

# Nettoyer toutes les cellules dynamiques
func clear_dynamic_grid():
	for cell in dynamic_grid_cells:
		if cell:
			cell.queue_free()
	dynamic_grid_cells.clear()
	current_ghost_position = Vector2i(-999, -999)

# Mettre à jour la grille dynamique autour du ghost
func update_dynamic_grid(ghost_world_pos: Vector3):
	# Vérification de sécurité : s'assurer que cette fonction n'est pas appelée en boucle
	if not is_inside_tree():
		print("Warning: update_dynamic_grid appelé avant que GridSystem soit dans l'arbre")
		return
	
	var ghost_grid_pos = world_to_grid(ghost_world_pos)
	
	# Si le ghost n'a pas bougé de cellule, pas besoin de recréer la grille
	if ghost_grid_pos == current_ghost_position:
		return
	
	# Nettoyer l'ancienne grille
	clear_dynamic_grid()
	current_ghost_position = ghost_grid_pos
	
	# Créer les cellules dans un rayon autour du ghost
	for x in range(ghost_grid_pos.x - GRID_RADIUS, ghost_grid_pos.x + GRID_RADIUS + 1):
		for z in range(ghost_grid_pos.y - GRID_RADIUS, ghost_grid_pos.y + GRID_RADIUS + 1):
			var cell_pos = Vector2i(x, z)
			if is_valid_grid_position(cell_pos):
				# Calculer la distance au ghost pour l'opacité
				var distance = sqrt((x - ghost_grid_pos.x)**2 + (z - ghost_grid_pos.y)**2)
				var opacity_factor = max(0.0, 1.0 - (distance / GRID_RADIUS))
				
				var cell_visual = create_dynamic_cell_visual(cell_pos, opacity_factor)
				if cell_visual:
					dynamic_grid_cells.append(cell_visual)

# Créer une cellule visuelle dynamique avec opacité variable
func create_dynamic_cell_visual(grid_pos: Vector2i, opacity_factor: float) -> Node3D:
	var cell_node = Node3D.new()
	var world_pos = grid_to_world(grid_pos)
	var terrain_height = get_terrain_height_at_position(world_pos)
	
	# Créer les 4 lignes de la cellule
	var half_size = CELL_SIZE * 0.5
	var corners = [
		Vector3(-half_size, 0, -half_size),
		Vector3(half_size, 0, -half_size),
		Vector3(half_size, 0, half_size),
		Vector3(-half_size, 0, half_size)
	]
	
	# Créer 4 MeshInstance3D pour les 4 côtés de la cellule
	for i in range(4):
		var line_mesh = MeshInstance3D.new()
		var array_mesh = ArrayMesh.new()
		var vertices = PackedVector3Array()
		var indices = PackedInt32Array()
		
		# Ligne de corner[i] vers corner[(i+1)%4]
		vertices.append(corners[i])
		vertices.append(corners[(i + 1) % 4])
		indices.append(0)
		indices.append(1)
		
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = indices
		
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
		line_mesh.mesh = array_mesh
		
		# Matériau avec opacité variable
		var line_material = StandardMaterial3D.new()
		var final_opacity = MAX_OPACITY * opacity_factor
		line_material.albedo_color = Color(0.5, 0.7, 1.0, final_opacity)
		line_material.flags_transparent = true
		line_material.flags_unshaded = true
		line_material.flags_do_not_receive_shadows = true
		line_material.flags_disable_ambient_light = true
		line_material.no_depth_test = true
		line_material.emission_enabled = true
		line_material.emission = Color(0.3, 0.5, 0.8) * opacity_factor
		line_material.emission_energy = 0.5 * opacity_factor
		
		line_mesh.material_override = line_material
		line_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		cell_node.add_child(line_mesh)
	
	# Ajouter d'abord l'enfant à l'arbre
	add_child(cell_node)
	
	# Maintenant positionner le node (après l'ajout à l'arbre)
	cell_node.global_position = Vector3(world_pos.x, terrain_height + 1.5, world_pos.z)
	
	return cell_node


# Obtenir la hauteur du terrain à une position donnée
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


# Obtenir la cellule la plus proche d'une position mondiale
func get_nearest_cell(world_pos: Vector3) -> Vector2i:
	return world_to_grid(world_pos)

# Marquer des zones comme bloquées (pour les obstacles, limites, etc.)
func block_area(center: Vector2i, radius: int):
	for x in range(center.x - radius, center.x + radius + 1):
		for z in range(center.y - radius, center.y + radius + 1):
			var pos = Vector2i(x, z)
			if is_valid_grid_position(pos):
				set_cell_state(pos, CellState.BLOCKED)
