# Dans Personnage_01.gd
extends NPC

func _ready():
	# Créer les données spécifiques à l'adulte masculin
	_create_masculine_adult_data()
	
	# Appeler le _ready() du parent après avoir défini les données
	super._ready()

func _create_masculine_adult_data():
	data = Personne.new()
	
	# Caractéristiques physiques réalistes pour adulte masculin
	data.taille = 1.70 + randf() * 0.20  # 1.70m à 1.90m
	data.poids = 65 + randf() * 35        # 65kg à 100kg
	
	# Couleurs de peau réalistes
	data.couleur_peau = _get_realistic_skin_color()
	
	# Couleurs de cheveux réalistes
	data.couleur_cheveux = _get_realistic_hair_color()
	
	# Vêtements masculins
	data.couleur_haut = _get_masculine_clothing_color()
	data.couleur_bas = _get_masculine_clothing_color()
	data.couleur_chaussures = _get_realistic_shoe_color()
	
	print("[Personnage_01] Adulte masculin créé - Taille: ", data.taille, "m, Poids: ", data.poids, "kg")

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
		Color(0.3, 0.15, 0.05)    # Châtain
	]
	return hair_colors[randi() % hair_colors.size()]

func _get_masculine_clothing_color() -> Color:
	var masculine_colors = [
		Color(0.2, 0.3, 0.8),     # Bleu
		Color(0.3, 0.3, 0.3),     # Gris foncé
		Color(0.1, 0.1, 0.1),     # Noir
		Color(0.4, 0.2, 0.1),     # Marron
		Color(0.2, 0.4, 0.2),     # Vert foncé
		Color(0.5, 0.3, 0.1)      # Cuir
	]
	return masculine_colors[randi() % masculine_colors.size()]

func _get_realistic_shoe_color() -> Color:
	var shoe_colors = [
		Color(0.1, 0.1, 0.1),     # Noir
		Color(0.3, 0.2, 0.1),     # Marron
		Color(0.4, 0.4, 0.4),     # Gris
		Color(0.6, 0.3, 0.1)      # Cuir
	]
	return shoe_colors[randi() % shoe_colors.size()]
