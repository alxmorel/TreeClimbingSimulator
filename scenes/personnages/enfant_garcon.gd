# Dans Personnage_03.gd
extends NPC

func _ready():
	# Créer les données spécifiques à l'enfant
	_create_child_data()
	
	# Appeler le _ready() du parent après avoir défini les données
	super._ready()

func _create_child_data():
	data = Personne.new()
	
	# Caractéristiques physiques réalistes pour enfant
	data.taille = 1.10 + randf() * 0.30  # 1.10m à 1.40m (5-12 ans)
	data.poids = 20 + randf() * 25       # 20kg à 45kg
	
	data.tranche_age = "Enfant"
	
	# Couleurs de peau réalistes
	data.couleur_peau = _get_realistic_skin_color()
	
	# Couleurs de cheveux réalistes
	data.couleur_cheveux = _get_realistic_hair_color()
	
	# Vêtements colorés pour enfants
	data.couleur_haut = _get_child_clothing_color()
	data.couleur_bas = _get_child_clothing_color()
	data.couleur_chaussures = _get_child_shoe_color()
	
	print("[Personnage_03] Enfant créé - Taille: ", data.taille, "m, Poids: ", data.poids, "kg")

func _get_realistic_skin_color() -> Color:
	var skin_tones = [
		Color(0.96, 0.87, 0.70),  # Peau claire
		Color(0.85, 0.70, 0.50),  # Peau mate
		Color(0.70, 0.50, 0.30),  # Peau mate
		Color(0.60, 0.40, 0.25),  # Peau foncée
		Color(0.80, 0.60, 0.40)   # Peau mate
	]
	return skin_tones[randi() % skin_tones.size()]

func _get_realistic_hair_color() -> Color:
	var hair_colors = [
		Color(0.2, 0.1, 0.05),    # Noir
		Color(0.4, 0.25, 0.1),    # Brun foncé
		Color(0.6, 0.4, 0.2),     # Brun clair
		Color(0.8, 0.6, 0.3),     # Blond
		Color(0.3, 0.15, 0.05)    # Châtain
	]
	return hair_colors[randi() % hair_colors.size()]

func _get_child_clothing_color() -> Color:
	var child_colors = [
		Color(1.0, 0.2, 0.2),     # Rouge vif
		Color(0.2, 0.8, 0.2),     # Vert vif
		Color(0.2, 0.2, 1.0),     # Bleu vif
		Color(1.0, 0.8, 0.2),     # Jaune vif
		Color(1.0, 0.4, 0.2),     # Orange vif
		Color(0.8, 0.2, 1.0)      # Violet vif
	]
	return child_colors[randi() % child_colors.size()]

func _get_child_shoe_color() -> Color:
	var child_shoe_colors = [
		Color(1.0, 0.2, 0.2),     # Rouge vif
		Color(0.2, 0.8, 0.2),     # Vert vif
		Color(0.2, 0.2, 1.0),     # Bleu vif
		Color(1.0, 0.8, 0.2),     # Jaune vif
		Color(0.1, 0.1, 0.1),     # Noir
		Color(0.8, 0.8, 0.8)      # Blanc
	]
	return child_shoe_colors[randi() % child_shoe_colors.size()]
