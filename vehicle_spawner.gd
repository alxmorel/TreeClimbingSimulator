extends Node3D

@export var path_3d: Path3D
@export var vehicle_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var max_vehicles: int = 5

var _timer := 0.0
var _spawned := []

func _ready():
	if not path_3d:
		# Essayer d'auto-détecter
		var parent = get_parent()
		while parent and not path_3d:
			path_3d = parent.find_child("Path3D", false, false)
			parent = parent.get_parent()

func _process(delta):
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		if vehicle_scene and path_3d and _spawned.size() < max_vehicles:
			_spawn_vehicle()
	_cleanup_finished()

func _spawn_vehicle():
	var instance = vehicle_scene.instantiate()
	if not instance:
		return
	# Position au début (toute à droite sur votre capture)
	var curve := path_3d.curve
	if not curve:
		return
	var p0 = path_3d.global_position + curve.sample_baked(0.0)
	instance.global_position = Vector3(p0.x, instance.global_position.y, p0.z)
	# Attacher à la scène
	get_tree().current_scene.add_child(instance)
	# Si c'est un PathFollower, lui assigner le path
	if "set_path" in instance:
		instance.set_path(path_3d)
	_spawned.append(instance)

func _cleanup_finished():
	for v in _spawned.duplicate():
		if not is_instance_valid(v):
			_spawned.erase(v)

