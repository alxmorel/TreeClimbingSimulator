# scripts/npc_states/waiting_for_ticket_state.gd
class_name WaitingForTicketState
extends NPCState

func enter() -> void:
	print("[NPC] État: En attente de ticket")
	npc.current_context = "waiting_for_ticket"
	npc.agent.set_target_position(npc.global_position)  # S'arrêter
	npc.speed = 0  # Arrêter le mouvement

func physics_process(delta: float) -> void:
	# Dans cet état, le NPC attend que le joueur lui donne un ticket
	# La logique de réception du ticket est gérée dans NPC.receive_ticket()
	pass

func exit() -> void:
	# Remettre la vitesse normale quand on quitte cet état
	npc.speed = npc.walk_speed
