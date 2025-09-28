extends Resource
class_name Personne

# --- Caractéristiques physiques ---
@export var prenom: String = "Alexandre"
@export var nom: String = "Morel"

@export var taille: float = 1.75       # en mètres
@export var poids: float = 70.0        # kg
@export var couleur_peau: Color = Color(1, 0.8, 0.6)
@export var couleur_cheveux: Color = Color(0.1, 0.1, 0.1)
@export var sexe: String = "Indetermine"  # Homme/Femme/Indetermine
@export var tranche_age: String = "Adulte"  # Enfant/Adulte/Senior

# --- Style vestimentaire ---
@export var couleur_haut: Color = Color(0.2, 0.5, 0.8)
@export var couleur_bas: Color = Color(0.1, 0.1, 0.1)
@export var couleur_chaussures: Color = Color(0.1, 0.1, 0.1)
@export var accessoire: Array = []  # lunettes, chapeau, sac...

@export var niveau_energie: String = "medium"  # "low", "medium", "high"
@export var preferences_activites: Array[String] = []  # Préférences personnalisées
@export var budget: String = "medium"  # "low", "medium", "high"
@export var groupe: String = "solo"  # "solo", "couple", "famille", "groupe"
