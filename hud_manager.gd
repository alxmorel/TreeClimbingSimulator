extends CanvasLayer
class_name HUDManager

# Références aux éléments du HUD
@export var day_label: Label
@export var time_label: Label
@export var park_state_label: Label
@export var money_label: Label
@export var skill_points_label: Label
@export var experience_bar: ProgressBar
@export var task_list_container: VBoxContainer

# Référence au GameManager
var game_manager: GameManager

# Références aux panels pour le style dynamique
var park_state_panel: Panel

func _ready():
	# Attendre que le moteur soit prêt
	await get_tree().process_frame
	
	# Trouver le GameManager (dans la même scène)
	game_manager = get_node_or_null("../GameManager")
	if not game_manager:
		print("Erreur: GameManager non trouvé dans HUDManager")
		return
	
	# Récupérer la référence au panel de l'état du parc
	park_state_panel = get_node_or_null("LeftPanel/LeftVBox/TimeStatePanel/StatePanel")
	
	# Connecter aux signaux du GameManager
	connect_to_game_manager()
	
	# Initialiser l'affichage
	update_all_displays()
	
	print("HUD Manager initialisé")

func connect_to_game_manager():
	if game_manager:
		game_manager.day_changed.connect(_on_day_changed)
		game_manager.hour_changed.connect(_on_hour_changed)
		game_manager.park_state_changed.connect(_on_park_state_changed)
		game_manager.money_changed.connect(_on_money_changed)
		game_manager.experience_changed.connect(_on_experience_changed)
		game_manager.skill_points_changed.connect(_on_skill_points_changed)

func update_all_displays():
	if not game_manager:
		return
	
	update_day_display()
	update_time_display()
	update_park_state_display()
	update_money_display()
	update_skill_points_display()
	update_experience_display()
	update_task_list()

# Mise à jour des affichages individuels
func update_day_display():
	if day_label and game_manager:
		day_label.text = str(game_manager.get_day())

func update_time_display():
	if time_label and game_manager:
		time_label.text = game_manager.get_time()

func update_park_state_display():
	if park_state_label and game_manager:
		park_state_label.text = game_manager.get_park_state()
		
		# Changer le style du panel selon l'état
		if park_state_panel:
			var style = StyleBoxFlat.new()
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.corner_radius_top_left = 8
			style.corner_radius_top_right = 8
			style.corner_radius_bottom_right = 8
			style.corner_radius_bottom_left = 8
			
			if game_manager.park_is_open:
				# Style vert pour ouvert
				style.bg_color = Color(0.2, 0.8, 0.2, 0.9)
				style.border_color = Color(0.4, 1, 0.4, 1)
			else:
				# Style rouge pour fermé
				style.bg_color = Color(0.8, 0.2, 0.2, 0.9)
				style.border_color = Color(1, 0.4, 0.4, 1)
			
			park_state_panel.add_theme_stylebox_override("panel", style)

func update_money_display():
	if money_label and game_manager:
		money_label.text = str(game_manager.get_money())

func update_skill_points_display():
	if skill_points_label and game_manager:
		skill_points_label.text = "⭐ " + str(game_manager.get_skill_points())

func update_experience_display():
	if experience_bar and game_manager:
		experience_bar.value = game_manager.get_experience_progress() * 100

func update_task_list():
	if not task_list_container or not game_manager:
		return
	
	# Nettoyer la liste existante
	for child in task_list_container.get_children():
		child.queue_free()
	
	# Ajouter les tâches actives
	var active_tasks = game_manager.get_active_tasks()
	for task in active_tasks:
		var task_item = create_task_item(task)
		task_list_container.add_child(task_item)

func create_task_item(task: Dictionary) -> Control:
	var task_panel = Panel.new()
	task_panel.custom_minimum_size = Vector2(250, 60)
	
	# Style du panneau
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	task_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	task_panel.add_child(vbox)
	
	# Titre de la tâche
	var title_label = Label.new()
	title_label.text = task.title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(title_label)
	
	# Description de la tâche
	var desc_label = Label.new()
	desc_label.text = task.description
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color.WHITE)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	# Récompenses
	if task.reward_money > 0 or task.reward_xp > 0:
		var reward_label = Label.new()
		var reward_text = "Récompense: "
		if task.reward_money > 0:
			reward_text += str(task.reward_money) + "€ "
		if task.reward_xp > 0:
			reward_text += str(task.reward_xp) + " XP"
		reward_label.text = reward_text
		reward_label.add_theme_font_size_override("font_size", 9)
		reward_label.add_theme_color_override("font_color", Color.CYAN)
		vbox.add_child(reward_label)
	
	return task_panel

# Callbacks des signaux
func _on_day_changed(new_day: int):
	update_day_display()

func _on_hour_changed(new_hour: int):
	update_time_display()

func _on_park_state_changed(is_open: bool):
	update_park_state_display()

func _on_money_changed(new_amount: int):
	update_money_display()

func _on_experience_changed(new_xp: int):
	update_experience_display()

func _on_skill_points_changed(new_points: int):
	update_skill_points_display()
	update_task_list()  # Mettre à jour aussi les tâches car elles peuvent changer
