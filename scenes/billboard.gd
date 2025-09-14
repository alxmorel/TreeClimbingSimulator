# res://scenes/billboard/Billboard.gd
extends ObjectInteractable

@onready var label = get_parent().get_node("SubViewport/Control/Label") as Label

# Retourne les infos pour le travel de la caméra : position relative ou offset, durée, etc.
func get_camera_travel_params() -> Dictionary:
	return {
		"offset": Vector3(-2, 5, -8), # position relative depuis l'objet
		"duration": 0.8,
		"look_at": global_transform.origin + Vector3(0, 1.0, 0) # point que la caméra doit regarder
	}

func object_interact() -> void:
	# Crée une fenêtre de saisie simple
	var line_edit := LineEdit.new()
	line_edit.custom_minimum_size.x = 250.0
	line_edit.custom_minimum_size.y = 38.0

	line_edit.placeholder_text = "Entrez votre texte..."
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.grab_focus()

	# Quand l'utilisateur valide (Enter), on change le Label
	line_edit.connect("text_submitted", Callable(self, "_on_text_submitted"))
	# Gérer l'annulation avec Escape
	line_edit.connect("gui_input", Callable(self, "_on_line_edit_input"))

	# On ajoute le champ de texte dans le CanvasLayer global (UI)
	if GlobalContext.ui_context:
		print("GlobalContext.ui_context : ",GlobalContext.ui_context )
		GlobalContext.ui_context.show_input(line_edit)


func _on_text_submitted(new_text: String) -> void:
	print("Texte soumis:", new_text)
	print("Label instance:", label)
	if label:
		label.text = new_text
	else:
		print("⚠️ label est null, vérifie le chemin $SubViewport/Control/Label")

	if GlobalContext.ui_context:
		GlobalContext.ui_context.hide_input()
	
	# Restaurer la caméra après validation
	GlobalContext.player.restore_camera_to_player()

		
func _on_line_edit_input(event: InputEvent) -> void:
	if event is InputEventKey:
		# Bloquer uniquement Escape pour sortir du mode input
		if event.is_action_pressed("ui_cancel"):
			if GlobalContext.ui_context:
				GlobalContext.ui_context.hide_input()
			GlobalContext.player.restore_camera_to_player()
			# Consume event
			get_viewport().set_input_as_handled()
