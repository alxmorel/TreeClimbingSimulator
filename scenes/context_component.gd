extends CenterContainer
class_name ContextComponent

@export var default_key_action: String = "E"

@onready var button: Button = $HBoxContainer/Button
@onready var context: Label = $HBoxContainer/Label

var input_active: bool = false

func _ready() -> void:
	GlobalContext.ui_context = self
	reset()

func reset() -> void:
	button.text = default_key_action
	context.text = ""
	visible = false  # caché par défaut

func update_key_action(key_label: String = "") -> void:
	button.text = key_label if key_label != "" else default_key_action

func update_content(my_text: String) -> void:
	context.text = my_text
	visible = true

func show_input(control: Control) -> void:
	# Cacher le bouton et label d’interaction pour ne pas interférer
	button.visible = false
	context.visible = false
	
	add_child(control)
	control.grab_focus()
	input_active = true
	GlobalContext.input_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # libère la souris

func hide_input() -> void:	
	for child in get_children():
		if child is LineEdit:
			child.queue_free()
	input_active = false
	GlobalContext.input_active = false
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Réactiver bouton et label d'interaction
	button.visible = true
	context.visible = true
