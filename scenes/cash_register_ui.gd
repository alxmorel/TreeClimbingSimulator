extends Control
signal ticket_ready_to_print(ticket_data)

@onready var btn_enfant = %btn_enfant
@onready var btn_adulte = %btn_adulte
@onready var btn_senior = %btn_senior
@onready var btn_mi_journee = %btn_mi_journee
@onready var btn_journee = %btn_journee
@onready var btn_basic = %btn_basic
@onready var btn_sensation = %btn_sensation
@onready var btn_impression_ticket = %btn_impression_ticket

var type_personne := ""
var duree := ""
var parcours := ""

# Références aux boutons sélectionnés pour les styles
var selected_type_button: Button = null
var selected_duree_button: Button = null
var selected_parcours_button: Button = null

# Curseur de débogage
var debug_cursor: ColorRect = null

func _ready():
	# Connecter les signaux
	btn_enfant.pressed.connect(_on_type_pressed.bind("Enfant", btn_enfant))
	btn_adulte.pressed.connect(_on_type_pressed.bind("Adulte", btn_adulte))
	btn_senior.pressed.connect(_on_type_pressed.bind("Sénior", btn_senior))
	btn_mi_journee.pressed.connect(_on_duree_pressed.bind("1/2 Journée", btn_mi_journee))
	btn_journee.pressed.connect(_on_duree_pressed.bind("Journée", btn_journee))
	btn_basic.pressed.connect(_on_parcours_pressed.bind("Basic", btn_basic))
	btn_sensation.pressed.connect(_on_parcours_pressed.bind("Sensation", btn_sensation))
	btn_impression_ticket.pressed.connect(_on_impression_ticket_pressed)
	
	# Style initial pour le bouton d'impression (désactivé)
	_update_print_button_state()
	
	# Créer un curseur de débogage
	_create_debug_cursor()

func _on_type_pressed(value: String, button: Button):
	type_personne = value
	_update_selection_style(selected_type_button, button)
	selected_type_button = button
	_update_print_button_state()
	print("👤 Type sélectionné: ", value)

func _on_duree_pressed(value: String, button: Button):
	duree = value
	_update_selection_style(selected_duree_button, button)
	selected_duree_button = button
	_update_print_button_state()
	print("⏰ Durée sélectionnée: ", value)

func _on_parcours_pressed(value: String, button: Button):
	parcours = value
	_update_selection_style(selected_parcours_button, button)
	selected_parcours_button = button
	_update_print_button_state()
	print("🎯 Parcours sélectionné: ", value)

func _on_impression_ticket_pressed():
	if type_personne != "" and duree != "" and parcours != "":
		var data = {"type_personne": type_personne, "duree": duree, "parcours": parcours}
		print("🎫 Impression du ticket: ", data)
		emit_signal("ticket_ready_to_print", data)
		_reset_selections()
	else:
		print("⚠️ Sélectionnez toutes les catégories avant d'imprimer")

func _reset_selections():
	type_personne = ""
	duree = ""
	parcours = ""
	
	# Réinitialiser les styles des boutons
	_reset_button_style(selected_type_button)
	_reset_button_style(selected_duree_button)
	_reset_button_style(selected_parcours_button)
	
	selected_type_button = null
	selected_duree_button = null
	selected_parcours_button = null
	
	_update_print_button_state()

func _update_selection_style(old_button: Button, new_button: Button):
	# Réinitialiser l'ancien bouton
	if old_button:
		_reset_button_style(old_button)
	
	# Styler le nouveau bouton sélectionné
	if new_button:
		new_button.modulate = Color(1.2, 1.2, 0.8)  # Couleur dorée pour la sélection

func _reset_button_style(button: Button):
	if button:
		button.modulate = Color.WHITE

func _update_print_button_state():
	var can_print = type_personne != "" and duree != "" and parcours != ""
	btn_impression_ticket.disabled = not can_print
	
	if can_print:
		btn_impression_ticket.modulate = Color(0.8, 1.2, 0.8)  # Vert quand prêt
	else:
		btn_impression_ticket.modulate = Color(0.7, 0.7, 0.7)  # Gris quand pas prêt

func _create_debug_cursor():
	# Créer un curseur de débogage visible
	debug_cursor = ColorRect.new()
	debug_cursor.size = Vector2(20, 20)
	debug_cursor.color = Color.RED
	debug_cursor.z_index = 100  # Au-dessus de tout
	debug_cursor.visible = false
	add_child(debug_cursor)
	
	print("🎯 Curseur de débogage créé")

func show_debug_cursor_at(pos: Vector2):
	if debug_cursor:
		debug_cursor.position = pos - Vector2(10, 10)  # Centrer le curseur
		debug_cursor.visible = true
		print("🔴 Curseur débogage à: ", pos)

func hide_debug_cursor():
	if debug_cursor:
		debug_cursor.visible = false

# Fonction pour tester la projection depuis l'extérieur
func debug_mouse_projection(mouse_pos: Vector2):
	show_debug_cursor_at(mouse_pos)
	print("🖱️ Projection souris sur interface: ", mouse_pos)
