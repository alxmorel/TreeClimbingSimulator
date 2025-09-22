# DialogueUI.gd
extends Control

@onready var dialogue_label : Label = $Panel/MarginContainer/Label
var current_lines: Array[String] = []
var current_index := 0
	
func _ready():
	dialogue_label.text = ""
	visible = false
	
func _unhandled_input(event):
	if visible and event.is_action_pressed("ui_accept"):  # ui_accept = Entrée ou Espace
		next_line()

func start_dialogue(lines: Array[String]):
	current_lines = lines
	current_index = 0
	visible = true
	_show_line()

func _show_line():
	if current_index < current_lines.size():
		dialogue_label.text = current_lines[current_index]
	else:
		_end_dialogue()

func next_line():
	current_index += 1
	_show_line()

func _end_dialogue():
	visible = false
	GlobalContext.player.restore_camera_to_player()
