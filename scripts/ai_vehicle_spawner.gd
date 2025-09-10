extends Node3D
class_name AIVehicleSpawner

# Spawner professionnel pour véhicules AI avec NavigationAgent3D
@export var path_3d: Path3D
@export var vehicle_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var max_vehicles: int = 10
@export var auto_find_path: bool = true

var _timer: float = 0.0
var _vehicles: Array[AIVehicle] = []

func _ready():
	print("=== AI VEHICLE SPAWNER INITIALISATION ===")
	
	if auto_find_path and not path_3d:
		_find_path_3d()
	
	if not path_3d:
		print("ERREUR: Aucun Path3D trouvé pour le spawner!")
		return
	
	if not vehicle_scene:
		print("ERREUR: Aucune scène de véhicule assignée!")
		return
	
	print("Spawner configuré - Interval: ", spawn_interval, "s | Max véhicules: ", max_vehicles)

func _process(delta):
	_timer += delta
	if _timer >= spawn_interval and _vehicles.size() < max_vehicles:
		_timer = 0.0
		_spawn_vehicle()
	
	_cleanup_finished_vehicles()

func _find_path_3d():
	print("Recherche automatique du Path3D...")
	var scene_root = get_tree().current_scene
	path_3d = scene_root.find_child("Path3D", false, false)
	if path_3d:
		print("Path3D trouvé: ", path_3d.name)
	else:
		print("ERREUR: Aucun Path3D trouvé!")

func _spawn_vehicle():
	if not vehicle_scene or not path_3d:
		return
	
	# Instancier le véhicule
	var vehicle = vehicle_scene.instantiate()
	if not vehicle:
		print("ERREUR: Impossible d'instancier le véhicule!")
		return
	
	# S'assurer que c'est un AIVehicle
	if not vehicle is AIVehicle:
		print("ERREUR: Le véhicule doit être de type AIVehicle!")
		vehicle.queue_free()
		return
	
	# Configurer le véhicule
	vehicle.name = "AIVehicle_" + str(_vehicles.size())
	vehicle.target_path = path_3d
	vehicle.auto_find_path = false  # On assigne manuellement
	
	# Ajouter à la scène
	get_tree().current_scene.add_child(vehicle)
	
	# Connecter les signaux pour le debug
	vehicle.journey_started.connect(_on_vehicle_started.bind(vehicle))
	vehicle.journey_completed.connect(_on_vehicle_completed.bind(vehicle))
	
	_vehicles.append(vehicle)
	print("✅ Véhicule AI spawné: ", vehicle.name, " (Total: ", _vehicles.size(), ")")

func _cleanup_finished_vehicles():
	for vehicle in _vehicles.duplicate():
		if not is_instance_valid(vehicle) or vehicle.is_at_end():
			if is_instance_valid(vehicle):
				print("🗑️ Suppression du véhicule: ", vehicle.name)
				vehicle.queue_free()
			_vehicles.erase(vehicle)

func _on_vehicle_started(vehicle: AIVehicle):
	print("🚗 Départ: ", vehicle.name)

func _on_vehicle_completed(vehicle: AIVehicle):
	print("🏁 Arrivée: ", vehicle.name)

# Fonctions publiques
func get_active_vehicles() -> Array[AIVehicle]:
	return _vehicles.duplicate()

func get_vehicle_count() -> int:
	return _vehicles.size()

func clear_all_vehicles():
	for vehicle in _vehicles:
		if is_instance_valid(vehicle):
			vehicle.queue_free()
	_vehicles.clear()
	print("🧹 Tous les véhicules supprimés")
