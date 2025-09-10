extends Node

# Script de test pour la détection d'arbres
# À attacher à un nœud dans la scène pour tester

func _ready():
	print("=== Test de détection d'arbres ===")
	
	# Attendre que la scène soit prête
	await get_tree().process_frame
	
	# Tester la détection d'arbres
	test_tree_detection()

func test_tree_detection():
	var scene_root = get_tree().current_scene
	print("Scène racine: ", scene_root.name)
	
	# Rechercher le PlacementManager
	var placement_manager = scene_root.get_node_or_null("PlacementManager")
	if placement_manager:
		print("PlacementManager trouvé")
		
		# Tester la fonction de recherche d'arbres
		if placement_manager.has_method("find_trees_in_scene"):
			var trees = placement_manager.find_trees_in_scene(scene_root)
			print("Arbres trouvés: ", trees.size())
			
			for i in range(trees.size()):
				var tree = trees[i]
				print("  Arbre ", i, ": ", tree.name, " à la position: ", tree.global_position)
		else:
			print("PlacementManager n'a pas la méthode find_trees_in_scene")
	else:
		print("PlacementManager non trouvé")
	
	# Rechercher le système Terrain3D
	var terrain3d = scene_root.get_node_or_null("Terrain3D")
	if terrain3d:
		print("Terrain3D trouvé")
		
		# Lister les enfants du Terrain3D
		print("Enfants du Terrain3D:")
		for child in terrain3d.get_children():
			print("  - ", child.name, " (", child.get_class(), ")")
			
			# Lister les petits-enfants
			for grandchild in child.get_children():
				print("    - ", grandchild.name, " (", grandchild.get_class(), ")")
	
	# Rechercher tous les nœuds contenant "tree" dans le nom
	print("\nRecherche de tous les nœuds contenant 'tree':")
	find_all_tree_nodes(scene_root)

func find_all_tree_nodes(node: Node, depth: int = 0):
	var indent = ""
	for i in range(depth):
		indent += "  "
	
	# Vérifier si ce nœud contient "tree" dans le nom
	if "tree" in node.name.to_lower():
		var position_info = "N/A"
		if node is Node3D:
			position_info = str(node.global_position)
		print(indent + "🌳 ", node.name, " (", node.get_class(), ") à la position: ", position_info)
	
	# Parcourir récursivement les enfants
	for child in node.get_children():
		find_all_tree_nodes(child, depth + 1)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			print("=== Test manuel de détection d'arbres ===")
			test_tree_detection()
