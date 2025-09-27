class_name StateMachine
extends Node

signal state_changed(from: State, to: State)

var current_state: State
var states: Dictionary = {}
var player: CharacterBody3D

func _init(p: CharacterBody3D):
	player = p

func add_state(state_name: String, state: State) -> void:
	state.state_machine = self
	state.player = player
	states[state_name] = state

func start(initial_state_name: String) -> void:
	if initial_state_name in states:
		current_state = states[initial_state_name]
		current_state.enter()

func change_state(new_state_name: String) -> void:
	if not new_state_name in states:
		print("État inexistant : ", new_state_name)
		return
	
	if current_state:
		current_state.exit()
		var old_state = current_state
		current_state = states[new_state_name]
		current_state.enter()
		state_changed.emit(old_state, current_state)
	else:
		current_state = states[new_state_name]
		current_state.enter()

func physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process(delta)

func handle_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func get_current_state_name() -> String:
	for state_name in states.keys():
		if states[state_name] == current_state:
			return state_name
	return ""
