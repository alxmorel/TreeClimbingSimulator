# scripts/npc_states/npc_state.gd
class_name NPCState
extends RefCounted

var npc: NPC
var state_machine: NPCStateMachine

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_process(delta: float) -> void:
	pass

func handle_input(event: InputEvent) -> void:
	pass
