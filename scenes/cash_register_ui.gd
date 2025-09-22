extends Control

var type_personne := ""
var duree := ""
var parcours := ""

func _ready():
	# Connexion des boutons "Tranche d'âge"
	$Panel/MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer/btn_enfant.pressed.connect(_on_type_pressed.bind("Enfant"))
	$Panel/MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer/btn_adulte.pressed.connect(_on_type_pressed.bind("Adulte"))
	$Panel/MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer/btn_senior.pressed.connect(_on_type_pressed.bind("Sénior"))

	# Connexion des boutons "Durée"
	$Panel/MarginContainer/VBoxContainer/VBoxContainer2/HBoxContainer/btn_mi_journee.pressed.connect(_on_duree_pressed.bind("1/2 Journée"))
	$Panel/MarginContainer/VBoxContainer/VBoxContainer2/HBoxContainer/btn_journee.pressed.connect(_on_duree_pressed.bind("Journée"))

	# Connexion des boutons "Formule"
	$Panel/MarginContainer/VBoxContainer/VBoxContainer3/HBoxContainer/btn_basic.pressed.connect(_on_parcours_pressed.bind("Basic"))
	$Panel/MarginContainer/VBoxContainer/VBoxContainer3/HBoxContainer/btn_sensation.pressed.connect(_on_parcours_pressed.bind("Sensation"))

	# Bouton impression ticket
	$btn_impression_ticket.pressed.connect(_on_impression_ticket_pressed)


func _on_type_pressed(value: String):
	type_personne = value
	print("Type sélectionné :", type_personne)

func _on_duree_pressed(value: String):
	duree = value
	print("Durée sélectionnée :", duree)

func _on_parcours_pressed(value: String):
	parcours = value
	print("Parcours sélectionné :", parcours)

func _on_impression_ticket_pressed():
	print("--- Impression du ticket ---")
	print("Âge :", type_personne)
	print("Durée :", duree)
	print("Formule :", parcours)
	print("---------------------------")
