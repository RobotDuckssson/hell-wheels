extends Camera3D
## Jaktkamera bakom bilen (tre lägen) och en kretsande kamera för menyn.

var target = null
var mode := 0
var shake := 0.0
var _orbit := false
var _orbit_t := 0.0
var _snap := true


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_mode = Node.PROCESS_MODE_ALWAYS
	far = 3500.0
	near = 0.1
	fov = 72.0
	current = true


func follow(car) -> void:
	target = car
	_orbit = false
	_snap = true


func set_orbit(car) -> void:
	target = car
	_orbit = true
	_snap = true


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var xf: Transform3D = target.get_global_transform_interpolated()
	var cp := xf.origin
	if _orbit:
		_orbit_t += delta * 0.18
		var r := 9.5
		global_position = cp + Vector3(cos(_orbit_t) * r, 2.4 + sin(_orbit_t * 0.7) * 0.6, sin(_orbit_t) * r)
		look_at(cp + Vector3.UP * 0.9, Vector3.UP)
		fov = 48.0
		h_offset = -2.6
		v_offset = 0.0
		return
	if get_tree().paused:
		return
	var fwd := -xf.basis.z
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	var vel: Vector3 = target.linear_velocity
	var vflat := Vector3(vel.x, 0, vel.z)
	var spd := vflat.length()
	var dir := flat
	if spd > 6.0 and vflat.dot(flat) > 0.0:
		dir = (flat * 0.6 + vflat.normalized() * 0.4).normalized()
	var top: float = target.stats["top"]
	var sr := clampf(spd / top, 0.0, 1.3)
	var desired: Vector3
	var look: Vector3
	match mode:
		1:
			desired = xf * Vector3(0, 1.25, -0.3)
			look = desired + fwd * 20.0
		2:
			desired = cp - dir * (13.0 + sr * 2.0) + Vector3.UP * 5.0
			look = cp + Vector3.UP * 1.2 + dir * 4.0
		_:
			desired = cp - dir * (7.2 + sr * 1.8) + Vector3.UP * (2.5 + sr * 0.3)
			look = cp + Vector3.UP * 1.1 + dir * 3.5
	if not target.alive:
		desired = cp - flat * 11.0 + Vector3.UP * 6.0
		look = cp
	if _snap or global_position.distance_to(desired) > 60.0:
		global_position = desired
		_snap = false
	elif mode == 1:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-delta * 9.0))
	look_at(look, Vector3.UP)
	var want := 70.0 + sr * 16.0 + (8.0 if target.boosting else 0.0)
	fov = lerpf(fov, want, 1.0 - exp(-delta * 4.0))
	if shake > 0.0:
		h_offset = randf_range(-1, 1) * shake * 0.35
		v_offset = randf_range(-1, 1) * shake * 0.35
		shake = move_toward(shake, 0.0, delta * 2.2)
	else:
		h_offset = 0.0
		v_offset = 0.0
