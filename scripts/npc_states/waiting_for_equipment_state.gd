# scripts/npc_states/waiting_for_equipment_state.gd
class_name WaitingForEquipmentState
extends NPCState

var equipment_zone_position: Vector3

func enter() -> void:
	print("[NPC] État: En attente d'équipement")
	npc.current_context = "waiting_for_equipment"
	npc.is_talking = false
	npc.speed = npc.walk_speed
	
	# Se diriger vers la zone d'équipement
	_navigate_to_equipment_zone()

func _navigate_to_equipment_zone():
	# Récupérer la position de la zone d'équipement
	if ParkPointsManager.instance:
		equipment_zone_position = ParkPointsManager.instance.get_random_equipment_zone()
		if equipment_zone_position != Vector3.ZERO:
			npc.agent.target_position = equipment_zone_position
			print("[NPC] Direction zone d'équipement: ", equipment_zone_position)
		else:
			print("[NPC] ERREUR: Aucune zone d'équipement trouvée!")
	else:
		print("[NPC] ERREUR: ParkPointsManager introuvable!")

func physics_process(delta: float) -> void:
	# Vérifier si on est arrivé à la zone d'équipement
	if npc.agent.is_navigation_finished():
		var distance_to_equipment = npc.global_position.distance_to(equipment_zone_position)
		if distance_to_equipment < 0.1:  # Proche de la zone d'équipement
			# S'arrêter et attendre
			npc.agent.set_target_position(npc.global_position)
			npc.speed = 0
