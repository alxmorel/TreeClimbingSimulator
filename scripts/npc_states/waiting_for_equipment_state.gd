# scripts/npc_states/waiting_for_equipment_state.gd
class_name WaitingForEquipmentState
extends NPCState

var equipment_zone_position: Vector3
var reserved_equipment_zone: Node3D

func enter() -> void:
	print("[NPC] État: En attente d'équipement")
	npc.current_context = "waiting_for_equipment"
	npc.is_talking = false
	npc.speed = npc.walk_speed
	
	# Se diriger vers la zone d'équipement
	_navigate_to_equipment_zone()

func _navigate_to_equipment_zone():
	# Récupérer une zone d'équipement disponible
	if ParkPointsManager.instance:
		reserved_equipment_zone = ParkPointsManager.instance.get_random_available_equipment_zone()
		if reserved_equipment_zone:
			# Réserver le point
			var npc_id = npc.get_instance_id()
			if ParkPointsManager.instance.reserve_point(reserved_equipment_zone, npc_id):
				equipment_zone_position = reserved_equipment_zone.global_position
				npc.agent.target_position = equipment_zone_position
				print("[NPC] Zone d'équipement réservée: ", equipment_zone_position)
			else:
				print("[NPC] ERREUR: Impossible de réserver la zone d'équipement!")
		else:
			print("[NPC] ERREUR: Aucune zone d'équipement disponible!")
	else:
		print("[NPC] ERREUR: ParkPointsManager introuvable!")

func physics_process(delta: float) -> void:
	# Vérifier si on est arrivé à la zone d'équipement
	if npc.agent.is_navigation_finished():
		var distance_to_equipment = npc.global_position.distance_to(equipment_zone_position)
		if distance_to_equipment < 0.05:  # Proche de la zone d'équipement
			# Occuper le point
			var npc_id = npc.get_instance_id()
			ParkPointsManager.instance.occupy_point(reserved_equipment_zone, npc_id)
			
			# S'arrêter et attendre
			npc.agent.set_target_position(npc.global_position)
			npc.speed = 0

func exit() -> void:
	# Libérer le point quand on quitte cet état
	if reserved_equipment_zone:
		var npc_id = npc.get_instance_id()
		ParkPointsManager.instance.release_point(reserved_equipment_zone, npc_id)
