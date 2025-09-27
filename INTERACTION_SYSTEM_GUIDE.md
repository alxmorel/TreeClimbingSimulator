# Guide du Système d'Interaction Refactorisé

## Vue d'ensemble

Le nouveau système d'interaction est conçu pour être modulaire, extensible et facile à maintenir. Il sépare clairement les responsabilités :

- **InteractionData** : Configuration des interactions
- **ObjectInteractable** : Interface standardisée pour tous les objets interactables
- **InteractionManager** : Gestion centralisée des auras, UI et caméra
- **PlayerWithInteractionManager** : Script joueur nettoyé qui délègue à l'InteractionManager

## Architecture

```
Player
├── InteractionManager (gère auras, UI, caméra)
└── StateMachine (gère les états du joueur)

ObjectInteractable (classe de base)
├── InteractionData (configuration)
└── Objets spécifiques (billboard, ticket, ordinateur, etc.)
```

## Comment créer un nouvel objet interactable

### Méthode 1 : Configuration programmatique

```gdscript
# res://scripts/MyInteractable.gd
extends ObjectInteractable

func _ready():
    super._ready()
    
    # Configuration simple
    set_interaction_config("Mon action", "ui_accept", false)
    set_aura_config(InteractionData.AuraType.GLOW, Color.GREEN)

func object_interact() -> bool:
    print("Mon interaction personnalisée!")
    return true
```

### Méthode 2 : Configuration par ressource

1. Créer une ressource InteractionData dans l'éditeur
2. L'assigner à l'objet :

```gdscript
extends ObjectInteractable

@export var my_interaction_data: InteractionData

func _ready():
    super._ready()
    interaction_data = my_interaction_data

func object_interact() -> bool:
    # Logique spécifique
    return true
```

## Types d'aura disponibles

- `NONE` : Pas d'effet visuel
- `OUTLINE` : Contour lumineux
- `GLOW` : Effet de lueur
- `PARTICLES` : Particules autour de l'objet
- `CUSTOM` : Effet personnalisé

## Animation de caméra

Pour activer l'animation de caméra :

```gdscript
set_camera_animation(true, Vector3(0, 2, 3), 1.0) # position, durée
interaction_data.camera_look_at_offset = Vector3(0, 1, 0) # point de regard
```

## Signaux standardisés

Tous les objets interactables émettent :

```gdscript
signal interaction_started(player: Node)
signal interaction_ended(player: Node)
signal interaction_failed(reason: String)
```

Connectez-vous à ces signaux pour ajouter des effets sonores, visuels, etc.

## Migration des objets existants

### Avant
```gdscript
extends Node3D

func object_interact() -> void:
    print("Interaction")
```

### Après
```gdscript
extends ObjectInteractable

func _ready():
    super._ready()
    set_interaction_config("Mon label", "ui_accept")

func object_interact() -> bool:
    print("Interaction")
    return true
```

## Conditions d'interaction personnalisées

```gdscript
func _can_interact_custom(player: Node = null) -> bool:
    # Vos conditions spécifiques
    return player.has_key if player else false

func _has_been_used() -> bool:
    # Pour les objets non-répétables
    return my_used_flag
```

## Objets consommables

```gdscript
func _ready():
    super._ready()
    interaction_data = InteractionData.create_simple("Ramasser")
    interaction_data.consume_on_use = true

func _play_consume_effect():
    # Effet de disparition personnalisé
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
```

## Intégration avec le PlayerWithInteractionManager

Dans votre scène principale, remplacez le script du joueur par `PlayerWithInteractionManager.gd` :

```gdscript
# Dans la scène principale
@onready var player = $Player
@onready var ui_context = $UI

func _ready():
    # L'InteractionManager est automatiquement configuré
    # et connecté aux signaux du joueur
```

## Avantages du nouveau système

1. **Séparation des responsabilités** : Chaque classe a un rôle précis
2. **Extensibilité** : Facile d'ajouter de nouveaux types d'interactions
3. **Réutilisabilité** : Les configurations peuvent être sauvées comme ressources
4. **Maintenabilité** : Code plus organisé et modulaire
5. **Signaux standardisés** : Intégration facile d'effets globaux
6. **Configuration déclarative** : Moins de code, plus de données

## Exemple complet

Voir `examples/SimpleDoor.gd` pour un exemple complet d'implémentation d'une porte interactive avec animation, sons et logique métier.
