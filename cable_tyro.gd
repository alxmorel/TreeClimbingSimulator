extends Node3D

enum GRAVITY_DIRECTION {X_AXIS, X_AXIS_INVERSE, Y_AXIS, Y_AXIS_INVERSE, Z_AXIS, Z_AXIS_INVERSE}

@export var start_point: Node3D
@export var end_point: Node3D
@export_range(1,50,1) var number_of_segments: int = 10
@export_range(0, 100.0, 0.1) var cable_length: float = 5.0

@export var cable_gravity_amp: float = 0.245
@export var cable_gravity_direction: GRAVITY_DIRECTION = GRAVITY_DIRECTION.Y_AXIS
@export var cable_thickness: float = 0.1
@export var cable_springiness: float = 19.62
@export var cable_mesh:= preload("res://cable_mesh.tscn")
@onready var segment_stretch: float = float(cable_length / number_of_segments)
# instances
var segments: Array[Node3D] = []
var joints: Array[Node3D] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var distance: float = (end_point.global_position - start_point.global_position).length()
	var direction: Vector3 = (end_point.global_position - start_point.global_position).normalized()
	# start at start point
	joints.append(start_point)
	# create joints
	for j: int in (number_of_segments - 1):
		joints.append(Node3D.new())
		self.add_child(joints[j+1])
		# position nodes evenly between the two points
		joints[j+1].global_position = start_point.global_position + direction * (j + 1) * distance / (number_of_segments - 1)
	# end at end point
	joints.append(end_point)
	# create cable segments
	for s: int in number_of_segments:
		segments.append(cable_mesh.instantiate())
		self.add_child(segments[s])
		# position segments between the joints
		segments[s].global_position = joints[s].global_position + (joints[s+1].global_position - joints[s].global_position)/2
		segments[s].get_child(0).mesh.top_radius = cable_thickness/2.0
		segments[s].get_child(0).mesh.bottom_radius = cable_thickness/2.0

func _process(_delta: float) -> void:
	# Make segments point at their target and stretch/squash to their desired length
	for i: int in number_of_segments:
		# set position between joints
		segments[i].global_position = joints[i].global_position + (joints[i+1].global_position - joints[i].global_position)/2
		# look at next joint with proper orientation for cable continuity
		orient_segment_to_joint(segments[i], joints[i+1].global_position)
		# set length to the distance between the joints
		segments[i].get_child(0).mesh.height = (joints[i+1].global_position - joints[i].global_position).length()

func _physics_process(delta: float) -> void:
	# fake physics
	for i: int in number_of_segments:
		if i != 0:
			# collision
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(joints[i].global_position, joints[i].global_position - Vector3(0,cable_thickness, 0))
			var raycast: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			# Gravity
			if raycast.get("collider") == null:
				var inverse: int = 1 if [GRAVITY_DIRECTION.X_AXIS, GRAVITY_DIRECTION.Y_AXIS, GRAVITY_DIRECTION.Z_AXIS].has(cable_gravity_direction) else -1
				match cable_gravity_direction:
					GRAVITY_DIRECTION.X_AXIS, GRAVITY_DIRECTION.X_AXIS_INVERSE:
						joints[i].global_position.x = lerp(joints[i].global_position.x, joints[i].global_position.x - 1, cable_gravity_amp * delta * inverse/2.0)
					GRAVITY_DIRECTION.Y_AXIS, GRAVITY_DIRECTION.Y_AXIS_INVERSE:
						joints[i].global_position.y = lerp(joints[i].global_position.y, joints[i].global_position.y - 1, cable_gravity_amp * delta * inverse/2.0)
					GRAVITY_DIRECTION.Z_AXIS, GRAVITY_DIRECTION.Z_AXIS_INVERSE:
						joints[i].global_position.z = lerp(joints[i].global_position.z, joints[i].global_position.z - 1, cable_gravity_amp * delta * inverse/2.0)
			# stretch
			joints[i].global_position = lerp(joints[i].global_position, joints[i-1].global_position + (joints[i+1].global_position - joints[i-1].global_position)/2.0, cable_springiness * delta)
	# Retract
	if end_point is RigidBody3D:
		if (end_point.global_position - joints[0].global_position).length() >= segment_stretch * number_of_segments:
			var modifier: float = (end_point.global_position - joints[0].global_position).length() - segment_stretch * number_of_segments
			modifier = clamp(modifier, 0.0, cable_springiness)
			end_point.linear_velocity -= (end_point.global_position - joints[-2].global_position)*modifier
	if start_point is RigidBody3D:
		if (end_point.global_position - joints[0].global_position).length() >= segment_stretch * number_of_segments:
			var modifier: float = (end_point.global_position - joints[0].global_position).length() - segment_stretch * number_of_segments
			modifier = clamp(modifier, 0.0, cable_springiness)
			joints[0].linear_velocity -= (joints[0].global_position - joints[1].global_position)*modifier

func orient_segment_to_joint(segment: Node3D, target_joint: Vector3) -> void:
	var segment_pos: Vector3 = segment.global_position
	var direction: Vector3 = (target_joint - segment_pos).normalized()
	
	# Si les points sont trop proches, ne pas modifier l'orientation
	if direction.length() < 0.001:
		return
	
	# Le cylindre dans cable_mesh.tscn a son axe principal orienté vers Z (pas Y)
	# On doit orienter le segment pour que l'axe Z du cylindre suive la direction de la corde
	var up_vector: Vector3 = Vector3.UP
	
	# Si la direction est presque parallèle à l'axe Y, utiliser un autre vecteur de référence
	if abs(direction.dot(Vector3.UP)) > 0.9:
		up_vector = Vector3.RIGHT
	
	# Créer une base orthogonale où l'axe Z pointe vers la direction de la corde
	var right: Vector3 = up_vector.cross(direction).normalized()
	var up: Vector3 = direction.cross(right).normalized()
	
	# Construire la matrice de rotation avec Z comme axe principal
	var rotation_basis: Basis = Basis(right, up, direction)
	segment.global_transform.basis = rotation_basis

func safe_look_at(node: Node3D, target: Vector3) -> void:
	var origin: Vector3 = node.global_transform.origin
	var v_z: Vector3 = (origin - target).normalized()

	# Just return if at same position
	if origin == target:
		return

	# Find an up vector that we can rotate around
	var up: Vector3 = Vector3.ZERO
	for entry: Vector3 in [Vector3.UP, Vector3.RIGHT, Vector3.BACK]:
		var v_x: Vector3 = entry.cross(v_z).normalized()
		if v_x.length() != 0:
			up = entry
			break

	# Look at the target
	if up != Vector3.ZERO:
		node.look_at(target, up)
