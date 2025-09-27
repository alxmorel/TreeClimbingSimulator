# scripts/npc_states/seeking_ticket_state.gd
class_name SeekingTicketState
extends NPCState

func enter() -> void:
	print("[NPC] État: Recherche de ticket")
	npc.current_context = "seeking_ticket"
	_set_target_to_billeterie()

func _set_target_to_billeterie():
	if GlobalContext.target_billeterie:
		npc.agent.target_position = GlobalContext.target_billeterie.global_position
		print("[NPC] Direction billeterie: ", GlobalContext.target_billeterie.global_position)
	else:
		print("[NPC] ERREUR: TargetBilleterie introuvable!")

func physics_process(delta: float) -> void:
	# Vérifier si on est arrivé à la billeterie
	if npc.agent.is_navigation_finished():
		var distance_to_billeterie = npc.global_position.distance_to(GlobalContext.target_billeterie.global_position)
		if distance_to_billeterie < 3.0:  # Proche de la billeterie
			print("[NPC] Arrivé à la billeterie, passage en attente")
			state_machine.change_state("waiting_for_ticket")
