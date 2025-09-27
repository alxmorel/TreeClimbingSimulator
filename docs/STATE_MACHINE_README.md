# State Machine pour Character Controller

## Vue d'ensemble

Le système de State Machine a été implémenté pour remplacer la logique conditionnelle complexe dans `character_body_3d.gd`. Cette approche offre une meilleure séparation des préoccupations et une maintenance plus facile.

## Structure

### StateMachine (`scripts/state_machine.gd`)
- Classe principale qui gère les transitions entre états
- Stocke les références vers tous les états disponibles
- Délègue les appels `physics_process()` et `handle_input()` à l'état actuel

### State (`scripts/states/base_state.gd`)
- Classe de base abstraite pour tous les états
- Définit l'interface commune : `enter()`, `exit()`, `physics_process()`, `handle_input()`
- Fournit des méthodes utilitaires communes (gravité, mouvement, head bob, etc.)

## États disponibles

### NormalState (`scripts/states/normal_state.gd`)
- Gère le mouvement standard du joueur
- Inclut : gravité, saut, mouvement horizontal, head bob, FOV, interactions

### LadderState (`scripts/states/ladder_state.gd`)
- Gère le comportement sur les échelles
- Inclut : mouvement vertical selon la caméra, collage à l'échelle, vitesses variables

### ZiplineState (`scripts/states/zipline_state.gd`)
- Gère le comportement sur la tyrolienne
- Inclut : positionnement le long du câble, vitesse progressive, conditions de sortie

### OrdinateurState (`scripts/states/ordinateur_state.gd`)
- Gère l'interaction avec l'ordinateur
- Inclut : blocage du mouvement, gestion des clics, projection de la souris

## Utilisation

### Ajout d'un nouvel état

1. Créer une nouvelle classe héritant de `State`
2. Implémenter les méthodes `enter()`, `exit()`, `physics_process()`, `handle_input()`
3. Ajouter l'état dans `_setup_state_machine()` du character controller

### Changement d'état

```gdscript
# Depuis le character controller
state_machine.change_state("nom_de_l_etat")

# Depuis un état
state_machine.change_state("autre_etat")
```

### Accès aux propriétés du joueur

Depuis un état, vous pouvez accéder au joueur via `player` :
```gdscript
player.velocity = Vector3.ZERO
player.camera.fov = 90.0
player._check_interaction()
```

## Avantages

1. **Séparation claire** : Chaque état gère sa propre logique
2. **Maintenance facilitée** : Modifications isolées par état
3. **Extensibilité** : Ajout facile de nouveaux états
4. **Lisibilité** : Plus de gros `if/elif` dans `_physics_process`
5. **Réutilisabilité** : Méthodes communes dans la classe de base

## Migration depuis l'ancien système

L'ancienne énumération `State` et les conditions `current_state == State.XXX` ont été remplacées par la State Machine. Les transitions se font maintenant via `state_machine.change_state("nom")`.

### Remplacement des anciennes vérifications d'état

```gdscript
# AVANT
if player.current_state == player.State.ORDINATEUR:
    return "Quitter l'ordinateur"

# APRÈS
if player.is_in_ordinateur_state():
    return "Quitter l'ordinateur"
```

### Méthodes de vérification d'état disponibles

- `player.is_in_normal_state()` - État normal de mouvement
- `player.is_in_ladder_state()` - État d'échelle
- `player.is_in_zipline_state()` - État de tyrolienne
- `player.is_in_ordinateur_state()` - État d'ordinateur
- `player.get_current_state_name()` - Retourne le nom de l'état actuel

### Changements d'état depuis des objets externes

```gdscript
# AVANT
player.current_state = player.State.ORDINATEUR

# APRÈS
player.change_to_ordinateur_state()
```

Méthodes disponibles :
- `player.change_to_normal_state()`
- `player.change_to_ladder_state()`
- `player.change_to_zipline_state()`
- `player.change_to_ordinateur_state()`
