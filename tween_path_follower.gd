extends PathFollow3D
class_name TweenPathFollower

# Méthode avec Tween pour animation ultra-fluide
@export var duration: float = 60.0  # Durée en secondes pour parcourir tout le chemin
@export var auto_start: bool = true

var tween: Tween

func _ready():
	if auto_start:
		start_journey()

func start_journey():
	progress = 0.0
	tween = create_tween()
	tween.tween_property(self, "progress", 1.0, duration)
	tween.tween_callback(_on_journey_complete)

func _on_journey_complete():
	print("Voyage terminé !")
	# Optionnel : redémarrer ou supprimer
	# start_journey()  # Pour boucle infinie

func stop_journey():
	if tween:
		tween.kill()

func reset():
	stop_journey()
	start_journey()
