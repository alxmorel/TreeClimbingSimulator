extends CenterContainer
class_name ContextComponent

@export var default_key_action: String = "E"

@onready var button: Button = $HBoxContainer/Button
@onready var context: Label = $HBoxContainer/Label

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
