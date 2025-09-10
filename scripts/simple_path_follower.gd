extends PathFollow3D
class_name SimplePathFollower

# Méthode professionnelle avec PathFollow3D
# Beaucoup plus simple et fiable que VehicleBody3D

@export var speed: float = 1.39  # 5 km/h
@export var auto_start: bool = true

func _ready():
	if auto_start:
		start_moving()

func _physics_process(delta):
	if progress_ratio < 1.0:
		# Avancer le long du chemin
		progress += speed * delta
	else:
		# Arrivé à la fin
		stop_moving()

func start_moving():
	set_physics_process(true)

func stop_moving():
	set_physics_process(false)
	print("Véhicule arrivé à destination")

# Fonction pour redémarrer
func reset():
	progress = 0.0
	start_moving()
