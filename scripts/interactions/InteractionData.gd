# res://scripts/interactions/InteractionData.gd
extends Resource
class_name InteractionData

## Configuration pour les interactions avec les objets
## Permet de définir le comportement visuel et les paramètres d'interaction

@export_group("UI Configuration")
## Le texte affiché à l'utilisateur pour cette interaction
@export var label: String = "Interagir"
## La touche d'action pour déclencher l'interaction
@export var action_key: String = "ui_accept"
## Icône optionnelle à afficher (chemin vers une texture)
@export var icon_path: String = ""

@export_group("Camera Animation")
## Si true, une animation de caméra sera déclenchée
@export var requires_camera_animation: bool = false
## Position relative de la caméra par rapport à l'objet
@export var camera_offset: Vector3 = Vector3(0, 1.5, 2.0)
## Durée de l'animation de caméra en secondes
@export var camera_duration: float = 0.8
## Point que la caméra doit regarder (relatif à l'objet)
@export var camera_look_at_offset: Vector3 = Vector3(0, 1.0, 0)

@export_group("Stencil Effects")
## Mode de stencil (0 = désactivé, 1 = activé)
@export var stencil_mode: int = 1
## Type d'effet stencil à appliquer
@export var stencil_type: StencilType = StencilType.OUTLINE
## Couleur de l'effet stencil
@export var stencil_color: Color = Color(1, 1, 0, 0.8)  # Jaune par défaut
## Intensité de l'effet stencil (0.0 = invisible, 1.0 = opaque)
@export var stencil_intensity: float = 1.0
## Épaisseur de l'outline
@export var stencil_outline_thickness: float = 0.01

## Types d'effets stencil disponibles
enum StencilType {
	NONE,        ## Pas d'effet stencil
	OUTLINE,     ## Contour avec stencil
	GLOW,        ## Effet de lueur avec stencil
	HIGHLIGHT,   ## Surbrillance simple
	CUSTOM       ## Effet personnalisé
}

@export_group("Interaction Behavior")
## Si true, l'interaction se déclenche automatiquement en s'approchant
@export var auto_trigger: bool = false
## Distance à laquelle l'interaction devient disponible
@export var interaction_distance: float = 3.0
## Si true, l'interaction peut être répétée
@export var repeatable: bool = true
## Si true, l'objet sera détruit après interaction
@export var consume_on_use: bool = false

@export_group("Audio")
## Son joué lors de l'interaction
@export var interaction_sound: AudioStream
## Volume du son d'interaction
@export var sound_volume: float = 1.0

## Types d'aura disponibles
enum AuraType {
	NONE,        ## Pas d'effet visuel
	OUTLINE,     ## Contour lumineux
	GLOW,        ## Effet de lueur
	PARTICLES,   ## Particules autour de l'objet
	CUSTOM       ## Effet personnalisé défini par l'objet
}

## Crée une configuration d'interaction simple
static func create_simple(label_text: String, action: String = "ui_accept") -> InteractionData:
	var data = InteractionData.new()
	data.label = label_text
	data.action_key = action
	return data

## Crée une configuration avec animation de caméra
static func create_with_camera(label_text: String, offset: Vector3, duration: float = 0.8) -> InteractionData:
	var data = create_simple(label_text)
	data.requires_camera_animation = true
	data.camera_offset = offset
	data.camera_duration = duration
	return data

## Valide la configuration
func is_valid() -> bool:
	return not label.is_empty() and not action_key.is_empty()

## Retourne les paramètres de caméra sous forme de dictionnaire (compatibilité)
func get_camera_travel_params() -> Dictionary:
	if not requires_camera_animation:
		return {}
	
	return {
		"offset": camera_offset,
		"duration": camera_duration,
		"look_at_offset": camera_look_at_offset
	}
