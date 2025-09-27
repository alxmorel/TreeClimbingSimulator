# scripts/park_management/park_points_manager.gd
extends Node
class_name ParkPointsManager

# Points d'intérêt du parc
var equipment_zones: Array[Node3D] = []
var adventure_courses: Array[Node3D] = []
var playgrounds: Array[Node3D] = []
var picnic_tables: Array[Node3D] = []
var toilets: Array[Node3D] = []
var rest_areas: Array[Node3D] = []

# Singleton pour accès global
static var instance: ParkPointsManager

func _ready():
	# Définir comme singleton
	instance = self
	
	# Scanner automatiquement les points d'intérêt
	call_deferred("_scan_park_points")
	
	print("[ParkManager] Initialisation du gestionnaire de points d'intérêt")

func _scan_park_points():
	# Scanner la scène pour trouver les points d'intérêt
	equipment_zones = _get_node3d_in_group("equipment_zone")
	adventure_courses = _get_node3d_in_group("adventure_course")
	playgrounds = _get_node3d_in_group("playground")
	picnic_tables = _get_node3d_in_group("picnic_table")
	toilets = _get_node3d_in_group("toilets")
	rest_areas = _get_node3d_in_group("rest_area")
	
	print("[ParkManager] Points d'intérêt trouvés:")
	print("  - Zones d'équipement: ", equipment_zones.size())
	print("  - Parcours d'aventure: ", adventure_courses.size())
	print("  - Aires de jeu: ", playgrounds.size())
	print("  - Tables de pique-nique: ", picnic_tables.size())
	print("  - Toilettes: ", toilets.size())
	print("  - Zones de repos: ", rest_areas.size())

func _get_node3d_in_group(group_name: String) -> Array[Node3D]:
	var nodes = get_tree().get_nodes_in_group(group_name)
	var node3d_array: Array[Node3D] = []
	
	for node in nodes:
		if node is Node3D:
			node3d_array.append(node as Node3D)
	
	return node3d_array

# Méthodes pour récupérer des positions aléatoires
func get_random_equipment_zone() -> Vector3:
	if equipment_zones.size() > 0:
		return equipment_zones[randi() % equipment_zones.size()].global_position
	return Vector3.ZERO

func get_random_adventure_course() -> Vector3:
	if adventure_courses.size() > 0:
		return adventure_courses[randi() % adventure_courses.size()].global_position
	return Vector3.ZERO

func get_random_playground() -> Vector3:
	if playgrounds.size() > 0:
		return playgrounds[randi() % playgrounds.size()].global_position
	return Vector3.ZERO

func get_random_picnic_table() -> Vector3:
	if picnic_tables.size() > 0:
		return picnic_tables[randi() % picnic_tables.size()].global_position
	return Vector3.ZERO

func get_random_toilets() -> Vector3:
	if toilets.size() > 0:
		return toilets[randi() % toilets.size()].global_position
	return Vector3.ZERO

func get_random_rest_area() -> Vector3:
	if rest_areas.size() > 0:
		return rest_areas[randi() % rest_areas.size()].global_position
	return Vector3.ZERO

# Méthode générique pour récupérer une position d'activité
func get_activity_position(activity_type: String) -> Vector3:
	match activity_type:
		"equipment_zone":
			return get_random_equipment_zone()
		"adventure_course":
			return get_random_adventure_course()
		"playground":
			return get_random_playground()
		"picnic_area":
			return get_random_picnic_table()
		"toilets":
			return get_random_toilets()
		"rest_area":
			return get_random_rest_area()
		_:
			print("[ParkManager] Type d'activité inconnu: ", activity_type)
			return Vector3.ZERO

# Dans park_points_manager.gd, modifier get_activity_preferences() :
func get_activity_preferences(ticket_data: Dictionary) -> Array[String]:
	var preferences = []
	
	match ticket_data.type:
		"Enfant":
			preferences = ["playground", "adventure_course", "picnic_area", "toilets"]
		"Adulte":
			preferences = ["adventure_course", "picnic_area", "rest_area", "toilets"]
		"Sénior":
			preferences = ["rest_area", "picnic_area", "toilets", "playground"]
	
	return preferences

# Méthode pour obtenir la durée d'une activité
func get_activity_duration(activity: String, ticket_data: Dictionary) -> float:
	var base_duration = 30.0
	
	match activity:
		"equipment_zone":
			return base_duration * 0.5  # Plus rapide
		"adventure_course":
			return base_duration * 2.0  # Plus long
		"playground":
			return base_duration * 1.5
		"rest_area":
			return base_duration * 1.2
		"picnic_area":
			return base_duration * 1.0
		"toilets":
			return base_duration * 0.3  # Très rapide
		_:
			return base_duration
