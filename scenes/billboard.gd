# res://scenes/billboard/Billboard.gd
class_name Billboard
extends ObjectInteractable

@onready var label = $SubViewport/Control/Label as Label

func _ready():
	super._ready()
	
	# Configuration spécifique du billboard
	set_interaction_config("Changer nom du parc", "ui_accept", true)
	set_camera_animation(true, Vector3(-2, 5, -8), 0.8)
	
	# Configurer le point de regard de la caméra
	interaction_data.camera_look_at_offset = Vector3(0, 1.0, 0)

# Retourne le texte que l'UI doit afficher pour cette interaction
func get_interaction_label() -> String:
	return "Changer nom du parc"

func object_interact() -> bool:
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
		GlobalContext.ui_context.show_input(line_edit)
	
	return true  # Interaction réussie


func _on_text_submitted(new_text: String) -> void:
	if label:
		label.text = new_text

	if GlobalContext.ui_context:
		GlobalContext.ui_context.hide_input()
	
	# Restaurer la caméra après validation
	if GlobalContext.player and GlobalContext.player.has_method("restore_camera_to_player"):
		GlobalContext.player.restore_camera_to_player()

		
func _on_line_edit_input(event: InputEvent) -> void:
	if event is InputEventKey:
		# Bloquer uniquement Escape pour sortir du mode input
		if event.is_action_pressed("ui_cancel"):
			if GlobalContext.ui_context:
				GlobalContext.ui_context.hide_input()
			if GlobalContext.player and GlobalContext.player.has_method("restore_camera_to_player"):
				GlobalContext.player.restore_camera_to_player()
			# Consume event
			get_viewport().set_input_as_handled()
