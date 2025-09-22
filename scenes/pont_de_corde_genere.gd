extends Node3D

enum GRAVITY_DIRECTION {X_AXIS, X_AXIS_INVERSE, Y_AXIS, Y_AXIS_INVERSE, Z_AXIS, Z_AXIS_INVERSE}

@export var start_left: Node3D
@export var end_left: Node3D
@export var start_right: Node3D
@export var end_right: Node3D

@export_range(2, 50, 1) var number_of_segments: int = 10
@export_range(0.1, 100.0, 0.1) var cable_length: float = 10.0

@export var cable_thickness: float = 0.1

@export var cable_mesh: PackedScene = preload("res://scenes/cable_mesh.tscn")
@export var plank_scene: PackedScene = preload("res://scenes/plank.tscn")

@export_range(1, 50) var number_of_planks: int = 5

# --- Internals ---
var joints_left: Array[Node3D] = []
var joints_right: Array[Node3D] = []
var segments_left: Array[Node3D] = []
var segments_right: Array[Node3D] = []

func _ready() -> void:
	print("=== Génération du pont de corde ===")
	_create_cable(joints_left, segments_left, start_left, end_left, "left")
	_create_cable(joints_right, segments_right, start_right, end_right, "right")
	_attach_planks_to_cables()
	print("=== Génération terminée ===")
	
	# Vérification après un délai
	await get_tree().create_timer(1.0).timeout
	_debug_plank_status()

func _create_cable(joints: Array, segments: Array, start_point: Node3D, end_point: Node3D, side: String) -> void:
	print("Création de la corde ", side)
	var direction = (end_point.global_position - start_point.global_position).normalized()
	var distance = (end_point.global_position - start_point.global_position).length()
	
	joints.append(start_point)
	for i in range(number_of_segments - 1):
		var joint = Node3D.new()
		add_child(joint)
		joint.global_position = start_point.global_position + direction * (i + 1) * distance / (number_of_segments - 1)
		joints.append(joint)
		print("Joint ", i+1, " créé à ", joint.global_position)
	joints.append(end_point)
	print("Corde ", side, " : joints totaux = ", joints.size())
	
	for i in range(number_of_segments):
		var seg = cable_mesh.instantiate()
		add_child(seg)
		segments.append(seg)
		_update_segment(seg, joints[i], joints[i+1])
		print("Segment ", i, " créé entre joints ", i, " et ", i+1)

func _update_segment(seg: Node3D, joint_a: Node3D, joint_b: Node3D) -> void:
	seg.global_position = joint_a.global_position + (joint_b.global_position - joint_a.global_position)/2
	
	var direction = (joint_b.global_position - joint_a.global_position).normalized()
	var up_vector: Vector3 = Vector3.UP
	if abs(direction.dot(Vector3.UP)) > 0.9:
		up_vector = Vector3.RIGHT
	var right = up_vector.cross(direction).normalized()
	var up = direction.cross(right).normalized()
	seg.global_transform.basis = Basis(right, up, direction)
	
	var mesh_instance = seg.get_child(0)
	mesh_instance.mesh.top_radius = cable_thickness / 2
	mesh_instance.mesh.bottom_radius = cable_thickness / 2
	mesh_instance.mesh.height = (joint_b.global_position - joint_a.global_position).length()

func _calculate_reference_height() -> float:
	# Calculer la hauteur de référence basée sur les joints du milieu
	# Éviter les extrémités qui peuvent être plus basses
	var middle_joints = []
	var start_index = max(1, int(number_of_segments * 0.2))  # 20% du début
	var end_index = min(number_of_segments - 1, int(number_of_segments * 0.8))  # 80% du début
	
	for i in range(start_index, end_index + 1):
		if i < joints_left.size() and i < joints_right.size():
			middle_joints.append(joints_left[i].global_position.y)
			middle_joints.append(joints_right[i].global_position.y)
	
	if middle_joints.size() > 0:
		var total_height = 0.0
		for height in middle_joints:
			total_height += height
		return total_height / middle_joints.size()
	else:
		# Fallback : utiliser la hauteur moyenne de tous les joints
		var total_height = 0.0
		var count = 0
		for joint in joints_left:
			total_height += joint.global_position.y
			count += 1
		for joint in joints_right:
			total_height += joint.global_position.y
			count += 1
		return total_height / count if count > 0 else 0.0

func _calculate_plank_distribution() -> Array[int]:
	# Calculer la distribution optimale des planches sur les joints
	var plank_positions: Array[int] = []
	
	if number_of_planks == 0:
		return plank_positions
	
	# Éviter les extrémités (joints 0 et dernier)
	var available_joints = number_of_segments - 2
	var start_joint = 1
	var end_joint = number_of_segments - 1
	
	# Distribution équilibrée
	for i in range(number_of_planks):
		var ratio = (i + 1) / float(number_of_planks + 1)
		var joint_index = start_joint + int(ratio * available_joints)
		joint_index = clamp(joint_index, start_joint, end_joint)
		plank_positions.append(joint_index)
	
	return plank_positions

func _attach_planks_to_cables() -> void:
	if not plank_scene:
		return
	
	# Calculer la distribution optimale des planches
	var plank_positions = _calculate_plank_distribution()

	for i in range(number_of_planks):
		# Instanciation
		var plank = plank_scene.instantiate() as RigidBody3D
		add_child(plank)
		
		# Configuration de la planche pour plus de stabilité
		plank.mass = 0.5  # Masse légère
		plank.gravity_scale = 1.0  # Gravité normale
		plank.linear_damp = 0.1  # Amortissement linéaire
		plank.angular_damp = 0.1  # Amortissement angulaire
				
		# Utiliser la position calculée par la fonction de distribution
		var joint_index = plank_positions[i]
		
		# Vérifier que les indices sont valides
		if joint_index >= joints_left.size() or joint_index >= joints_right.size():
			continue
		
		var joint_left = joints_left[joint_index]
		var joint_right = joints_right[joint_index]

		# Position et orientation initiale
		# Calculer la position centrale entre les deux joints
		var center_position = (joint_left.global_position + joint_right.global_position) / 2
		
		# Ajuster la hauteur pour que toutes les planches soient à la même hauteur
		# Utiliser la hauteur moyenne des joints du milieu comme référence
		var reference_height = _calculate_reference_height()
		center_position.y = reference_height
		
		plank.global_position = center_position

		# Calculer la direction entre les deux joints (direction des cordes)
		var cable_direction = (joint_right.global_position - joint_left.global_position).normalized()
		
		# Orienter la planche pour qu'elle soit PERPENDICULAIRE aux cordes et HORIZONTALE
		# La planche doit être horizontale (comme un sol) et perpendiculaire aux cordes
		var plank_right = cable_direction  # Direction des cordes
		var plank_up = Vector3.UP  # Toujours vers le haut
		var plank_forward = plank_right.cross(plank_up).normalized()  # Perpendiculaire aux cordes
		
		# Vérifier si les vecteurs sont valides
		if plank_forward.length() > 0.001:
			plank.global_transform.basis = Basis(plank_right, plank_up, plank_forward)
		else:
			# Si les cordes sont verticales, orientation par défaut
			plank.global_transform.basis = Basis.IDENTITY
		
		# Création de corps statiques pour les points d'ancrage
		var anchor_left = StaticBody3D.new()
		anchor_left.name = "Anchor_Left_" + str(i)
		# Ajuster la hauteur de l'ancre pour qu'elle soit à la même hauteur que la planche
		var anchor_left_pos = joint_left.global_position
		anchor_left_pos.y = reference_height
		anchor_left.global_position = anchor_left_pos
		add_child(anchor_left)
		
		var anchor_right = StaticBody3D.new()
		anchor_right.name = "Anchor_Right_" + str(i)
		# Ajuster la hauteur de l'ancre pour qu'elle soit à la même hauteur que la planche
		var anchor_right_pos = joint_right.global_position
		anchor_right_pos.y = reference_height
		anchor_right.global_position = anchor_right_pos
		add_child(anchor_right)
		
		# Création des joints physiques avec Generic6DOFJoint3D - configuration simplifiée
		var joint_left_conn = Generic6DOFJoint3D.new()
		joint_left_conn.name = "Joint_Left_" + str(i)
		joint_left_conn.node_a = anchor_left.get_path()
		joint_left_conn.node_b = plank.get_path()
		
		# Configuration simplifiée - seulement les limites linéaires pour maintenir la distance
		joint_left_conn.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
		joint_left_conn.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
		joint_left_conn.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
		
		# Limites linéaires plus strictes pour maintenir les planches attachées
		joint_left_conn.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -0.05)
		joint_left_conn.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -0.05)
		joint_left_conn.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -0.05)
		joint_left_conn.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.05)
		joint_left_conn.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.05)
		joint_left_conn.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.05)
		
		# Amortissement plus fort pour la stabilité
		joint_left_conn.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_DAMPING, 0.8)
		joint_left_conn.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_DAMPING, 0.8)
		joint_left_conn.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_DAMPING, 0.8)
		
		add_child(joint_left_conn)
		
		var joint_right_conn = Generic6DOFJoint3D.new()
		joint_right_conn.name = "Joint_Right_" + str(i)
		joint_right_conn.node_a = anchor_right.get_path()
		joint_right_conn.node_b = plank.get_path()
		
		# Même configuration pour le joint droit
		joint_right_conn.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
		joint_right_conn.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
		joint_right_conn.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
		
		joint_right_conn.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -0.05)
		joint_right_conn.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -0.05)
		joint_right_conn.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -0.05)
		joint_right_conn.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.05)
		joint_right_conn.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.05)
		joint_right_conn.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.05)
		
		joint_right_conn.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_DAMPING, 0.8)
		joint_right_conn.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_DAMPING, 0.8)
		joint_right_conn.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_DAMPING, 0.8)
		
		add_child(joint_right_conn)

func _debug_plank_status() -> void:
	var planks = get_children().filter(func(node): return node is RigidBody3D)
	
	for i in range(planks.size()):
		var plank = planks[i] as RigidBody3D
		
		# Vérifier les joints attachés
		var joints = get_children().filter(func(node): 
			return node is Generic6DOFJoint3D and node.node_b == plank.get_path()
		)

func _adjust_plank_orientations() -> void:
	# Ajuster l'orientation des planches pour qu'elles restent alignées avec les cordes
	for i in range(number_of_planks):
		var step = int(number_of_segments / (number_of_planks + 1))
		var joint_index = clamp((i + 1) * step, 1, number_of_segments - 1)
		
		if joint_index < joints_left.size() and joint_index < joints_right.size():
			var joint_left = joints_left[joint_index]
			var joint_right = joints_right[joint_index]
			
			# Trouver la planche correspondante
			var planks = get_children().filter(func(node): return node is RigidBody3D)
			if i < planks.size():
				var plank = planks[i] as RigidBody3D
				
				# Calculer la nouvelle direction des cordes
				var cable_direction = (joint_right.global_position - joint_left.global_position).normalized()
				
				# Ajuster l'orientation progressivement pour rester perpendiculaire
				var target_basis = _calculate_plank_basis_perpendicular(cable_direction)
				plank.global_transform.basis = plank.global_transform.basis.slerp(target_basis, 0.1)

func _calculate_plank_basis_perpendicular(cable_direction: Vector3) -> Basis:
	# Calculer la base d'orientation pour une planche PERPENDICULAIRE aux cordes
	# Approche plus robuste pour éviter les erreurs de déterminant
	var plank_direction = Vector3.UP.cross(cable_direction)
	
	# Vérifier si le vecteur est valide
	if plank_direction.length() < 0.001:
		plank_direction = Vector3.RIGHT
	else:
		plank_direction = plank_direction.normalized()
	
	# Créer la base d'orientation
	var right = cable_direction
	var up = plank_direction
	var forward = right.cross(up).normalized()
	
	# Vérifier que la base est valide
	if abs(right.dot(up)) < 0.9:
		return Basis(right, up, forward)
	else:
		return Basis.IDENTITY

func _calculate_plank_basis(direction: Vector3) -> Basis:
	# Ancienne fonction - gardée pour compatibilité
	var up_vector = Vector3.UP
	if abs(direction.dot(Vector3.UP)) > 0.9:
		up_vector = Vector3.RIGHT
	
	var right = up_vector.cross(direction).normalized()
	var up = direction.cross(right).normalized()
	return Basis(right, up, direction)

func _update_anchor_positions() -> void:
	# Mettre à jour les positions des ancres pour qu'elles suivent les joints des cordes
	# Désactivé temporairement pour éviter les mouvements brusques
	# Les ancres restent fixes une fois créées
	pass

func _process(delta: float) -> void:
	for i in range(number_of_segments):
		_update_segment(segments_left[i], joints_left[i], joints_left[i+1])
		_update_segment(segments_right[i], joints_right[i], joints_right[i+1])
	
	# Mettre à jour les positions des ancres avec les joints des cordes
	_update_anchor_positions()
	
	# Désactivé l'ajustement automatique pour éviter les interférences avec la physique
	# _adjust_plank_orientations()
