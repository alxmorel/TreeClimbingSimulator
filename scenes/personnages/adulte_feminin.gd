# Dans Personnage_02.gd
extends NPC

func _ready():
	# Créer les données spécifiques à l'adulte féminin
	_create_feminine_adult_data()
	
	# Appeler le _ready() du parent après avoir défini les données
	super._ready()

func _create_feminine_adult_data():
	data = Personne.new()
	
	# Caractéristiques physiques réalistes pour adulte féminin
	data.taille = 1.55 + randf() * 0.20  # 1.55m à 1.75m
	data.poids = 45 + randf() * 30       # 45kg à 75kg
	
	data.tranche_age = "Adulte"
	
	# Couleurs de peau réalistes
	data.couleur_peau = _get_realistic_skin_color()
	
	# Couleurs de cheveux réalistes
	data.couleur_cheveux = _get_realistic_hair_color()
	
	# Vêtements féminins
	data.couleur_haut = _get_feminine_clothing_color()
	data.couleur_bas = _get_feminine_clothing_color()
	data.couleur_chaussures = _get_feminine_shoe_color()
	
	print("[Personnage_02] Adulte féminin créé - Taille: ", data.taille, "m, Poids: ", data.poids, "kg")

func _get_realistic_skin_color() -> Color:
	var skin_tones = [
		Color(0.96, 0.87, 0.70),  # Peau claire européenne
		Color(0.85, 0.70, 0.50),  # Peau mate méditerranéenne
		Color(0.70, 0.50, 0.30),  # Peau mate asiatique
		Color(0.60, 0.40, 0.25),  # Peau foncée africaine
		Color(0.80, 0.60, 0.40)   # Peau mate latino
	]
	return skin_tones[randi() % skin_tones.size()]

func _get_realistic_hair_color() -> Color:
	var hair_colors = [
		Color(0.2, 0.1, 0.05),    # Noir
		Color(0.4, 0.25, 0.1),    # Brun foncé
		Color(0.6, 0.4, 0.2),     # Brun clair
		Color(0.8, 0.6, 0.3),     # Blond
		Color(0.9, 0.7, 0.4),     # Blond clair
		Color(0.3, 0.15, 0.05)    # Châtain
	]
	return hair_colors[randi() % hair_colors.size()]

func _get_feminine_clothing_color() -> Color:
	var feminine_colors = [
		Color(0.8, 0.2, 0.6),     # Rose
		Color(0.2, 0.6, 0.8),     # Bleu clair
		Color(0.6, 0.8, 0.2),     # Vert clair
		Color(0.8, 0.6, 0.2),     # Jaune
		Color(0.9, 0.9, 0.9),     # Blanc
		Color(0.6, 0.3, 0.8),     # Violet
		Color(0.8, 0.4, 0.2),     # Orange
		Color(0.2, 0.3, 0.8),     # Bleu
		Color(0.8, 0.2, 0.2),     # Rouge
		Color(0.2, 0.8, 0.2)      # Vert
	]
	return feminine_colors[randi() % feminine_colors.size()]

func _get_feminine_shoe_color() -> Color:
	var feminine_shoe_colors = [
		Color(0.1, 0.1, 0.1),     # Noir
		Color(0.8, 0.2, 0.6),     # Rose
		Color(0.2, 0.6, 0.8),     # Bleu clair
		Color(0.6, 0.3, 0.8),     # Violet
		Color(0.8, 0.4, 0.2),     # Orange
		Color(0.9, 0.9, 0.9),     # Blanc
		Color(0.3, 0.2, 0.1),     # Marron
		Color(0.4, 0.4, 0.4)      # Gris
	]
	return feminine_shoe_colors[randi() % feminine_shoe_colors.size()]
