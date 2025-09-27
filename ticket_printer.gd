extends Node3D

@export var print_duration: float = 1.0  # Durée de l'animation d'impression

func _create_ticket(ticket_data: Dictionary):
	var ticket_scene = preload("res://scenes/Ticket.tscn")
	var ticket = ticket_scene.instantiate() as Node3D

	self.get_parent().add_child(ticket)
	(ticket as Ticket).set_ticket_data(ticket_data.type_personne, ticket_data.duree, ticket_data.parcours)
	
	# Marquer le ticket comme en cours d'impression
	if ticket.has_method("set_printing_state"):
		ticket.set_printing_state(true)
	
	# Position de sortie du ticket
	var ticket_spawn_position: Vector3
	if self:
		ticket_spawn_position = self.global_position + Vector3(0, 0.2, 0)
	else:
		ticket_spawn_position = global_position + Vector3(0.3, 0.3, 0.4)
	
	ticket.global_position = ticket_spawn_position
	
	# Démarrer l'animation d'impression progressive
	_start_print_animation(ticket)
	
	print("🎫 Impression du ticket démarrée...")
	
	# Donner une petite impulsion au RigidBody du ticket pour qu'il "sorte" de l'ordinateur
	# Le ticket est maintenant un RigidBody3D directement
	#if ticket is RigidBody3D:
		#ticket.apply_impulse(Vector3(0.5, 1.0, 0.2), Vector3.ZERO)	
	#else:
		#push_error("🎫 ERREUR: Le ticket n'est pas un RigidBody3D!")


func _start_print_animation(ticket: Node3D):
	if not ticket:
		return
	
	# Animation d'impression progressive
	var start_scale = Vector3(0.1, 0.1, 0.1)  # Très petit au début
	var end_scale = Vector3.ONE  # Taille normale
	
	# Position initiale (dans l'imprimante)
	var start_pos = global_position + Vector3(0, -0.1, 0)
	var end_pos = global_position + Vector3(0, 0.2, 0)
	
	# Appliquer l'état initial
	ticket.scale = start_scale
	ticket.global_position = start_pos
	
	# Animation de l'échelle
	var tween_scale = create_tween()
	tween_scale.tween_property(ticket, "scale", end_scale, print_duration)
	tween_scale.set_ease(Tween.EASE_OUT)
	tween_scale.set_trans(Tween.TRANS_CUBIC)
	
	# Animation de la position (sortie progressive)
	var tween_pos = create_tween()
	tween_pos.tween_property(ticket, "global_position", end_pos, print_duration)
	tween_pos.set_ease(Tween.EASE_OUT)
	tween_pos.set_trans(Tween.TRANS_CUBIC)
	
	# Animation de l'opacité (si le matériau le supporte)
	if ticket.has_method("_animate_alpha"):
		ticket._animate_alpha(0.0, 1.0, print_duration)
	
	# Réactiver la physique à la fin de l'animation
	await tween_scale.finished
	
	# Marquer le ticket comme prêt à être ramassé
	if ticket.has_method("set_printing_state"):
		ticket.set_printing_state(false)
	
	# Donner une petite impulsion au RigidBody du ticket pour qu'il "sorte" de l'ordinateur
	#if ticket is RigidBody3D:
		#ticket.apply_impulse(Vector3(0.2, 0.5, 0.1), Vector3.ZERO)
	
	print("🎫 Impression terminée - ticket prêt à être ramassé!")
