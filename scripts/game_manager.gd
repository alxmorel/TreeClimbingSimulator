extends Node
class_name GameManager

signal day_changed(new_day: int)
signal hour_changed(new_hour: int)
signal park_state_changed(is_open: bool)
signal money_changed(new_amount: int)
signal experience_changed(new_xp: int)
signal skill_points_changed(new_points: int)

# Données de temps
var current_day: int = 1
var current_hour: float = 8.0  # 8h00 du matin
var time_speed: float = 1.0  # 1 seconde réelle = 1 minute de jeu

# État du parc
var park_is_open: bool = false
var park_open_hour: int = 9
var park_close_hour: int = 18

# Économie du joueur
var player_money: int = 1000
var player_experience: int = 0
var player_skill_points: int = 0
var experience_per_level: int = 100

# Tâches actives
var active_tasks: Array[Dictionary] = []

func _ready():
	# Démarrer le système de temps
	var timer = Timer.new()
	timer.wait_time = 1.0  # 1 seconde réelle
	timer.timeout.connect(_on_time_tick)
	timer.autostart = true
	add_child(timer)
	
	# Initialiser les tâches de démarrage
	initialize_starter_tasks()
	
	print("GameManager initialisé - Jour ", current_day, " à ", get_formatted_time())

func _on_time_tick():
	# Avancer le temps de 1 minute de jeu par seconde réelle
	current_hour += (1.0 / 60.0) * time_speed
	
	# Gestion du changement de jour
	if current_hour >= 24.0:
		current_hour = 0.0
		current_day += 1
		day_changed.emit(current_day)
		print("Nouveau jour: ", current_day)
	
	# Gestion de l'ouverture/fermeture du parc
	var should_be_open = current_hour >= park_open_hour and current_hour < park_close_hour
	if should_be_open != park_is_open:
		park_is_open = should_be_open
		park_state_changed.emit(park_is_open)
		print("Parc ", "ouvert" if park_is_open else "fermé")
	
	hour_changed.emit(int(current_hour))

# Obtenir l'heure formatée (HH:MM)
func get_formatted_time() -> String:
	var hours = int(current_hour)
	var minutes = int((current_hour - hours) * 60)
	return "%02d:%02d" % [hours, minutes]

# Gestion de l'argent
func add_money(amount: int):
	player_money += amount
	money_changed.emit(player_money)
	print("Argent ajouté: +", amount, " (Total: ", player_money, ")")

func spend_money(amount: int) -> bool:
	if player_money >= amount:
		player_money -= amount
		money_changed.emit(player_money)
		print("Argent dépensé: -", amount, " (Reste: ", player_money, ")")
		return true
	else:
		print("Pas assez d'argent! Requis: ", amount, ", Disponible: ", player_money)
		return false

func can_afford(amount: int) -> bool:
	return player_money >= amount

# Gestion de l'expérience
func add_experience(amount: int):
	player_experience += amount
	experience_changed.emit(player_experience)
	
	# Vérifier si le joueur gagne des points de compétence
	var new_skill_points = player_experience / experience_per_level
	if new_skill_points > player_skill_points:
		var gained_points = new_skill_points - player_skill_points
		player_skill_points = new_skill_points
		skill_points_changed.emit(player_skill_points)
		print("Niveau atteint! +", gained_points, " points de compétence")
	
	print("Expérience gagnée: +", amount, " (Total: ", player_experience, ")")

# Gestion des tâches
func add_task(title: String, description: String, reward_money: int = 0, reward_xp: int = 0):
	var task = {
		"id": generate_task_id(),
		"title": title,
		"description": description,
		"reward_money": reward_money,
		"reward_xp": reward_xp,
		"completed": false
	}
	active_tasks.append(task)
	print("Nouvelle tâche: ", title)

func complete_task(task_id: String):
	for i in range(active_tasks.size()):
		var task = active_tasks[i]
		if task.id == task_id and not task.completed:
			task.completed = true
			
			# Donner les récompenses
			if task.reward_money > 0:
				add_money(task.reward_money)
			if task.reward_xp > 0:
				add_experience(task.reward_xp)
			
			print("Tâche terminée: ", task.title)
			break

func get_active_tasks() -> Array[Dictionary]:
	var active = []
	for task in active_tasks:
		if not task.completed:
			active.append(task)
	return active

func generate_task_id() -> String:
	return "task_" + str(Time.get_unix_time_from_system())

# Initialiser les tâches de démarrage
func initialize_starter_tasks():
	add_task("Bienvenue!", "Placez votre premier arbre dans le parc", 50, 25)
	add_task("Développement", "Placez 5 objets dans le parc", 200, 100)
	add_task("Gestionnaire", "Accumulez 2000€", 0, 150)

# Getters pour le HUD
func get_day() -> int:
	return current_day

func get_time() -> String:
	return get_formatted_time()

func get_park_state() -> String:
	return "Ouvert" if park_is_open else "Fermé"

func get_money() -> int:
	return player_money

func get_experience() -> int:
	return player_experience

func get_experience_progress() -> float:
	return float(player_experience % experience_per_level) / float(experience_per_level)

func get_skill_points() -> int:
	return player_skill_points
