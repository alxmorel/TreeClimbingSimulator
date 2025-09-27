# scripts/npc_states/exploring_park_state.gd
class_name ExploringParkState
extends NPCState

var current_activity: String = ""
var activity_duration: float = 0.0
var max_activity_duration: float = 30.0
var park_manager: ParkPointsManager

func enter() -> void:
	print("[NPC] État: Exploration du parc")
	npc.current_context = "exploring_park"
	npc.speed = npc.walk_speed  # Vitesse normale
	
	# Récupérer le gestionnaire de points d'intérêt
	park_manager = ParkPointsManager.instance
	if not park_manager:
		push_error("[NPC] ParkPointsManager introuvable!")
		return
	
	_choose_next_activity()

func _choose_next_activity():
	if not park_manager:
		return
	
	# Obtenir les préférences basées sur le ticket (si disponible)
	var preferences = []
	if npc.ticket_data and not npc.ticket_data.is_empty():
		preferences = park_manager.get_activity_preferences(npc.ticket_data)
	else:
		# Préférences par défaut (sans zone d'équipement)
		preferences = ["adventure_course", "playground", "picnic_area", "rest_area", "toilets"]
	
	# Choisir une activité aléatoire parmi les préférences
	current_activity = preferences[randi() % preferences.size()]
	activity_duration = 0.0
	max_activity_duration = park_manager.get_activity_duration(current_activity, npc.ticket_data if npc.ticket_data else {})
	
	print("[NPC] Nouvelle activité choisie: ", current_activity, " (durée: ", max_activity_duration, "s)")
	_navigate_to_activity()

func _navigate_to_activity():
	if not park_manager:
		return
	
	var target_position = park_manager.get_activity_position(current_activity)
	if target_position != Vector3.ZERO:
		npc.agent.target_position = target_position
		print("[NPC] Direction: ", current_activity, " à ", target_position)
	else:
		print("[NPC] Aucune position trouvée pour: ", current_activity)
		# Choisir une autre activité
		_choose_next_activity()

func physics_process(delta: float) -> void:
	activity_duration += delta
	
	# Si l'activité est terminée, en choisir une nouvelle
	if activity_duration >= max_activity_duration:
		print("[NPC] Activité terminée, choix d'une nouvelle activité")
		_choose_next_activity()
	
	# Si arrivé à destination, faire une pause
	if npc.agent.is_navigation_finished():
		# Le NPC reste sur place pendant l'activité
		pass
