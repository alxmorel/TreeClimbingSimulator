# scripts/npc_states/seeking_ticket_state.gd
class_name SeekingTicketState
extends NPCState

func enter() -> void:
	print("[NPC] État: Recherche de ticket")
	npc.current_context = "seeking_ticket"
	_join_ticket_queue()

func _join_ticket_queue():
	if ParkPointsManager.instance:
		var park_manager = ParkPointsManager.instance
		var queue_position = park_manager.join_ticket_queue(npc.get_instance_id())
		
		if queue_position >= 0:
			print("[NPC] Rejoint la file d'attente à la position ", queue_position)
			_navigate_to_queue_position(queue_position)
		else:
			print("[NPC] File d'attente pleine, attente...")
			# Attendre qu'une place se libère
			await npc.get_tree().create_timer(1.0).timeout
			_join_ticket_queue()
	else:
		print("[NPC] ERREUR: ParkPointsManager introuvable!")


func _navigate_to_queue_position(position: int):
	if ParkPointsManager.instance:
		var park_manager = ParkPointsManager.instance
		var target_node = park_manager.get_ticket_queue_position(npc.get_instance_id())
		
		if target_node:
			# NOUVEAU : Debug complet de la position
			print("[NPC] === DEBUG POSITION ===")
			print("[NPC] Target Node: ", target_node.name)
			print("[NPC] Target global_position: ", target_node.global_position)
			print("[NPC] Target transform: ", target_node.transform)
			print("[NPC] Target scale: ", target_node.scale)
			print("[NPC] NPC current position: ", npc.global_position)
			print("[NPC] Distance: ", npc.global_position.distance_to(target_node.global_position))
			
			# NOUVEAU : Position exacte du point
			npc.agent.target_position = target_node.global_position
			print("[NPC] Agent target_position set to: ", npc.agent.target_position)
			print("[NPC] === END DEBUG ===")
		else:
			print("[NPC] ERREUR: Position de file introuvable!")

func _on_queue_position_changed(new_position: int):
	print("[NPC] Position dans la file changée vers: ", new_position)
	
	# NOUVEAU : Re-naviguer vers la nouvelle position
	_navigate_to_queue_position(new_position)			



func physics_process(delta: float) -> void:
	# Vérifier si le NPC est arrivé à sa position dans la file
	if npc.agent.is_navigation_finished():
		if ParkPointsManager.instance:
			var park_manager = ParkPointsManager.instance
			
			# NOUVEAU : Vérifier la distance exacte à la position cible
			var target_node = park_manager.get_ticket_queue_position(npc.get_instance_id())
			if target_node:
				# NOUVEAU : Calcul de distance HORIZONTALE uniquement (X et Z)
				var npc_pos = Vector3(npc.global_position.x, 0, npc.global_position.z)
				var target_pos = Vector3(target_node.global_position.x, 0, target_node.global_position.z)
				var distance_to_target = npc_pos.distance_to(target_pos)
				print("[NPC] Distance horizontale à la position cible: ", distance_to_target)
				
				# NOUVEAU : Seuil très strict (0.5m) pour être EXACTEMENT sur la position
				if distance_to_target < 0.5:
					# Vérifier si le NPC est en première position
					if park_manager.is_at_front_of_queue(npc.get_instance_id()):
						print("[NPC] En première position de la file, passage en attente de ticket")
						npc.npc_state_machine.change_state("waiting_for_ticket")
					else:
						print("[NPC] En attente dans la file...")
				# SUPPRIMER : Plus de re-navigation automatique
			else:
				print("[NPC] ERREUR: Position de file introuvable!")
