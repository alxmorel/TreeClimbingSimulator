# object_interactable.gd
extends Node3D
class_name ObjectInteractable

## Classe de base pour tous les objets interactables du jeu
## Définit l'interface standardisée pour les interactions

# Signaux standardisés
signal interaction_started(player: Node)
signal interaction_ended(player: Node)
signal interaction_failed(reason: String)

@export var interaction_data: InteractionData
@export var mesh_list : Array[MeshInstance3D]

func _ready():
	# Créer une configuration par défaut si aucune n'est définie
	if not interaction_data:
		interaction_data = InteractionData.create_simple(get_interaction_label())


func _update_object_interaction_detection(is_detected : bool):
	_change_stencil(is_detected)

	if(is_detected):
		# Afficher le label d'interraction
		if GlobalContext.ui_context:
			GlobalContext.ui_context.update_key_action("E")
			var label = self.get_interaction_label()
			if label != "" :
				GlobalContext.ui_context.update_content(label)
			else:
				GlobalContext.ui_context.update_content("Interagir")
		return
	

## Retourne la configuration d'interaction
func get_interaction_data() -> InteractionData:
	return interaction_data if interaction_data else InteractionData.create_simple(get_interaction_label())

## Retourne le texte que l'UI doit afficher pour cette interaction
## À surcharger dans les classes filles pour des labels dynamiques
func get_interaction_label() -> String:
	if interaction_data and not interaction_data.label.is_empty():
		return interaction_data.label
	return "Interagir"

## Vérifie si l'interaction est possible dans l'état actuel
func can_interact(player: Node = null) -> bool:
	var data = get_interaction_data()
	
	# Vérifier si l'objet peut être réutilisé
	if not data.repeatable and _has_been_used():
		return false
	
	# Les classes filles peuvent ajouter leurs propres conditions
	return _can_interact_custom(player)

## Méthode à surcharger pour des conditions d'interaction spécifiques
func _can_interact_custom(player: Node = null) -> bool:
	return true

## Vérifie si l'objet a déjà été utilisé (pour les objets non-répétables)
func _has_been_used() -> bool:
	# Par défaut, les objets peuvent toujours être utilisés
	# Les classes filles peuvent surcharger cette méthode
	return false

## Méthode principale d'interaction - point d'entrée standardisé
func trigger_interaction(player: Node = null) -> bool:
	if not can_interact(player):
		var reason = "Interaction non disponible"
		interaction_failed.emit(reason)
		return false
	
	# Émettre le signal de début
	interaction_started.emit(player)
	
	#Utiliser le système InteractionManager si disponible
	if player and player.has_method("get") and player.get("interaction_manager"):
		var interaction_manager = player.get("interaction_manager")
		if interaction_manager and interaction_manager.has_method("perform_interaction"):
			# Le InteractionManager gère automatiquement l'animation de caméra
			interaction_manager.current_interactable = self
			interaction_manager.perform_interaction()
			return true
	
	# Appeler la logique métier spécifique
	var success = object_interact()
	
	# Émettre le signal de fin
	interaction_ended.emit(player)
	
	# Gérer la consommation de l'objet
	var data = get_interaction_data()
	if data.consume_on_use and success:
		_consume_object()
	
	return success

## Méthode à surcharger - logique métier spécifique de l'interaction
func object_interact() -> bool:
	print("⚠️ object_interact() non implémentée pour: ", name)
	return false

## Marque l'objet comme consommé et le détruit
func _consume_object():
	# Jouer un effet de disparition si disponible
	_play_consume_effect()
	
	# Détruire l'objet après un délai pour permettre les effets
	var tween = create_tween()
	tween.tween_callback(queue_free).set_delay(0.1)

## Effet visuel lors de la consommation (à surcharger)
func _play_consume_effect():
	pass

## Retourne les paramètres de caméra (compatibilité avec l'ancien système)
func get_camera_travel_params() -> Dictionary:
	var data = get_interaction_data()
	var params = data.get_camera_travel_params()
	
	# Si pas d'animation de caméra, retourner un dictionnaire vide
	if params.is_empty():
		return {}
	
	# Convertir le format nouveau vers l'ancien format
	var result = {}
	result["offset"] = params.get("offset", Vector3.ZERO)
	result["duration"] = params.get("duration", 0.8)
	result["look_at"] = global_position + params.get("look_at_offset", Vector3(0, 1, 0))
	
	return result

## Méthodes utilitaires pour la configuration

## Définit une nouvelle configuration d'interaction
func set_interaction_config(label_text: String, action_key: String = "ui_accept", with_camera: bool = false):
	if with_camera:
		interaction_data = InteractionData.create_with_camera(label_text, Vector3(0, 1.5, 2.0))
	else:
		interaction_data = InteractionData.create_simple(label_text, action_key)

## Active/désactive l'animation de caméra
func set_camera_animation(enabled: bool, offset: Vector3 = Vector3(0, 1.5, 2.0), duration: float = 0.8):
	if not interaction_data:
		interaction_data = InteractionData.create_simple(get_interaction_label())
	
	interaction_data.requires_camera_animation = enabled
	interaction_data.camera_offset = offset
	interaction_data.camera_duration = duration



## Configure l'effet stencil
func set_stencil_config(type: InteractionData.StencilType, color: Color = Color.YELLOW, intensity: float = 1.0):
	if not interaction_data:
		interaction_data = InteractionData.create_simple(get_interaction_label())
	
	interaction_data.stencil_type = type
	interaction_data.stencil_color = color
	interaction_data.stencil_intensity = intensity

## Configure l'outline stencil
func set_stencil_outline(color: Color = Color.YELLOW, thickness: float = 0.01):
	if not interaction_data:
		interaction_data = InteractionData.create_simple(get_interaction_label())
	
	interaction_data.stencil_type = InteractionData.StencilType.OUTLINE
	interaction_data.stencil_color = color
	interaction_data.stencil_outline_thickness = thickness

## Configure l'effet de lueur
func set_stencil_glow(color: Color = Color.YELLOW, intensity: float = 1.0):
	if not interaction_data:
		interaction_data = InteractionData.create_simple(get_interaction_label())
	
	interaction_data.stencil_type = InteractionData.StencilType.GLOW
	interaction_data.stencil_color = color
	interaction_data.stencil_intensity = intensity


func _change_stencil(is_detected: bool):
	var data = get_interaction_data()
	
	# Si pas d'effet stencil configuré, ne rien faire
	if data.stencil_type == InteractionData.StencilType.NONE:
		return
	
	# Appliquer l'effet stencil sur tous les meshes
	for mesh in mesh_list:
		if not mesh or not mesh.get_active_material(0):
			continue
			
		var material = mesh.get_active_material(0)
		
		if is_detected:
			_apply_stencil_effect(material, data)
		else:
			_remove_stencil_effect(material)

## Applique l'effet stencil selon le type configuré
func _apply_stencil_effect(material: Material, data: InteractionData):
	match data.stencil_type:
		InteractionData.StencilType.OUTLINE:
			_apply_outline_stencil(material, data)
		InteractionData.StencilType.GLOW:
			_apply_glow_stencil(material, data)
		InteractionData.StencilType.HIGHLIGHT:
			_apply_highlight_stencil(material, data)
		InteractionData.StencilType.CUSTOM:
			_apply_custom_stencil(material, data)

## Effet de contour avec stencil
func _apply_outline_stencil(material: Material, data: InteractionData):
	material.set("stencil_mode", data.stencil_mode)
	material.set("stencil_color", data.stencil_color)
	material.set("stencil_outline_thickness", data.stencil_outline_thickness)

## Effet de lueur avec stencil
func _apply_glow_stencil(material: Material, data: InteractionData):
	material.set("stencil_mode", data.stencil_mode)
	material.set("stencil_color", data.stencil_color)
	material.set("emission", data.stencil_color * data.stencil_intensity)
	material.set("emission_enabled", true)

## Effet de surbrillance simple
func _apply_highlight_stencil(material: Material, data: InteractionData):
	material.set("stencil_mode", data.stencil_mode)
	material.set("stencil_color", data.stencil_color)
	# Augmenter légèrement la luminosité
	var current_color = material.get("albedo_color")
	material.set("albedo_color", current_color.lerp(Color.WHITE, 0.3))

## Effet personnalisé (à surcharger dans les classes filles)
func _apply_custom_stencil(material: Material, data: InteractionData):
	# Les classes filles peuvent surcharger cette méthode
	_apply_highlight_stencil(material, data)

## Retire l'effet stencil
func _remove_stencil_effect(material: Material):
	material.set("stencil_mode", 0)
	material.set("emission_enabled", false)
	# Restaurer la couleur originale si nécessaire
