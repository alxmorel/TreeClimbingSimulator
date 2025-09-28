# scripts/ui/PlayerInventory.gd
extends Control
class_name PlayerInventory

@onready var slot_1: Panel = $HBoxContainer/Slot1/SlotPanel
@onready var slot_2: Panel = $HBoxContainer/Slot2/SlotPanel
@onready var slot_3: Panel = $HBoxContainer/Slot3/SlotPanel

# Signaux
signal item_added(item: Node, slot_index: int)
signal item_removed(item: Node, slot_index: int)
signal active_item_changed(item: Node, slot_index: int)

var icon_cache: Dictionary = {}

var inventory_slots: Array[Node] = []
var inventory_items: Array[Node] = []  # Les objets dans l'inventaire
var active_slot_index: int = 0  # Index de l'item actif (0-2)

var item_ui_position = Vector3(0.4, -0.5, -0.7) #Vector3(0.3, -0.4, -0.8)
var item_animating: bool = false
var item_start_transform: Transform3D
var item_target_transform: Transform3D
var item_animation_t: float = 0.0
var item_animation_duration: float = 1.0


func _ready():
	# Initialiser les slots
	inventory_slots = [slot_1, slot_2, slot_3]
	
	# Initialiser l'array des items
	inventory_items = [null, null, null]  # 3 slots vides
	
	# Configurer l'UI
	_setup_ui()
	
	# S'assurer que l'inventaire est visible
	visible = true

func _process(delta: float):
	# Mettre à jour l'animation de l'item
	_update_item_animation(delta)

func _setup_ui():
	# Configurer l'apparence des slots
	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		if slot:
			# AFFICHER les slots vides par défaut
			slot.visible = true
			slot.modulate = Color(0.3, 0.3, 0.3, 0.8)  # Gris foncé pour les slots vides
			
			# Créer seulement le TextureRect pour afficher les icônes
			_create_slot_texture_rect(slot)


func _create_slot_texture_rect(slot: Panel):
	# Créer un TextureRect pour afficher le rendu des icônes
	if not slot.has_node("SlotTextureRect"):
		var texture_rect = TextureRect.new()
		texture_rect.name = "SlotTextureRect"
		texture_rect.anchors_preset = Control.PRESET_FULL_RECT
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(texture_rect)


func add_item(item: Node) -> bool:
	# Vérifier que l'array est initialisé
	if inventory_items.is_empty():
		inventory_items = [null, null, null]
	
	# D'abord vérifier si le slot actif est libre
	if active_slot_index < inventory_items.size() and inventory_items[active_slot_index] == null:
		# Le slot actif est libre, y ajouter l'item
		inventory_items[active_slot_index] = item
		_update_slot_display(active_slot_index)
		item_added.emit(item, active_slot_index)
		
		# NOUVEAU : Attacher immédiatement à la caméra
		_attach_item_to_camera(item)
		
		print("🎒 Item ajouté au slot actif ", active_slot_index)
		return true
	
	# Sinon, chercher le premier slot libre
	for i in range(inventory_slots.size()):
		if i < inventory_items.size() and inventory_items[i] == null:
			# Ajouter l'item
			inventory_items[i] = item
			_update_slot_display(i)
			item_added.emit(item, i)
			
			# NOUVEAU : Si c'est le premier slot, le rendre actif ET l'attacher
			if i == 0:
				set_active_slot(0)
				_attach_item_to_camera(item)
			else:
				# Pour les autres slots, juste stocker dans l'inventaire
				# L'item reste détaché du monde mais n'est pas attaché à la caméra
				print("🎒 Item stocké dans l'inventaire, slot ", i)
			
			print("🎒 Item ajouté au premier slot libre ", i)
			return true
	
	print("🎒 Inventaire plein!")
	return false
	

func remove_item(slot_index: int) -> Node:
	if slot_index < 0 or slot_index >= inventory_slots.size():
		return null
	
	var item = inventory_items[slot_index]
	if item:
		inventory_items[slot_index] = null
		_update_slot_display(slot_index)
		item_removed.emit(item, slot_index)

		print("🎒 Item retiré de l'inventaire, slot ", slot_index)
	
	return item


func get_active_item() -> Node:
	if active_slot_index >= 0 and active_slot_index < inventory_items.size():
		return inventory_items[active_slot_index]
	return null


func set_active_slot(slot_index: int):
	if slot_index < 0 or slot_index >= inventory_slots.size():
		return
	
	# Désactiver l'ancien slot
	if active_slot_index >= 0 and active_slot_index < inventory_slots.size():
		var old_slot = inventory_slots[active_slot_index]
		if old_slot:
			# Retourner à la couleur normale ou vide
			if inventory_items[active_slot_index] != null:
				old_slot.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Item normal
			else:
				old_slot.modulate = Color(0.3, 0.3, 0.3, 0.8)  # Slot vide
	
	# Activer le nouveau slot
	active_slot_index = slot_index
	if active_slot_index < inventory_slots.size():
		var new_slot = inventory_slots[active_slot_index]
		if new_slot:
			# Mettre en évidence le slot actif
			new_slot.modulate = Color(0.876, 0.785, 0.731, 1.0)  # Marron pour l'actif
			
			# Ajouter une bordure ou un effet
			_add_active_slot_effect(new_slot)
	
	# NOUVEAU : Changer l'item actif sans drop
	var active_item = get_active_item()
	if active_item:
		# Détacher l'ancien item de la caméra
		_detach_current_item_from_camera()
		# Attacher le nouvel item à la caméra
		_attach_item_to_camera(active_item)
	
	# Émettre le signal
	active_item_changed.emit(active_item, active_slot_index)
	
	print("🎒 Slot actif changé: ", active_slot_index, " Item: ", active_item)
	

func _add_active_slot_effect(slot: Panel):
	# Ajouter un effet visuel pour le slot actif
	if not slot.has_node("ActiveEffect"):
		var effect = Panel.new()
		effect.name = "ActiveEffect"
		effect.modulate = Color(0.876, 0.785, 0.731, 0.3)  # Marron transparent
		slot.add_child(effect)
		effect.anchors_preset = Control.PRESET_FULL_RECT
		effect.position = Vector2.ZERO
		effect.size = slot.size

func _update_item_forward_position() -> void:
	# Met à jour la position de l'item pour qu'il reste toujours devant le joueur
	var player = GlobalContext.player
	if not player:
		return
	
	# Vérifier s'il y a un item attaché à la caméra
	for child in player.camera.get_children():
		if child is Ticket or child is Harnais:
			# L'item doit toujours être au centre de l'écran, dans la direction "avant" de la caméra
			# Position locale dans l'espace de la caméra : devant (Z négatif)
			var item_basis = Basis()
			item_basis = item_basis.rotated(Vector3.UP, deg_to_rad(15))  # Légère rotation sur Y
			item_basis = item_basis.rotated(Vector3.RIGHT, deg_to_rad(-10))  # Légère inclinaison
			
			# Position fixe au centre de l'écran (devant la caméra) - forcer la mise à jour
			child.transform = Transform3D(item_basis, item_ui_position)
			break

func scroll_to_next_item():
	var next_slot = (active_slot_index + 1) % inventory_slots.size()
	set_active_slot(next_slot)

func scroll_to_previous_item():
	var prev_slot = (active_slot_index - 1 + inventory_slots.size()) % inventory_slots.size()
	set_active_slot(prev_slot)

func _find_next_active_item():
	# Trouver le prochain item disponible
	for i in range(inventory_slots.size()):
		var slot_index = (active_slot_index + i) % inventory_slots.size()
		if inventory_items[slot_index] != null:
			set_active_slot(slot_index)
			return
	
	# Aucun item trouvé
	set_active_slot(0)

func _update_slot_display(slot_index: int):
	if slot_index < 0 or slot_index >= inventory_slots.size():
		return
	
	var slot = inventory_slots[slot_index]
	var item = inventory_items[slot_index]
	
	if item:
		# Afficher l'item
		slot.visible = true
		slot.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Couleur normale
		
		# NOUVEAU : Si c'est le slot actif, le mettre en évidence
		if slot_index == active_slot_index:
			slot.modulate = Color(0.876, 0.785, 0.731, 1.0)  # Jaune pour l'actif
			_add_active_slot_effect(slot)
		
		# Masquer l'indicateur vide
		if slot.has_node("EmptyIndicator"):
			slot.get_node("EmptyIndicator").visible = false
		
		# Ajouter ou mettre à jour le SubViewport
		_add_item_viewport_to_slot(slot, item)
		
		# Ajouter le nom de l'item
		if slot.has_node("ItemLabel"):
			slot.get_node("ItemLabel").text = _get_item_name(item)
	else:
		# Slot vide
		slot.modulate = Color(0.3, 0.3, 0.3, 0.8)  # Gris foncé
		
		# Afficher l'indicateur vide
		if slot.has_node("EmptyIndicator"):
			slot.get_node("EmptyIndicator").visible = true
		
		# Supprimer le SubViewport s'il existe
		_remove_item_viewport_from_slot(slot)
		

func _add_item_viewport_to_slot(slot: Panel, item: Node):
	print("🎯 Ajout viewport pour item: ", item.name)
	
	# Nettoyer le contenu existant
	_clear_slot_viewport(slot)
	
	# Charger la scène d'icône appropriée
	var icon_scene: PackedScene
	if item is Ticket:
		icon_scene = preload("res://scenes/ui/ticket_icon.tscn")
	elif item is Harnais:
		icon_scene = preload("res://scenes/ui/harnais_icon.tscn")
	else:
		print("❌ Type d'item non supporté: ", item.get_class())
		return
	
	# Instancier la scène d'icône directement dans le slot
	var icon_instance = icon_scene.instantiate()
	icon_instance.name = "ItemIcon"
	slot.add_child(icon_instance)
	
	# Récupérer le SubViewport de la scène d'icône et connecter au TextureRect
	var texture_rect = slot.get_node("SlotTextureRect")
	
	if icon_instance and texture_rect:
		texture_rect.texture = icon_instance.get_texture()
		print("✅ Scène d'icône ajoutée avec SubViewport connecté au TextureRect")
	else:
		print("❌ SubViewport ou TextureRect non trouvé")


func _clear_slot_viewport(slot: Panel):
	# Supprimer l'instance d'icône s'il existe
	if slot.has_node("ItemIcon"):
		slot.get_node("ItemIcon").queue_free()
	
	# Vider la texture du TextureRect
	var texture_rect = slot.get_node("SlotTextureRect")
	if texture_rect:
		texture_rect.texture = null
		

func _remove_item_viewport_from_slot(slot: Panel):
	# Nettoyer le slot
	_clear_slot_viewport(slot)


func _get_item_name(item: Node) -> String:
	# Retourner le nom de l'item
	if item.has_method("get_display_name"):
		return item.get_display_name()
	
	# Noms par défaut
	if item is Ticket:
		return "Ticket"
	elif item is Harnais:
		return "Harnais"
	
	return "Item"

func get_item_count() -> int:
	var count = 0
	for item in inventory_items:
		if item != null:
			count += 1
	return count

func is_full() -> bool:
	return get_item_count() >= inventory_slots.size()

func is_empty() -> bool:
	return get_item_count() == 0
	
func _attach_item_to_camera(item: Node):
	# Attacher l'item à la caméra selon son type
	if item is Ticket:
		_attach_ticket_to_camera(item)
	elif item is Harnais:
		_attach_harnais_to_camera(item)
	# Ajouter d'autres types d'items ici si nécessaire

	
func _attach_ticket_to_camera(ticket: Node):
	if not ticket:
		return
	
	# NOUVEAU : Vérifier que l'item est dans l'arbre
	if not ticket.is_inside_tree():
		print("🎒 Item pas encore dans l'arbre, attente...")
		await get_tree().process_frame
		if not ticket.is_inside_tree():
			print("🎒 ERREUR: Item toujours pas dans l'arbre!")
			return
	
	# Attacher le ticket à la caméra pour l'affichage
	var player = GlobalContext.player
	if not player:
		return
	
	# 1. DÉSACTIVER COMPLÈTEMENT LA PHYSIQUE avant d'attacher
	ticket.set_freeze_mode(RigidBody3D.FREEZE_MODE_KINEMATIC)
	ticket.freeze = true
	ticket.gravity_scale = 0
	ticket.lock_rotation = true
	
	# 2. Sauvegarder la position mondiale AVANT de détacher
	var world_position = ticket.global_position
	var world_rotation = ticket.global_rotation
	var world_scale = ticket.scale
	
	# 3. Détacher du monde
	if ticket.get_parent():
		ticket.get_parent().remove_child(ticket)
	
	# 4. Attacher à la caméra
	player.camera.add_child(ticket)
	
	# 5. Repositionner le ticket à sa position mondiale dans l'espace de la caméra
	ticket.global_position = world_position
	ticket.global_rotation = world_rotation
	ticket.scale = world_scale
	
	# 6. NOUVEAU : Calculer une nouvelle position de départ pour l'animation
	var camera_position = player.camera.global_position
	var camera_forward = -player.camera.global_transform.basis.z
	var camera_right = player.camera.global_transform.basis.x
	var camera_up = player.camera.global_transform.basis.y
	
	# Position de départ : légèrement à droite et en bas de la caméra
	var start_position = camera_position + camera_right * 0.5 + camera_up * -0.2 + camera_forward * 0.3
	
	# Convertir en position locale dans la caméra
	var local_start_position = player.camera.to_local(start_position)
	
	# 7. Position de départ pour l'animation (position locale dans la caméra)
	item_start_transform = Transform3D(Basis(), local_start_position)
	
	# 8. Position cible finale (centre de l'écran dans l'espace de la caméra)
	var ticket_basis = Basis()
	ticket_basis = ticket_basis.rotated(Vector3.UP, deg_to_rad(15))  # Légère rotation sur Y
	ticket_basis = ticket_basis.rotated(Vector3.RIGHT, deg_to_rad(-10))  # Légère inclinaison
	item_target_transform = Transform3D(ticket_basis, item_ui_position)
	
	# 9. Démarrer l'animation
	item_animating = true
	item_animation_t = 0.0
	
	print("🎫 Ticket attaché à la caméra!")
	

func _attach_harnais_to_camera(harnais: Node):
	# Attacher le harnais à la caméra pour l'affichage
	var player = GlobalContext.player
	if not player:
		return
	
	# 1. DÉSACTIVER COMPLÈTEMENT LA PHYSIQUE avant d'attacher
	harnais.set_freeze_mode(RigidBody3D.FREEZE_MODE_KINEMATIC)
	harnais.freeze = true
	harnais.gravity_scale = 0
	harnais.lock_rotation = true
	
	# 2. Sauvegarder la position mondiale AVANT de détacher
	var world_position = harnais.global_position
	var world_rotation = harnais.global_rotation
	var world_scale = harnais.scale
	
	# 3. Détacher du monde
	if harnais.get_parent():
		harnais.get_parent().remove_child(harnais)
	
	# 4. Attacher à la caméra
	player.camera.add_child(harnais)
	
	# 5. Repositionner le harnais à sa position mondiale dans l'espace de la caméra
	harnais.global_position = world_position
	harnais.global_rotation = world_rotation
	harnais.scale = world_scale
	
	# 6. NOUVEAU : Calculer une nouvelle position de départ pour l'animation
	var camera_position = player.camera.global_position
	var camera_forward = -player.camera.global_transform.basis.z
	var camera_right = player.camera.global_transform.basis.x
	var camera_up = player.camera.global_transform.basis.y
	
	# Position de départ : légèrement à droite et en bas de la caméra
	var start_position = camera_position + camera_right * 0.5 + camera_up * -0.2 + camera_forward * 0.3
	
	# Convertir en position locale dans la caméra
	var local_start_position = player.camera.to_local(start_position)
	
	# 7. Position de départ pour l'animation (position locale dans la caméra)
	item_start_transform = Transform3D(Basis(), local_start_position)
	
	# 8. Position cible finale (centre de l'écran dans l'espace de la caméra)
	var harnais_basis = Basis()
	harnais_basis = harnais_basis.rotated(Vector3.UP, deg_to_rad(15))  # Légère rotation sur Y
	harnais_basis = harnais_basis.rotated(Vector3.RIGHT, deg_to_rad(-10))  # Légère inclinaison
	item_target_transform = Transform3D(harnais_basis, item_ui_position)
	
	# 9. Démarrer l'animation
	item_animating = true
	item_animation_t = 0.0
	
	print("🎒 Harnais attaché à la caméra!")


func _detach_item_from_camera(item: Node):
	# Détacher l'item de la caméra SANS le remettre dans le monde
	if not item:
		return
	
	var player = GlobalContext.player
	if not player:
		return
	
	# Détacher de la caméra
	if item.get_parent() == player.camera:
		player.camera.remove_child(item)
	
	print("🎒 Item détaché de la caméra (changement d'item): ", item.name)


func _drop_item_from_camera(item: Node):
	print("🔍 DEBUG: Tentative de drop de l'item: ", item.name)
	
	var player = GlobalContext.player
	if not player:
		return
	
	# NOUVEAU : Utiliser la position de la caméra + offset fixe
	var camera_position = player.camera.global_position
	var camera_forward = -player.camera.global_transform.basis.z  # Direction avant
	var camera_right = player.camera.global_transform.basis.x     # Direction droite
	var camera_up = player.camera.global_transform.basis.y        # Direction haut
	
	# Position de drop : devant la caméra
	var drop_position = camera_position + camera_forward * 0.8 + camera_up * -0.3
	
	print("🔍 DEBUG: Position caméra: ", camera_position)
	print("🔍 DEBUG: Position de drop calculée: ", drop_position)
	
	# Détacher de la caméra
	if item.get_parent() == player.camera:
		player.camera.remove_child(item)
	
	# Remettre dans le monde
	get_tree().current_scene.add_child(item)
	
	# Repositionner l'item à sa position de drop
	item.global_position = drop_position
	item.global_rotation = player.camera.global_rotation
	item.scale = Vector3.ONE  # Reset de l'échelle
	
	# RÉACTIVER LA PHYSIQUE COMPLÈTEMENT
	item.freeze = false
	item.set_freeze_mode(RigidBody3D.FREEZE_MODE_KINEMATIC)
	item.gravity_scale = 1.0
	item.lock_rotation = false
	
	print("🔍 DEBUG: Item position finale: ", item.global_position)
	print("🎒 Item drop dans le monde: ", item.name)


func _on_active_item_changed(item: Node, slot_index: int):
	print("🔍 DEBUG: _on_active_item_changed appelé avec item: ", item, " slot: ", slot_index)
	
	# Détacher l'ancien item de la caméra (SANS le remettre dans le monde)
	_detach_current_item_from_camera()
	
	# Attacher le nouvel item à la caméra
	if item:
		print("🎒 Item actif changé: ", item.name, " Slot: ", slot_index)
		_attach_item_to_camera(item)
	else:
		print("🎒 Aucun item actif")
		
		

func _detach_current_item_from_camera():
	# Détacher l'item actuel de la caméra (SANS le remettre dans le monde)
	var player = GlobalContext.player
	if not player:
		return
	
	# Vérifier s'il y a un item attaché à la caméra
	for child in player.camera.get_children():
		if child is Ticket or child is Harnais:
			_detach_item_from_camera(child)  # Utiliser la nouvelle fonction
			break
			
			
func _update_item_animation(delta: float):
	# Gestion de l'animation de l'item
	if item_animating:
		item_animation_t += delta / item_animation_duration
		item_animation_t = clamp(item_animation_t, 0, 1)
		
		# Trouver l'item attaché à la caméra
		var player = GlobalContext.player
		if not player:
			return
		
		var attached_item = null
		for child in player.camera.get_children():
			if child is Ticket or child is Harnais:
				attached_item = child
				break
		
		if attached_item:
			# Animation fluide vers la position cible (utilisation des transforms locaux)
			var eased_t = ease_out_cubic(item_animation_t)
			attached_item.transform = item_start_transform.interpolate_with(item_target_transform, eased_t)
			
			if item_animation_t >= 1.0:
				item_animating = false
				# Animation terminée - l'item est déjà attaché à la caméra
				print("🎫 Animation terminée - item au centre de l'écran et suit parfaitement la caméra")
	
	# Mise à jour continue pour que l'item reste toujours devant le joueur
	if not item_animating:
		_update_item_forward_position()
		
		
func ease_out_cubic(t: float) -> float:
	var f = t - 1.0
	return f * f * f + 1.0
