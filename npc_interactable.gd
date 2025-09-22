# NPCInteractable.gd
extends Node3D
class_name NPCInteractable

@export var dialogue_context: String = "achat_billeterie"

func get_interaction_label() -> String:
	return "Parler"

func object_interact():
	# Récupère une ou plusieurs répliques dans ton dictionnaire global
	if GlobalContext.dialogues.has(dialogue_context):
		var lines = GlobalContext.dialogues[dialogue_context]
		var chosen = [lines[randi() % lines.size()]]  # ← une phrase aléatoire
		# ou lines si tu veux toutes les afficher
		GlobalContext.dialogue_ui.start_dialogue(chosen)

	# Faire tourner le NPC vers le joueur
	look_at(GlobalContext.player.global_transform.origin, Vector3.UP)
