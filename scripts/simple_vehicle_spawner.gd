extends Node3D
class_name SimpleVehicleSpawner

# Spawner professionnel et simple
@export var path_3d: Path3D
@export var vehicle_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var max_vehicles: int = 10

var _timer: float = 0.0
var _vehicles: Array[PathFollow3D] = []

func _ready():
	if not path_3d:
		_find_path_3d()

func _process(delta):
	_timer += delta
	if _timer >= spawn_interval and _vehicles.size() < max_vehicles:
		_timer = 0.0
		_spawn_vehicle()
	
	_cleanup_finished_vehicles()

func _find_path_3d():
	path_3d = get_tree().current_scene.find_child("Path3D", false, false)

func _spawn_vehicle():
	if not vehicle_scene or not path_3d:
		return
	
	# Créer le PathFollow3D
	var path_follow = PathFollow3D.new()
	path_follow.name = "Vehicle_" + str(_vehicles.size())
	path_3d.add_child(path_follow)
	
	# Instancier le véhicule
	var vehicle = vehicle_scene.instantiate()
	path_follow.add_child(vehicle)
	
	# Ajouter le script de suivi
	path_follow.set_script(load("res://scripts/simple_path_follower.gd"))
	
	_vehicles.append(path_follow)
	print("Véhicule spawné: ", path_follow.name)

func _cleanup_finished_vehicles():
	for vehicle in _vehicles.duplicate():
		if not is_instance_valid(vehicle) or vehicle.progress_ratio >= 1.0:
			if is_instance_valid(vehicle):
				vehicle.queue_free()
			_vehicles.erase(vehicle)
