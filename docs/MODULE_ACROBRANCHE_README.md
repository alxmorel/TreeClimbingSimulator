# Système de Placement de Modules d'Accrobranche

## Vue d'ensemble

Ce système permet de placer automatiquement des modules d'accrobranche sur les arbres existants dans la scène. Les modules se positionnent automatiquement à la base des arbres et s'orientent intelligemment vers les autres arbres alentour pour créer un parcours cohérent.

## Fonctionnalités

### 🎯 Placement Automatique sur Arbres
- **Détection automatique** : Le système détecte automatiquement tous les arbres dans la scène
- **Positionnement intelligent** : Les modules se placent à la base des arbres, au niveau du terrain
- **Suivi du terrain** : La hauteur s'ajuste automatiquement à l'élévation du terrain

### 🌳 Orientation Automatique
- **Analyse des connexions** : Le système analyse les arbres alentour pour déterminer la meilleure orientation
- **Optimisation des parcours** : L'orientation maximise le nombre de connexions potentielles avec d'autres arbres
- **Rotation manuelle** : Possibilité de faire pivoter manuellement le module avec la molette de la souris

### 🎮 Contrôles Utilisateur
- **Clic gauche** : Placer le module à la position actuelle
- **Déplacement de la souris** : Rotation automatique du module vers la direction de la souris
- **Échap** : Annuler le placement

## Utilisation

### 1. Accéder au Mode Builder
- Appuyer sur la touche de raccourci du mode builder
- L'interface de construction s'affiche

### 2. Sélectionner le Module
- Dans l'onglet "Modules", cliquer sur le module "Module Départ Rudimentaire" (🎯)
- Le ghost du module apparaît dans la scène

### 3. Placement Automatique
- **Déplacer la souris** : Le module se positionne automatiquement sur l'arbre le plus proche
- **Orientation automatique** : Le module s'oriente vers les autres arbres alentour
- **Validation visuelle** : 
  - 🟢 Vert : Placement valide
  - 🔴 Rouge : Placement invalide

### 4. Orientation Automatique
- Le module s'oriente automatiquement vers la direction de la souris
- L'orientation suit naturellement le mouvement de la souris

### 5. Confirmation du Placement
- Clic gauche pour placer définitivement le module
- Le module est ajouté à la scène avec un effet d'animation

## Configuration Technique

### Types d'Objets Supportés
Les modules d'accrobranche doivent avoir la propriété `"type": "tree_module"` dans leur définition :

```gdscript
{
    "name": "Module Départ Rudimentaire",
    "price": 150,
    "scene_path": "res://assets/models/module/départ_rudimentaire.glb",
    "icon": "🎯",
    "type": "tree_module"  # ← Cette propriété active le mode placement sur arbres
}
```

### Détection des Arbres
Le système détecte les arbres de plusieurs façons :
1. **Nom du fichier** : Contient "tree"
2. **Nom du nœud** : Contient "tree"
3. **Métadonnées** : Propriété `is_tree` définie
4. **Système Terrain3D** : Instances d'arbres dans le terrain

### Paramètres de Placement
- **Distance maximale de détection** : 20 unités
- **Distance de connexion** : 2-15 unités
- **Angle de cône de connexion** : 60° (cos(60°) = 0.5)
- **Hauteur de placement** : Terrain + 0.5 unités

## Dépannage

### Le Module ne se Place pas sur les Arbres
1. Vérifier que l'objet a `"type": "tree_module"`
2. Vérifier que des arbres sont présents dans la scène
3. Vérifier que les arbres ont des collisions activées
4. Utiliser le script de test (`test_tree_detection.gd`) pour diagnostiquer

### Détection d'Arbres Incorrecte
1. Vérifier la structure des nœuds dans la scène
2. S'assurer que les arbres Terrain3D sont correctement configurés
3. Vérifier les noms et chemins des fichiers de scène

### Performance
- La détection d'arbres est optimisée pour s'exécuter uniquement lors du déplacement de la souris
- Le système utilise un cache pour éviter les recalculs inutiles
- La grille dynamique se met à jour uniquement autour du ghost

## Extensions Futures

### Nouvelles Fonctionnalités Possibles
- **Prévisualisation des connexions** : Lignes visuelles montrant les connexions potentielles
- **Validation des parcours** : Vérification que le parcours est complet et logique
- **Types de modules** : Différents types avec des comportements de placement spécifiques
- **Système de contraintes** : Règles de placement plus sophistiquées

### Intégration avec d'Autres Systèmes
- **Système de progression** : Déblocage de nouveaux modules
- **Économie** : Coûts et revenus liés aux parcours
- **Physique** : Simulation des mouvements sur les parcours
- **IA** : Génération automatique de parcours optimaux
