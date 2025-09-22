extends VehicleBody3D
class_name AIVehicle

@export var target_path: Path3D
@export var max_speed: float = 15.0
@export var acceleration_force: float = 1200.0
@export var brake_force: float = 150.0
@export var personne_scene: PackedScene

var has_finished: bool = false
var curve_offset: float = 0.0

func _ready():
	if not target_path:
		target_path = get_tree().current_scene.find_child("RouteParc_rapide", true, false)
	if not target_path:
		push_error("Aucun Path3D assigné !")
		return
	if not target_path.curve:
		push_error("RouteParc_rapide sans courbe !")
		return

	curve_offset = target_path.curve.get_closest_offset(global_position)
	global_position = target_path.curve.sample_baked(curve_offset)
	print("[READY] Position initiale =", global_position, " offset =", curve_offset)

func _physics_process(delta):
	if not target_path or not target_path.curve or has_finished:
		return

	var curve = target_path.curve
	var path_length = curve.get_baked_length()
	var speed = linear_velocity.length()

	curve_offset = curve.get_closest_offset(global_position)
	var target = curve.sample_baked(curve_offset)
	var target_xz = Vector3(target.x, global_position.y, target.z)
	var dir_to_target = target_xz - global_position

	var forward = -transform.basis.z
	var lateral_error = forward.cross(dir_to_target).y
	var max_steer = 0.6
	steering = clamp(lateral_error * 2.0, -max_steer, max_steer)

	var desired_speed = max_speed
	if abs(lateral_error) > 0.2:
		desired_speed *= 0.5

	if speed < desired_speed:
		engine_force = acceleration_force
		brake = 0
	else:
		engine_force = 0
		brake = brake_force * 0.05

	for wheel in get_children():
		if wheel is VehicleWheel3D:
			if wheel.use_as_traction:
				wheel.engine_force = engine_force
				wheel.brake = brake
			if wheel.use_as_steering:
				wheel.steering = steering

	if curve_offset >= path_length - 0.1:
		_stop_vehicle()

func _stop_vehicle():
	engine_force = 0
	brake = brake_force
	steering = 0
	has_finished = true
	print("[STOP] Véhicule arrêté")

	if not personne_scene:
		push_error("Pas de Personne.tscn assignée !")
		return

	var nb_personnes = randi() % 3 + 1
	for i in nb_personnes:
		var p_scene = personne_scene.instantiate()
		var p_data = Personne.new()
		
		p_data.taille = 1.5 + randf() * 0.5
		p_data.poids = 50 + randf() * 50
		p_data.couleur_peau = Color(randf(), randf(), randf())
		p_data.couleur_cheveux = Color(randf(), randf(), randf())
		p_data.couleur_haut = Color(randf(), randf(), randf())
		p_data.couleur_bas = Color(randf(), randf(), randf())
		p_data.couleur_chaussures = Color(randf(), randf(), randf())
		
		print("p_data : ", p_data)
		
		p_scene.data = p_data

		get_parent().add_child(p_scene)

		var angle = randf() * PI * 2
		var distance = 2.0 + randf() * 2.0
		var offset_above_ground = p_scene.BASE_HEIGHT * p_scene.scale.y * 0.5 + 0.1
		p_scene.global_position = global_position + Vector3(cos(angle) * distance, offset_above_ground, sin(angle) * distance)
		p_scene._snap_to_ground_safe()
