# scripts/npc_states/equipment_fitting_state.gd
class_name EquipmentFittingState
extends NPCState

var fitting_completed: bool = false
var fitting_quality: float = 0.0  # 0.0 = trop lâche, 1.0 = parfait, 2.0 = trop serré

func enter() -> void:
	print("[NPC] État: Installation de l'équipement")
	npc.current_context = "equipment_fitting"
	npc.speed = 0  # S'arrêter pour l'installation
	
	# Démarrer le minijeu d'installation
	_start_equipment_fitting()

func _start_equipment_fitting():
	# Ici, vous pouvez déclencher le minijeu d'installation
	# Pour l'instant, on simule avec un délai
	print("[NPC] Démarrage du minijeu d'installation du harnais")
	
	# Simuler le minijeu (à remplacer par le vrai minijeu)
	await npc.get_tree().create_timer(5.0).timeout
	_complete_fitting()

func _complete_fitting():
	fitting_completed = true
	print("[NPC] Installation du harnais terminée")
	
	# Passer à l'exploration du parc
	state_machine.change_state("exploring_park")

func physics_process(delta: float) -> void:
	# Dans cet état, le NPC attend la fin du minijeu
	pass
