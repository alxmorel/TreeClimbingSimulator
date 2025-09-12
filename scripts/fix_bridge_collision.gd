extends EditorScript

func _run():
	print("Correction des collisions du pont de corde...")
	
	# Charger la scène
	var scene_path = "res://scenes/pont_de_corde_en_bois.tscn"
	var scene = load(scene_path)
	var instance = scene.instantiate()
	
	# Trouver le StaticBody3D
	var static_body = instance.get_node("StaticBody3D")
	if static_body:
		print("StaticBody3D trouvé")
		
		# Supprimer toutes les collision shapes existantes
		for child in static_body.get_children():
			if child is CollisionShape3D:
				print("Suppression de: ", child.name)
				child.queue_free()
		
		# Créer une nouvelle collision shape unifiée
		var new_collision = CollisionShape3D.new()
		new_collision.name = "CollisionShape3D"
		
		# Créer une BoxShape3D simple
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(3.0, 0.3, 20.0)  # Largeur, hauteur, longueur
		new_collision.shape = box_shape
		
		# Positionner la collision au centre du pont
		new_collision.transform = Transform3D.IDENTITY
		new_collision.position = Vector3(0, -1.5, 0)
		
		# Ajouter la nouvelle collision
		static_body.add_child(new_collision)
		new_collision.owner = instance
		
		print("Nouvelle collision créée")
		
		# Sauvegarder la scène modifiée
		var packed_scene = PackedScene.new()
		packed_scene.pack(instance)
		ResourceSaver.save(packed_scene, scene_path)
		
		print("Scène sauvegardée avec succès!")
	else:
		print("StaticBody3D non trouvé")
	
	instance.queue_free()
