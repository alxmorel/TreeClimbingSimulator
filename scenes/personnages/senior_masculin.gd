# Dans Personnage_05.gd
extends NPC

func _ready():
	# Créer les données spécifiques au sénior
	_create_senior_data()
	
	# Appeler le _ready() du parent après avoir défini les données
	super._ready()

func _create_senior_data():
	data = Personne.new()
	
	# Caractéristiques physiques réalistes pour sénior
	data.taille = 1.60 + randf() * 0.15  # 1.60m à 1.75m (peut être plus petit avec l'âge)
	data.poids = 55 + randf() * 25       # 55kg à 80kg
	
	data.tranche_age = "Senior"
	
	# Couleurs de peau réalistes (peut être plus pâle)
	data.couleur_peau = _get_senior_skin_color()
	
	# Couleurs de cheveux réalistes (plus gris/blanc)
	data.couleur_cheveux = _get_senior_hair_color()
	
	# Vêtements plus sobres
	data.couleur_haut = _get_senior_clothing_color()
	data.couleur_bas = _get_senior_clothing_color()
	data.couleur_chaussures = _get_senior_shoe_color()
	
	print("[Personnage_05] Sénior créé - Taille: ", data.taille, "m, Poids: ", data.poids, "kg")

func _get_senior_skin_color() -> Color:
	var senior_skin_tones = [
		Color(0.95, 0.85, 0.70),  # Peau claire (plus pâle)
		Color(0.80, 0.65, 0.45),  # Peau mate
		Color(0.65, 0.45, 0.30),  # Peau mate
		Color(0.60, 0.40, 0.25),  # Peau foncée
		Color(0.75, 0.55, 0.35)   # Peau mate
	]
	return senior_skin_tones[randi() % senior_skin_tones.size()]

func _get_senior_hair_color() -> Color:
	var senior_hair_colors = [
		Color(0.8, 0.8, 0.8),     # Gris/blanc
		Color(0.6, 0.6, 0.6),     # Gris foncé
		Color(0.4, 0.4, 0.4),     # Gris très foncé
		Color(0.2, 0.1, 0.05),    # Noir (peu probable)
		Color(0.3, 0.15, 0.05)    # Châtain (peu probable)
	]
	return senior_hair_colors[randi() % senior_hair_colors.size()]

func _get_senior_clothing_color() -> Color:
	var senior_colors = [
		Color(0.3, 0.3, 0.3),     # Gris foncé
		Color(0.1, 0.1, 0.1),     # Noir
		Color(0.2, 0.3, 0.8),     # Bleu foncé
		Color(0.4, 0.2, 0.1),     # Marron
		Color(0.2, 0.4, 0.2),     # Vert foncé
		Color(0.5, 0.5, 0.5)      # Gris
	]
	return senior_colors[randi() % senior_colors.size()]

func _get_senior_shoe_color() -> Color:
	var senior_shoe_colors = [
		Color(0.1, 0.1, 0.1),     # Noir
		Color(0.3, 0.2, 0.1),     # Marron
		Color(0.4, 0.4, 0.4),     # Gris
		Color(0.6, 0.3, 0.1)      # Cuir
	]
	return senior_shoe_colors[randi() % senior_shoe_colors.size()]
