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
	
	# NOUVEAU : Utiliser directement les données de Personne
	var preferences = _get_preferences_from_personne()
	
	# Choisir une activité aléatoire parmi les préférences
	current_activity = preferences[randi() % preferences.size()]
	activity_duration = 0.0
	max_activity_duration = park_manager.get_activity_duration(current_activity, {})
	
	print("[NPC] Nouvelle activité choisie: ", current_activity, " (durée: ", max_activity_duration, "s)")
	_navigate_to_activity()


func _get_preferences_from_personne() -> Array[String]:
	if not npc.data:
		return ["adventure_course", "playground", "picnic_area", "rest_area", "toilets"]
	
	var preferences: Array[String] = []
	var personne = npc.data
	
	  # Si des préférences personnalisées sont définies, les utiliser
	if not personne.preferences_activites.is_empty():
		return personne.preferences_activites
	
	# Préférences basées sur l'âge
	match personne.tranche_age:
		"Enfant":
			preferences = ["playground", "adventure_course", "picnic_area"]
		"Adulte":
			preferences = ["adventure_course", "picnic_area", "rest_area", "toilets"]
		"Senior":
			preferences = ["picnic_area", "rest_area", "toilets"]
	
	# Ajuster selon la taille (pour les activités physiques)
	if personne.taille > 1.6:  # Taille adulte
		if "adventure_course" not in preferences:
			preferences.append("adventure_course")
	
	# Ajuster selon le poids (pour l'énergie)
	if personne.poids < 60:  # Léger = plus d'énergie
		if "playground" not in preferences:
			preferences.append("playground")
	elif personne.poids > 80:  # Lourd = moins d'énergie
		if "rest_area" not in preferences:
			preferences.append("rest_area")
	
	# Ajuster selon le sexe (préférences culturelles)
	match personne.sexe:
		"Homme":
			# Préférence pour les activités plus physiques
			if "adventure_course" not in preferences:
				preferences.append("adventure_course")
		"Femme":
			# Préférence pour les activités plus sociales
			if "picnic_area" not in preferences:
				preferences.append("picnic_area")
				
	 # Ajuster selon le niveau d'énergie
	match personne.niveau_energie:
		"low":
			preferences = ["picnic_area", "rest_area", "toilets"]
		"medium":
			preferences.append("adventure_course")
		"high":
			preferences.append("playground")
			preferences.append("adventure_course")
	
	# Ajuster selon le groupe
	match personne.groupe:
		"famille":
			preferences.append("playground")
			preferences.append("picnic_area")
		"couple":
			preferences.append("picnic_area")
			preferences.append("rest_area")
		"groupe":
			preferences.append("adventure_course")
			preferences.append("playground")
	
	print("[NPC] Préférences générées pour ", personne.prenom, " (", personne.tranche_age, "): ", preferences)
	return preferences


func _navigate_to_activity():
	if not park_manager:
		return
	
	var target_node = park_manager.get_available_activity_position(current_activity)
	if target_node and target_node is Node3D:
		var target_position = target_node.global_transform.origin
		if target_position != Vector3.ZERO:
			npc.agent.target_position = target_position
			print("[NPC] Direction: ", current_activity, " à ", target_position)
	else:
		print("[NPC] Aucune position trouvée pour: ", current_activity)
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
