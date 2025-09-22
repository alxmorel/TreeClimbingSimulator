extends Control
@onready var liste_avis = $Panel/ScrollContainer/MarginContainer/ListeAvisParc
var avis_scene = preload("res://scenes/avis.tscn")

@export var phone_visible = false

# Exemple de données
var avis_data = [
	{
		"nom": "Marie",
		"texte": "Une expérience formidable ! Merci à toute l’équipe pour son accueil chaleureux, son professionnalisme et sa convivialité.",
		"avatar": preload("res://assets/images/femme.png")
	},
	{
		"nom": "Jean",
		"texte": "Pas fou fou quand même.",
		"avatar": preload("res://assets/images/enfants.png")
	},
	{
		"nom": "Alex",
		"texte": "C'est un park d'akrobranche koi",
		"avatar": preload("res://assets/images/grands-parents.png")
	},
		{
		"nom": "Marie",
		"texte": "Une expérience formidable ! Merci à toute l’équipe pour son accueil chaleureux, son professionnalisme et sa convivialité.",
		"avatar": preload("res://assets/images/femme.png")
	},
	{
		"nom": "Jean",
		"texte": "Pas fou fou quand même.",
		"avatar": preload("res://assets/images/enfants.png")
	},
	{
		"nom": "Alex",
		"texte": "C'est un park d'akrobranche koi",
		"avatar": preload("res://assets/images/grands-parents.png")
	}
]

func _ready():
	populate_avis(avis_data)

func populate_avis(data_array):
	# Nettoyer la liste avant de repopuler
	for child in liste_avis.get_children():
		child.queue_free()
	
	for d in data_array:
		var avis_instance = avis_scene.instantiate()
		
		var hbox = avis_instance.get_node("VBoxContainer/HBoxContainer")
		var avatar = hbox.get_node("Panel/ImageProfile")
		var nom = hbox.get_node("Panel2/Nom")
		var texte = hbox.get_node("Panel2/Commentaire")
		var bouton = avis_instance.get_node("VBoxContainer/BtnRepondreAvis")

		avatar.texture = d["avatar"]
		nom.text = d["nom"]
		texte.text = d["texte"]
		bouton.text = "Répondre à " + d["nom"]

		liste_avis.add_child(avis_instance)
