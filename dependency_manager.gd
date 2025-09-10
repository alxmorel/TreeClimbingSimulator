extends Node

# Gestionnaire de dépendances pour le système de builder
# Gère les relations entre objets (ex: modules d'accrobranche -> arbres)

# Structure des dépendances : { "objet_id": [dépendances] }
var dependencies: Dictionary = {}
# Structure inverse : { "objet_id": [objets_dépendants] }
var reverse_dependencies: Dictionary = {}

# ID unique pour chaque objet
var next_object_id: int = 0

func _ready():
	print("DependencyManager initialisé")

# Générer un ID unique pour un objet
func generate_object_id() -> String:
	next_object_id += 1
	return "obj_" + str(next_object_id)

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
		"id": dependent_id
	})
	
	print("Dépendance enregistrée: ", dependent_object.name, " -> ", dependency_object.name, " (", dependency_type, ")")

# Obtenir l'ID d'un objet
func get_object_id(obj: Node) -> String:
	if obj.has_meta("dependency_id"):
		return obj.get_meta("dependency_id")
	return ""

# Définir l'ID d'un objet
func set_object_id(obj: Node, id: String):
	obj.set_meta("dependency_id", id)

# Obtenir tous les objets dépendants d'un objet donné
func get_dependent_objects(object: Node) -> Array:
	var object_id = get_object_id(object)
	if not object_id or not reverse_dependencies.has(object_id):
		return []
	
	var dependents = []
	for dep_info in reverse_dependencies[object_id]:
		dependents.append(dep_info.object)
	
	return dependents

# Obtenir toutes les dépendances d'un objet donné
func get_object_dependencies(object: Node) -> Array:
	var object_id = get_object_id(object)
	if not object_id or not dependencies.has(object_id):
		return []
	
	return dependencies[object_id]

# Supprimer une dépendance
func remove_dependency(dependent_object: Node, dependency_object: Node):
	var dependent_id = get_object_id(dependent_object)
	var dependency_id = get_object_id(dependency_object)
	
	if not dependent_id or not dependency_id:
		return
	
	# Supprimer de la liste des dépendances
	if dependencies.has(dependent_id):
		dependencies[dependent_id] = dependencies[dependent_id].filter(
			func(dep): return dep.id != dependency_id
		)
	
	# Supprimer de la liste inverse
	if reverse_dependencies.has(dependency_id):
		reverse_dependencies[dependency_id] = reverse_dependencies[dependency_id].filter(
			func(dep): return dep.id != dependent_id
		)
	
	print("Dépendance supprimée: ", dependent_object.name, " -> ", dependency_object.name)

# Supprimer toutes les dépendances d'un objet
func remove_object_dependencies(object: Node):
	var object_id = get_object_id(object)
	if not object_id:
		return
	
	# Supprimer les dépendances de cet objet
	if dependencies.has(object_id):
		for dep_info in dependencies[object_id]:
			remove_dependency(object, dep_info.object)
		dependencies.erase(object_id)
	
	# Supprimer les dépendances vers cet objet
	if reverse_dependencies.has(object_id):
		for dep_info in reverse_dependencies[object_id]:
			remove_dependency(dep_info.object, object)
		reverse_dependencies.erase(object_id)

# Obtenir le chemin de dépendance complet (pour le déplacement en cascade)
func get_dependency_chain(object: Node) -> Array:
	var chain = []
	var visited = {}
	
	func traverse_deps(obj: Node, depth: int = 0):
		if depth > 10:  # Éviter les boucles infinies
			return
		
		var obj_id = get_object_id(obj)
		if not obj_id or visited.has(obj_id):
			return
		
		visited[obj_id] = true
		chain.append({
			"object": obj,
			"depth": depth,
			"dependencies": get_object_dependencies(obj)
		})
		
		# Traverser les dépendances
		for dep_info in get_object_dependencies(obj):
			traverse_deps(dep_info.object, depth + 1)
	
	traverse_deps(object)
	return chain

# Déplacer un objet et tous ses dépendants
func move_object_with_dependencies(object: Node, new_position: Vector3, new_rotation: Vector3 = Vector3.ZERO):
	var dependency_chain = get_dependency_chain(object)
	
	# Trier par profondeur (dépendances d'abord)
	dependency_chain.sort_custom(func(a, b): return a.depth > b.depth)
	
	# Déplacer chaque objet dans l'ordre
	for item in dependency_chain:
		var obj = item.object
		var old_pos = obj.global_position
		var old_rot = obj.global_rotation
		
		# Calculer le déplacement relatif
		var offset = new_position - old_pos
		var rotation_offset = new_rotation - old_rot
		
		# Appliquer le déplacement
		obj.global_position += offset
		obj.global_rotation += rotation_offset
		
		print("Objet déplacé: ", obj.name, " vers ", obj.global_position)

# Vérifier si un objet peut être déplacé sans casser ses dépendances
func can_move_object(object: Node) -> bool:
	var dependents = get_dependent_objects(object)
	
	# Si l'objet n'a pas de dépendants, il peut être déplacé librement
	if dependents.size() == 0:
		return true
	
	# Vérifier que tous les dépendants peuvent être déplacés aussi
	for dependent in dependents:
		if not can_move_object(dependent):
			return false
	
	return true

# Obtenir un résumé des dépendances pour le debug
func get_dependency_summary() -> String:
	var summary = "=== Résumé des Dépendances ===\n"
	
	for obj_id in dependencies:
		var obj = get_object_by_id(obj_id)
		if obj:
			summary += obj.name + " dépend de:\n"
			for dep_info in dependencies[obj_id]:
				var dep_obj = dep_info.object
				summary += "  - " + dep_obj.name + " (" + dep_info.type + ")\n"
	
	summary += "\n=== Dépendances Inverses ===\n"
	for obj_id in reverse_dependencies:
		var obj = get_object_by_id(obj_id)
		if obj:
			summary += obj.name + " est utilisé par:\n"
			for dep_info in reverse_dependencies[obj_id]:
				var dep_obj = dep_info.object
				summary += "  - " + dep_obj.name + " (" + dep_info.type + ")\n"
	
	return summary

# Fonction utilitaire pour trouver un objet par ID
func get_object_by_id(id: String) -> Node:
	# Chercher dans la scène (peut être optimisé)
	var scene_root = get_tree().current_scene
	return find_node_by_meta(scene_root, "dependency_id", id)

# Fonction récursive pour trouver un nœud par métadonnée
func find_node_by_meta(node: Node, meta_key: String, meta_value: String) -> Node:
	if node.has_meta(meta_key) and node.get_meta(meta_key) == meta_value:
		return node
	
	for child in node.get_children():
		var result = find_node_by_meta(child, meta_key, meta_value)
		if result:
			return result
	
	return null
