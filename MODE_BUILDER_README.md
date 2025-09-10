# Mode Builder - Tree Climbing Simulator

## Vue d'ensemble
Le mode builder permet de placer des objets dans la scène en utilisant une vue top-down et une interface de boutique.

## Contrôles

### Activation/Désactivation
- **Touche B** : Basculer entre le mode jeu normal et le mode builder

### Mode Builder - Vue Drone
- **ZQSD** : Déplacer la caméra (mouvement avec inertie)
- **Shift** : Mode turbo (vitesse x2.5)
- **Molette souris** : Ajuster l'altitude (zoom vertical)
- **Clic gauche** : Placer l'objet sélectionné
- **Échap** : Annuler le placement en cours

**Note** : La vitesse de déplacement augmente avec l'altitude (logique drone/RTS)

## Interface

### Boutique d'objets
- **Panel en bas** : Affiche les objets disponibles
- **Boutons d'objets** : Chaque objet affiche son nom et son prix
- **Affichage argent** : Coin inférieur gauche

### Objets disponibles
1. **Arbre** - 50€
2. **Rocher** - 25€

## Système de placement

### Grille de placement
- **Grille visible** : En mode builder, une grille transparente structure le terrain
- **Accrochage automatique** : Les objets s'alignent parfaitement sur les cellules
- **Cellules colorées** :
  - 🟢 **Vert** : Cellule libre (placement autorisé)
  - 🔵 **Bleu** : Cellule occupée par un objet
  - 🔴 **Rouge** : Cellule bloquée (obstacle/limite)

### Ghost Preview
- L'objet devient transparent lors du placement
- **Vert** : Position valide (cellule libre)
- **Rouge** : Position invalide (cellule occupée/bloquée)
- **Placement précis** : Suit automatiquement la grille

### Validation
- Vérification de l'argent disponible
- État des cellules (libre/occupée/bloquée)
- Placement organisé et structuré

## Architecture technique

### Scripts principaux
- `builder_manager.gd` : Gestionnaire principal des modes
- `builder_camera.gd` : Contrôles de la caméra drone (ZQSD + inertie)
- `builder_shop.gd` : Interface de la boutique
- `placement_manager.gd` : Système de placement avec ghost preview

### Organisation des nœuds
```
main/
├── CharacterBody3D/ (joueur + caméra normale)
├── BuilderManager (script principal)
├── BuilderCamera (caméra top-down)
├── PlacementManager (gestion placement)
├── BuilderUI/
│   └── BuilderShop/ (interface boutique)
├── Terrain3D/
└── PlacedObjects/ (créé automatiquement)
```

## Utilisation

1. **Démarrer le jeu** en mode normal
2. **Appuyer sur B** pour activer le mode builder
3. **Cliquer sur un objet** dans la boutique
4. **Déplacer la souris** pour positionner l'objet
5. **Clic gauche** pour placer (si position valide et argent suffisant)
6. **Échap** pour annuler le placement
7. **B** pour revenir au mode jeu normal

## Fonctionnalités implémentées

✅ Toggle mode builder (touche B)
✅ Caméra drone avec contrôles ZQSD + inertie
✅ Vitesse adaptative selon altitude + mode turbo Shift
✅ Zoom altitude progressif avec molette
✅ Interface boutique avec boutons dynamiques
✅ Système de ghost preview avec placement sous curseur
✅ Feedback visuel (vert/rouge)
✅ Gestion de l'argent
✅ Validation des placements
✅ Système d'annulation
✅ Retour automatique au mode jeu
✅ **Système de grille structuré**
✅ **Affichage visuel de la grille transparente**
✅ **Accrochage automatique sur les cellules**
✅ **Feedback visuel des états de cellules**
✅ **Effet bouncy cartoonesque au spawn**
✅ **HUD complet avec gestion du temps et progression**
