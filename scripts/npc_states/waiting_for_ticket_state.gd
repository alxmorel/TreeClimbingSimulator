# scripts/npc_states/waiting_for_ticket_state.gd
class_name WaitingForTicketState
extends NPCState

func enter() -> void:
	print("[NPC] État: En attente de ticket")
	npc.current_context = "waiting_for_ticket"
	npc.speed = 0  # Arrêter le mouvement
	npc.is_talking = false  # S'assurer qu'il peut parler
	
	#Démarrer le dialogue automatiquement
	npc._start_dialogue()

func exit() -> void:
	print("[NPC] Quitte la file d'attente")
