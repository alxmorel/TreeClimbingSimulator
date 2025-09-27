# scripts/npc_states/npc_state_machine.gd
class_name NPCStateMachine
extends RefCounted

var states: Dictionary = {}
var current_state: NPCState
var npc: NPC

func _init(npc_instance: NPC):
	npc = npc_instance

func add_state(state_name: String, state: NPCState):
	states[state_name] = state
	state.npc = npc
	state.state_machine = self

func change_state(state_name: String):
	if current_state:
		current_state.exit()
	
	current_state = states.get(state_name)
	if current_state:
		print("[NPC StateMachine] Changement vers: ", state_name)
		current_state.enter()

func physics_process(delta: float):
	if current_state:
		current_state.physics_process(delta)
