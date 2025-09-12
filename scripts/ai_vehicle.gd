extends VehicleBody3D
class_name AIVehicle

@export var target_path: Path3D
@export var max_speed: float = 10.0
@export var acceleration_force: float = 1200.0
@export var brake_force: float = 3000.0
@export var wheel_base: float = 5
@export var look_ahead_distance: float = 1.0  # distance devant la voiture

var has_finished: bool = false
var curve_offset: float = 0.0  # position actuelle sur la courbe

func _ready():
	if not target_path:
		target_path = get_tree().current_scene.find_child("Path3D", true, false)
	if not target_path:
		push_error("Aucun Path3D assigné !")
		return

	if not target_path.curve:
		push_error("Path3D sans courbe !")
		return

	# Position initiale sur la courbe
	curve_offset = target_path.curve.get_closest_offset(global_position)
	global_position = target_path.curve.sample_baked(curve_offset)

func _physics_process(delta):
	if not target_path or not target_path.curve or has_finished:
		return

	var curve = target_path.curve
	var path_length = curve.get_baked_length()

	# --- Trouver le point cible en avance sur la courbe ---
	curve_offset = curve.get_closest_offset(global_position)
	var target_offset = min(curve_offset + look_ahead_distance, path_length)
	var target = curve.sample_baked(target_offset)

	# --- Fin du chemin ---
	if curve_offset >= path_length - 0.1:
		_stop_vehicle()
		return

	# --- Orientation (Pure Pursuit) ---
	var local_target = to_local(target)
	var error = local_target.x
	var max_steer = 0.6
	var steering_angle = atan2(2 * wheel_base * error, look_ahead_distance ** 2)
	steering = lerp(steering, clamp(steering_angle, -max_steer, max_steer), delta * 5.0)

	# --- Gestion de la vitesse ---
	var speed = linear_velocity.length()
	if abs(error) > 0.5:  # virage serré, ralentir
		engine_force = 0.5 * acceleration_force
		brake = brake_force * 0.1
	elif speed < max_speed:
		engine_force = acceleration_force
		brake = 0
	else:
		engine_force = 0
		brake = brake_force * 0.05

func _stop_vehicle():
	engine_force = 0
	brake = brake_force
	steering = 0
	has_finished = true
