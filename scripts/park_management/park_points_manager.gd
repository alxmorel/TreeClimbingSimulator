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

var ticket_office_queue: Array[Node3D] = []  # Points de la file d'attente
var queue_positions: Dictionary = {}  # {npc_id: queue_index}
var queue_occupancy: Dictionary = {}  # {queue_index: npc_id}

# État des points (disponible, réservé, occupé)
var point_states: Dictionary = {}  # {node_id: "available"/"reserved"/"occupied"}
var point_reservations: Dictionary = {}  # {node_id: npc_id}

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
	
	_scan_ticket_office_queue()
	
	# Initialiser tous les points comme disponibles
	_initialize_point_states()
	
	print("[ParkManager] Points d'intérêt trouvés:")
	print("  - Zones d'équipement: ", equipment_zones.size())
	print("  - Parcours d'aventure: ", adventure_courses.size())
	print("  - Aires de jeu: ", playgrounds.size())
	print("  - Tables de pique-nique: ", picnic_tables.size())
	print("  - Toilettes: ", toilets.size())
	print("  - Zones de repos: ", rest_areas.size())
	

func _scan_ticket_office_queue():
	# Chercher les points de la file d'attente (triés par ordre)
	var queue_nodes = get_tree().get_nodes_in_group("ticket_office_queue")
	
	#Trier par numéro dans le nom
	queue_nodes.sort_custom(func(a, b): 
		# Extraire le numéro du nom (ex: TicketOfficeQueue1 -> 1)
		var a_num = a.name.get_slice("TicketOfficeQueue", 1).to_int()
		var b_num = b.name.get_slice("TicketOfficeQueue", 1).to_int()
		return a_num < b_num
	)
	
	for node in queue_nodes:
		if node is Node3D:
			ticket_office_queue.append(node as Node3D)
			print("[ParkManager] Point de file trouvé: ", node.name, " à ", node.global_position)
	
	print("[ParkManager] File d'attente configurée avec ", ticket_office_queue.size(), " positions")
	
	# Afficher l'ordre des positions
	for i in range(ticket_office_queue.size()):
		print("[ParkManager] Position ", i, ": ", ticket_office_queue[i].name, " à ", ticket_office_queue[i].global_position)
	


func join_ticket_queue(npc_id: int) -> int:
	# Trouver la première position libre (pas la plus proche)
	for i in range(ticket_office_queue.size()):
		if not queue_occupancy.has(i):
			queue_occupancy[i] = npc_id
			queue_positions[npc_id] = i
			print("[ParkManager] NPC ", npc_id, " rejoint la file à la position ", i)
			return i
	
	print("[ParkManager] File d'attente pleine pour NPC ", npc_id)
	return -1

func leave_ticket_queue(npc_id: int) -> bool:
	if not queue_positions.has(npc_id):
		return false
	
	var position = queue_positions[npc_id]
	queue_occupancy.erase(position)
	queue_positions.erase(npc_id)
	
	print("[ParkManager] NPC ", npc_id, " quitte la file à la position ", position)
	
	# NOUVEAU : Faire avancer la file
	_advance_queue()
	
	return true

func _advance_queue():
	print("[ParkManager] === AVANCEMENT DE LA FILE ===")
	
	# Faire avancer tous les NPCs dans la file
	for i in range(ticket_office_queue.size() - 1):
		if queue_occupancy.has(i + 1) and not queue_occupancy.has(i):
			# Déplacer le NPC de la position i+1 vers i
			var npc_id = queue_occupancy[i + 1]
			queue_occupancy[i] = npc_id
			queue_occupancy.erase(i + 1)
			queue_positions[npc_id] = i
			
			print("[ParkManager] NPC ", npc_id, " avance de la position ", i + 1, " vers ", i)
			
			# NOUVEAU : Forcer la navigation vers la nouvelle position
			_force_npc_navigation(npc_id, i)
	
	# NOUVEAU : Vérifier si le nouveau premier peut passer en attente
	_check_first_position_availability()
	
	print("[ParkManager] === FIN AVANCEMENT ===")

# NOUVEAU : Forcer la navigation d'un NPC
func _force_npc_navigation(npc_id: int, new_position: int):
	var npc_nodes = get_tree().get_nodes_in_group("npc")
	for npc in npc_nodes:
		if npc.get_instance_id() == npc_id:
			# NOUVEAU : Forcer la navigation vers la nouvelle position
			if npc.has_method("_navigate_to_queue_position"):
				npc._navigate_to_queue_position(new_position)
			break

# NOUVEAU : Notifier le NPC du changement de position
func _notify_npc_queue_position_change(npc_id: int, new_position: int):
	# Trouver le NPC dans la scène
	var npc_nodes = get_tree().get_nodes_in_group("npc")
	for npc in npc_nodes:
		if npc.get_instance_id() == npc_id:
			# NOUVEAU : Déclencher la re-navigation vers la nouvelle position
			if npc.has_method("_on_queue_position_changed"):
				npc._on_queue_position_changed(new_position)
			break

# NOUVEAU : Vérifier si le nouveau premier peut passer en attente
func _check_first_position_availability():
	if queue_occupancy.has(0):
		var first_npc_id = queue_occupancy[0]
		var npc_nodes = get_tree().get_nodes_in_group("npc")
		for npc in npc_nodes:
			if npc.get_instance_id() == first_npc_id:
				# NOUVEAU : Vérifier si le NPC est en SeekingTicketState
				if npc.has_method("get_current_state_name") and npc.get_current_state_name() == "SeekingTicketState":
					print("[ParkManager] NPC ", first_npc_id, " peut maintenant passer en attente de ticket")
					# Le NPC passera automatiquement en WaitingForTicketState via son physics_process
				break

func get_ticket_queue_position(npc_id: int) -> Node3D:
	if not queue_positions.has(npc_id):
		return null
	
	var position = queue_positions[npc_id]
	if position < ticket_office_queue.size():
		return ticket_office_queue[position]
	
	return null

func is_at_front_of_queue(npc_id: int) -> bool:
	return queue_positions.get(npc_id, -1) == 0

func get_queue_position_count() -> int:
	return queue_occupancy.size()


func _get_node3d_in_group(group_name: String) -> Array[Node3D]:
	var nodes = get_tree().get_nodes_in_group(group_name)
	var node3d_array: Array[Node3D] = []
	
	for node in nodes:
		if node is Node3D:
			node3d_array.append(node as Node3D)
	
	return node3d_array


func _initialize_point_states():
	# Initialiser l'état de tous les points
	for point in equipment_zones:
		point_states[point.get_instance_id()] = "available"
	
	for point in adventure_courses:
		point_states[point.get_instance_id()] = "available"
	
	for point in playgrounds:
		point_states[point.get_instance_id()] = "available"
	
	for point in picnic_tables:
		point_states[point.get_instance_id()] = "available"
	
	for point in toilets:
		point_states[point.get_instance_id()] = "available"
	
	for point in rest_areas:
		point_states[point.get_instance_id()] = "available"


# Méthodes pour réserver et libérer des points
func reserve_point(point: Node3D, npc_id: int) -> bool:
	var point_id = point.get_instance_id()
	
	if point_states.has(point_id) and point_states[point_id] == "available":
		point_states[point_id] = "reserved"
		point_reservations[point_id] = npc_id
		print("[ParkManager] Point réservé par NPC ", npc_id, " : ", point.name)
		return true
	else:
		print("[ParkManager] Point non disponible: ", point.name)
		return false

func occupy_point(point: Node3D, npc_id: int) -> bool:
	var point_id = point.get_instance_id()
	
	if point_states.has(point_id) and point_states[point_id] == "reserved" and point_reservations[point_id] == npc_id:
		point_states[point_id] = "occupied"
		print("[ParkManager] Point occupé par NPC ", npc_id, " : ", point.name)
		return true
	else:
		print("[ParkManager] Impossible d'occuper le point: ", point.name)
		return false

func release_point(point: Node3D, npc_id: int) -> bool:
	var point_id = point.get_instance_id()
	
	if point_states.has(point_id) and point_reservations.has(point_id) and point_reservations[point_id] == npc_id:
		point_states[point_id] = "available"
		point_reservations.erase(point_id)
		print("[ParkManager] Point libéré par NPC ", npc_id, " : ", point.name)
		return true
	else:
		print("[ParkManager] Point non réservé par ce NPC: ", point.name)
		return false


# Méthodes pour récupérer des positions disponibles
func get_random_available_equipment_zone() -> Node3D:
	return _get_random_available_point(equipment_zones)

func get_random_available_adventure_course() -> Node3D:
	return _get_random_available_point(adventure_courses)

func get_random_available_playground() -> Node3D:
	return _get_random_available_point(playgrounds)

func get_random_available_picnic_table() -> Node3D:
	return _get_random_available_point(picnic_tables)

func get_random_available_toilets() -> Node3D:
	return _get_random_available_point(toilets)

func get_random_available_rest_area() -> Node3D:
	return _get_random_available_point(rest_areas)


func _get_random_available_point(points: Array[Node3D]) -> Node3D:
	var available_points = []
	
	for point in points:
		var point_id = point.get_instance_id()
		if point_states.has(point_id) and point_states[point_id] == "available":
			available_points.append(point)
	
	if available_points.size() > 0:
		return available_points[randi() % available_points.size()]
	else:
		print("[ParkManager] Aucun point disponible dans cette catégorie")
		return null
		
	
# Méthode générique pour récupérer une position d'activité disponible
func get_available_activity_position(activity_type: String) -> Node3D:
	match activity_type:
		"equipment_zone":
			return get_random_available_equipment_zone()
		"adventure_course":
			return get_random_available_adventure_course()
		"playground":
			return get_random_available_playground()
		"picnic_area":
			return get_random_available_picnic_table()
		"toilets":
			return get_random_available_toilets()
		"rest_area":
			return get_random_available_rest_area()
		_:
			print("[ParkManager] Type d'activité inconnu: ", activity_type)
			return null


# Méthodes pour obtenir l'état des points
func is_point_available(point: Node3D) -> bool:
	var point_id = point.get_instance_id()
	return point_states.has(point_id) and point_states[point_id] == "available"

func is_point_reserved_by(point: Node3D, npc_id: int) -> bool:
	var point_id = point.get_instance_id()
	return point_states.has(point_id) and point_states[point_id] == "reserved" and point_reservations.get(point_id) == npc_id

func get_point_state(point: Node3D) -> String:
	var point_id = point.get_instance_id()
	return point_states.get(point_id, "unknown")


# Méthodes pour obtenir des informations sur les points
func get_available_points_count(activity_type: String) -> int:
	var points = []
	match activity_type:
		"equipment_zone":
			points = equipment_zones
		"adventure_course":
			points = adventure_courses
		"playground":
			points = playgrounds
		"picnic_area":
			points = picnic_tables
		"toilets":
			points = toilets
		"rest_area":
			points = rest_areas
	
	var count = 0
	for point in points:
		if is_point_available(point):
			count += 1
	
	return count

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
