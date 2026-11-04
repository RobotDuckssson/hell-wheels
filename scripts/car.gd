extends RigidBody3D
## En bil: fjädring med strålar, däckgrepp, sladd, boost, krockskador och vrak.
## Styrs av en förare (spelare eller AI) som sätter throttle/steer_in/handbrake/boost_in.

signal wrecked(car)

const CarTypes = preload("res://scripts/car_types.gd")
const CarModel = preload("res://scripts/car_model.gd")

const SUSP_REST := 0.5
const RAY_TOP := 0.45
const GRIP_SCALE := 1.55   # arkadgrepp: högre än verkliga däck så att man kan ta kurvor i fart
const RAY_BELOW := 0.27   # strålens längd under hjulets fästpunkt vid hängande hjul

var game: Node = null
var type_id := 0
var stats: Dictionary
var racer_name := "?"
var is_player := false
var paint := Color.WHITE
var accent := Color.WHITE

# Styrning (sätts av föraren varje fysiksteg)
var throttle := 0.0
var steer_in := 0.0
var handbrake := false
var boost_in := false
var can_drive := false
var driver = null

# Tillstånd
var hp := 100.0
var max_hp := 100.0
var alive := true
var boost := 1.0
var boosting := false
var speed := 0.0
var fwd_speed := 0.0
var slip := 0.0          # hur mycket bilen glider i sidled (m/s)
var grounded := 0
var steer_angle := 0.0
var damage_mult := 1.0   # svårighetsgradens skada mot just den här bilen
var top_mult := 1.0
var accel_mult := 1.0
var grip_mult := 1.0
var last_hitter = null
var last_hit_time := -99.0
var kills := 0
var air_time := 0.0
var wreck_time := 0.0
var finished := false
var finish_time := 0.0
var eliminated := false
var place := 0

# Banframsteg
var track_idx := 0
var track_offset := 0.0
var laps_done := 0       # antal passeringar av mållinjen
var half_ok := true
var progress := 0.0
var lap_start := 0.0
var best_lap := 0.0
var lap_times: Array = []

var _model: Dictionary
var _wheel_local: Array = []
var _wheel_comp: Array = []
var _wheel_spin := 0.0
var _prev_vel := Vector3.ZERO
var _contacts: Array = []
var _spark_cd := 0.0
var _skid_cd := 0.0
var _smoke = null
var _fire = null
var _engine: AudioStreamPlayer3D
var _whine: AudioStreamPlayer3D
var _skid: AudioStreamPlayer3D
var _body_tilt := Vector2.ZERO
var _acc := Vector3.ZERO
var _was_boosting := false
var _spray_cd := 0.0
var _lost_parts := 0
var _shake_cb: Callable


func setup(p_type: int, p_paint: Color, p_accent: Color) -> void:
	type_id = p_type
	stats = CarTypes.TYPES[type_id]
	paint = p_paint
	accent = p_accent
	mass = stats["mass"]
	max_hp = stats["hp"]
	hp = max_hp
	collision_layer = 2
	collision_mask = 1 | 2
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 6
	can_sleep = false
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 1.2
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.25, 0)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.25
	pm.bounce = 0.1
	physics_material_override = pm

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = stats["box"]
	cs.shape = bs
	cs.position = Vector3(0, stats["box_y"], 0)
	add_child(cs)

	var r: float = stats["wheel_r"]
	var wx: float = stats["wheel_x"]
	for z in [stats["wheel_zf"], stats["wheel_zb"]]:
		for side in [-1.0, 1.0]:
			_wheel_local.append(Vector3(side * wx, RAY_TOP, z))
			_wheel_comp.append(0.0)
	_build_model()
	_make_audio()


func _build_model() -> void:
	if _model.has("root"):
		_model["root"].queue_free()
	_model = CarModel.build(type_id, paint, accent)
	add_child(_model["root"])
	_lost_parts = 0


func _make_audio() -> void:
	if game == null or game.sfx == null:
		return
	_engine = game.sfx.make_loop("engine", self, -4.0 if is_player else -8.0)
	_whine = game.sfx.make_loop("whine", self, -14.0 if is_player else -20.0)
	_skid = game.sfx.make_loop("skid", self, -80.0)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_contacts.clear()
	for i in state.get_contact_count():
		_contacts.append([state.get_contact_collider_position(i), state.get_contact_collider_object(i), state.get_contact_local_normal(i)])


func _physics_process(delta: float) -> void:
	if driver != null:
		driver.drive(self, delta)
	if not can_drive:
		throttle = 0.0
		handbrake = true
		boost_in = false
	if not alive:
		throttle = 0.0
		steer_in = 0.0
		handbrake = true

	var space := get_world_3d().direct_space_state
	var gb := global_basis
	var up := gb.y
	var fwd := -gb.z
	var right := gb.x
	var v := linear_velocity
	speed = v.length()
	fwd_speed = v.dot(fwd)
	var top: float = float(stats["top"]) * top_mult
	var grip: float = float(stats["grip"]) * grip_mult
	var m := mass

	# Styrvinkel: mindre vid hög fart
	var speed_k := clampf(absf(fwd_speed) / top, 0.0, 1.0)
	var max_steer := deg_to_rad(float(stats["steer"])) * lerpf(1.0, 0.42, speed_k)
	steer_angle = move_toward(steer_angle, steer_in * max_steer, delta * 4.5)

	boosting = boost_in and boost > 0.02 and alive and can_drive
	if boosting:
		boost = maxf(0.0, boost - delta * 0.28)
	else:
		boost = minf(1.0, boost + delta * 0.05)

	grounded = 0
	var k := m * 9.81 * 0.25 / 0.22    # fjäderkonstant per hjul
	var c := 2.0 * 0.55 * sqrt(k * m * 0.25)
	var ray_len := RAY_TOP + RAY_BELOW
	var ground_n := Vector3.ZERO
	var slip_sum := 0.0
	var wload := m * 9.81 * 0.25
	for i in 4:
		var origin: Vector3 = global_transform * _wheel_local[i]
		var to := origin - up * ray_len
		var q := PhysicsRayQueryParameters3D.create(origin, to, 1, [get_rid()])
		var hit := space.intersect_ray(q)
		var front := i < 2
		if hit.is_empty():
			_wheel_comp[i] = lerpf(_wheel_comp[i], 0.0, 0.3)
			continue
		grounded += 1
		var hp_pos: Vector3 = hit["position"]
		var n: Vector3 = hit["normal"]
		ground_n += n
		var dist := origin.distance_to(hp_pos)
		var comp := clampf(ray_len - dist, 0.0, ray_len)
		_wheel_comp[i] = comp
		var rel := hp_pos - global_position
		var pv := v + angular_velocity.cross(rel)
		var f_s := comp * k - pv.dot(up) * c
		if comp > 0.42:
			f_s += (comp - 0.42) * k * 6.0
		f_s = maxf(f_s, 0.0)
		apply_force(up * f_s, rel)

		# Däck
		var wf := fwd
		if front:
			wf = fwd.rotated(up, -steer_angle)
		wf = (wf - n * wf.dot(n)).normalized()
		var wr := wf.cross(n).normalized()
		var lat_v := pv.dot(wr)
		var mu := grip
		var stiff := 15.0
		if not front:
			if handbrake:
				mu *= 0.42
				stiff = 2.5
		var max_f := mu * GRIP_SCALE * wload * (1.0 + speed_k * 0.5)
		var f_lat := -lat_v * m * 0.25 * stiff
		if absf(f_lat) > max_f:
			f_lat = signf(f_lat) * max_f
		if not front:
			slip_sum += absf(lat_v)
		# Kraften läggs i höjd med tyngdpunkten så att bilen inte välter
		var at := origin - up * (RAY_TOP - 0.25) - global_position
		apply_force(wr * f_lat, at)

		# Rullmotstånd och handbroms
		var long_v := pv.dot(wf)
		var roll := -long_v * m * 0.25 * 0.06
		if handbrake and not front:
			roll = -signf(long_v) * minf(absf(long_v) * m * 0.25 * 2.0, wload * 0.9)
		apply_force(wf * roll, at)

	slip = slip_sum * 0.5
	var ground_frac := grounded / 4.0

	# Motor och broms
	if grounded > 0:
		ground_n = ground_n.normalized()
		var flat_fwd := (fwd - ground_n * fwd.dot(ground_n)).normalized()
		var acc: float = float(stats["accel"]) * accel_mult
		var top_now := top * (1.25 if boosting else 1.0)
		var drive := 0.0
		if throttle > 0.05:
			if fwd_speed < -1.0:
				drive = throttle * 22.0          # bromsar när man backar och gasar
			else:
				var taper := clampf(1.0 - pow(maxf(fwd_speed, 0.0) / top_now, 2.0), 0.0, 1.0)
				drive = throttle * acc * (1.6 if boosting else 1.0) * (0.25 + 0.75 * taper)
				if fwd_speed > top_now:
					drive = -2.0
		elif throttle < -0.05:
			if fwd_speed > 1.5:
				drive = throttle * 24.0          # broms
			else:
				var rtaper := clampf(1.0 - absf(minf(fwd_speed, 0.0)) / 18.0, 0.0, 1.0)
				drive = throttle * 7.0 * rtaper
		apply_central_force(flat_fwd * drive * m * ground_frac)
		# Styrhjälp: lite extra girmoment så att bilen vrider in i kurvan även i hög fart
		if alive and absf(fwd_speed) > 3.0 and grounded >= 3:
			var want_yaw := -steer_in * clampf(absf(fwd_speed) / 12.0, 0.0, 1.0) * 1.35 * signf(fwd_speed)
			var yaw_err := want_yaw - angular_velocity.dot(up)
			if signf(yaw_err) == signf(want_yaw) or absf(steer_in) < 0.1:
				apply_torque(up * yaw_err * m * 2.5 * (1.0 if absf(steer_in) > 0.1 else 0.0))
		# Hjälp att hålla sladden: styrning ger lite extra girmoment när bilen glider
		if slip > 3.0 and alive:
			apply_torque(up * steer_in * m * 2.2 * clampf(slip / 10.0, 0.0, 1.0) * signf(fwd_speed + 0.1))
		# Marktryck
		apply_central_force(-up * speed * speed * m * 0.0022)
		air_time = 0.0
	else:
		air_time += delta
		# Rätar upp bilen i luften
		var tq := up.cross(Vector3.UP) * m * 6.0
		apply_torque(tq - angular_velocity * m * 0.6)

	# Luftmotstånd
	apply_central_force(-v * speed * m * 0.0006)

	_check_impacts(delta)
	_prev_vel = linear_velocity
	_update_visuals(delta)
	_update_audio()


func _check_impacts(delta: float) -> void:
	var dv := linear_velocity - _prev_vel
	_acc = _acc.lerp(dv / maxf(delta, 0.001), 0.3)
	var up := global_basis.y
	dv -= up * dv.dot(up) * 0.7
	var impact := dv.length()
	_spark_cd -= delta
	var t_now := _now()
	var hit_car = null
	var hit_pos := global_position
	var touching_wall := false
	for ct in _contacts:
		var obj = ct[1]
		if obj != null and obj.has_method("take_damage"):
			hit_car = obj
			hit_pos = ct[0]
		else:
			touching_wall = true
			hit_pos = ct[0]
	if hit_car != null:
		hit_car.last_hitter = self
		hit_car.last_hit_time = t_now
	if impact > 4.5 and _contacts.size() > 0:
		var fwd := -global_basis.z
		var frontal := dv.normalized().dot(fwd) < -0.5
		var dmg := (impact - 4.5) * 1.9 / float(stats["armor"])
		if frontal and hit_car != null:
			dmg *= 0.55   # den som rammar klarar sig bättre
		var cap := max_hp * (0.34 if game != null and game.settings["mode"] == 1 else 0.45)
		take_damage(minf(dmg * damage_mult, cap), hit_car)
		if game != null:
			game.fx.sparks(hit_pos, dv.normalized(), clampi(int(impact * 2.0), 6, 40))
			game.sfx.play3d("crash_big" if impact > 12.0 else "crash", hit_pos, clampf(-14.0 + impact, -12.0, 4.0))
			if is_player:
				game.shake(clampf(impact * 0.04, 0.05, 0.8))
	elif touching_wall and speed > 12.0 and _spark_cd <= 0.0 and game != null:
		_spark_cd = 0.06
		game.fx.sparks(hit_pos, -linear_velocity.normalized() * 0.5 + Vector3.UP * 0.3, 3)
		if is_player:
			game.sfx.play3d("scrape", hit_pos, -12.0)


func _now() -> float:
	return game.race_time if game != null else Time.get_ticks_msec() / 1000.0


func take_damage(amount: float, source = null) -> void:
	if not alive or amount <= 0.0:
		return
	var before := hp
	hp -= amount
	if source != null:
		last_hitter = source
		last_hit_time = _now()
	var ratio := hp / max_hp
	# Delar lossnar vid 75 %, 50 % och 25 % kvar
	for th in [0.75, 0.5, 0.25]:
		if before / max_hp > th and ratio <= th:
			_lose_part()
			_lose_part()
	_apply_damage_look()
	if hp <= 0.0:
		hp = 0.0
		_wreck()


func _apply_damage_look() -> void:
	var ratio := hp / max_hp
	var dark := clampf(1.0 - ratio, 0.0, 1.0) * 0.55
	for key in ["paint", "paint2"]:
		var mt: StandardMaterial3D = _model["mats"][key]
		var base := paint if key == "paint" else paint.darkened(0.3)
		mt.albedo_color = base.lerp(Color(0.06, 0.05, 0.05), dark)
		mt.roughness = lerpf(0.32, 0.8, dark)
	if _model.has("kmat"):
		(_model["kmat"] as ShaderMaterial).set_shader_parameter("dark", dark)
	if game != null:
		var bz: float = stats["box"].z
		if ratio < 0.5 and _smoke == null:
			_smoke = game.fx.attach_smoke(self, Vector3(0, 0.9, -bz * 0.32), false)
		if ratio < 0.25 and _fire == null:
			_fire = game.fx.attach_smoke(self, Vector3(0, 0.85, -bz * 0.3), true)


const DEBRIS := ["debris-bumper", "debris-door", "debris-door-window", "debris-spoiler-a", "debris-spoiler-b", "debris-tire", "debris-plate-a", "debris-plate-b"]


func _lose_part() -> void:
	var loose: Array = _model["loose"]
	if game == null:
		return
	if loose.is_empty():
		if _model.has("kscale") and _lost_parts < 6:
			_kenney_debris()
		return
	var mi: MeshInstance3D = loose.pop_at(randi() % loose.size())
	if not is_instance_valid(mi):
		return
	var gt := mi.global_transform
	var aabb := mi.get_aabb()
	var rb := RigidBody3D.new()
	rb.collision_layer = 4
	rb.collision_mask = 1
	rb.mass = 20.0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = (aabb.size * mi.scale).max(Vector3(0.08, 0.08, 0.08))
	cs.shape = bs
	cs.position = aabb.get_center()
	rb.add_child(cs)
	mi.get_parent().remove_child(mi)
	mi.transform = Transform3D(mi.transform.basis, Vector3.ZERO)
	rb.add_child(mi)
	# Lösa delar ska inte lysa (annars ser de ut som flygande lampor)
	var om := mi.material_override as StandardMaterial3D
	if om != null and om.emission_enabled:
		mi.material_override = _model["mats"]["dark"]
	game.debris_root.add_child(rb)
	rb.global_transform = gt
	rb.linear_velocity = linear_velocity * 0.8 + Vector3(randf_range(-4, 4), randf_range(3, 7), randf_range(-4, 4))
	rb.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	game.add_debris(rb)
	_lost_parts += 1


## Kenneys lösa delar flyger av: stötfångare, dörrar, spoilers och däck.
func _kenney_debris() -> void:
	var path := "res://assets/bilar/%s.glb" % DEBRIS[randi() % DEBRIS.size()]
	if not ResourceLoader.exists(path):
		return
	var inst: Node3D = load(path).instantiate()
	var k: float = _model["kscale"]
	CarModel._set_mat(inst, _model["kmat"])
	var ab := CarModel._aabb_of(inst, Transform3D.IDENTITY)
	var rb := RigidBody3D.new()
	rb.collision_layer = 4
	rb.collision_mask = 1
	rb.mass = 20.0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = (ab.size * k).max(Vector3(0.1, 0.1, 0.1))
	cs.shape = bs
	rb.add_child(cs)
	var holder := Node3D.new()
	holder.scale = Vector3(k, k, k)
	inst.position = -ab.get_center()
	holder.add_child(inst)
	rb.add_child(holder)
	game.debris_root.add_child(rb)
	var side := -1.0 if randf() < 0.5 else 1.0
	rb.global_transform = Transform3D(global_basis, global_transform * Vector3(side * 0.8, 0.8, randf_range(-1.5, 1.5)))
	rb.linear_velocity = linear_velocity * 0.8 + global_basis.x * side * randf_range(2, 5) + Vector3.UP * randf_range(3, 7)
	rb.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	game.add_debris(rb)
	_lost_parts += 1


func _wreck() -> void:
	alive = false
	wreck_time = _now()
	if game != null:
		game.fx.explosion(global_position + Vector3.UP)
		game.sfx.play3d("explosion", global_position, 6.0)
		if is_player:
			game.shake(1.2)
	apply_central_impulse(Vector3.UP * mass * 7.0 + linear_velocity * mass * 0.1)
	apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * mass * 3.0)
	for key in ["paint", "paint2"]:
		var mt: StandardMaterial3D = _model["mats"][key]
		mt.albedo_color = Color(0.04, 0.035, 0.03)
		mt.roughness = 0.95
		mt.metallic = 0.2
	if _model.has("kmat"):
		(_model["kmat"] as ShaderMaterial).set_shader_parameter("dark", 0.92)
	for key in ["head", "tail", "accent", "amber"]:
		var mt2: StandardMaterial3D = _model["mats"][key]
		mt2.emission_energy_multiplier = 0.0
		mt2.albedo_color = Color(0.05, 0.05, 0.05)
	for l in _model["lights"]:
		l.visible = false
	for i in 3:
		_lose_part()
	if game != null and _fire == null:
		_fire = game.fx.attach_smoke(self, Vector3(0, 0.9, 0), true)
	if _engine:
		_engine.stop()
	if _whine:
		_whine.stop()
	wrecked.emit(self)


## Sätter tillbaka bilen på banan, hel eller delvis lagad.
func respawn_at(xf: Transform3D, heal_to: float) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_prev_vel = Vector3.ZERO
	global_transform = xf
	reset_physics_interpolation()
	if not alive or heal_to > 0.0:
		var keep := hp
		alive = true
		hp = maxf(keep, max_hp * heal_to)
		if _smoke != null:
			_smoke.queue_free()
			_smoke = null
		if _fire != null:
			_fire.queue_free()
			_fire = null
		_build_model()
		if _engine:
			_engine.play()
		if _whine:
			_whine.play()
		_apply_damage_look()


func _update_visuals(delta: float) -> void:
	_wheel_spin += fwd_speed * delta / float(stats["wheel_r"])
	var wheels: Array = _model["wheels"]
	var r: float = stats["wheel_r"]
	for wi in wheels.size():
		var w: Dictionary = wheels[wi]
		var pivot: Node3D = w["pivot"]
		if w.get("kenney", false):
			(w["spin"] as Node3D).rotation.x = _wheel_spin
			if w["front"]:
				pivot.rotation.y = -steer_angle
			continue
		var idx := (0 if w["x"] < 0 else 1) + (0 if w["front"] else 2)
		var comp: float = _wheel_comp[idx]
		pivot.position.y = comp - RAY_BELOW + r
		if w["front"]:
			pivot.rotation.y = -steer_angle
		var spin: Node3D = w["spin"]
		spin.rotation.x = -_wheel_spin
	# Karossen lutar lite i kurvor och vid inbromsning
	var acc_local := global_basis.inverse() * (_acc)
	var target := Vector2(clampf(acc_local.z * 0.004, -0.06, 0.06), clampf(-acc_local.x * 0.005, -0.07, 0.07))
	_body_tilt = _body_tilt.lerp(target, 0.12)
	var body: Node3D = _model["body"]
	body.rotation = Vector3(_body_tilt.x, 0, _body_tilt.y)
	var flames: Node3D = _model["flames"]
	flames.visible = boosting
	if boosting:
		flames.scale = Vector3(1, 1, randf_range(0.7, 1.25))
		if not _was_boosting and is_player and game != null:
			game.sfx.play("boost", -6.0)
	_was_boosting = boosting

	# Däckspår och däckrök
	_skid_cd -= delta
	if game != null and grounded >= 2 and (slip > 4.5 or (handbrake and speed > 8.0)) and _skid_cd <= 0.0:
		_skid_cd = 0.03
		var zb: float = stats["wheel_zb"]
		for side in [-1.0, 1.0]:
			var p := global_transform * Vector3(side * float(stats["wheel_x"]), 0.0, zb)
			var gp := p - global_basis.y * 0.05
			game.fx.skid_mark(gp, linear_velocity, float(stats["wheel_w"]))
		if slip > 7.0 and randf() < 0.5:
			game.fx.tyre_smoke(global_transform * Vector3(0, 0.2, zb + 0.3))
	# Vattenstänk bakom hjulen på våta banor
	if game != null and game.track != null and game.track.def.get("rain", false) and grounded >= 2 and speed > 14.0:
		_spray_cd -= delta
		if _spray_cd <= 0.0:
			_spray_cd = 0.07
			var zb2: float = stats["wheel_zb"]
			for side2 in [-1.0, 1.0]:
				game.fx.spray(global_transform * Vector3(side2 * float(stats["wheel_x"]), 0.15, zb2 + 0.4), linear_velocity)


func _update_audio() -> void:
	if _engine == null:
		return
	var top: float = stats["top"]
	var sr := clampf(absf(fwd_speed) / top, 0.0, 1.3)
	var gear_pos := fmod(sr * 4.0, 1.0)
	var rpm := 0.55 + sr * 0.7 + gear_pos * 0.35 + absf(throttle) * 0.15
	_engine.pitch_scale = clampf(rpm, 0.4, 2.4)
	_whine.pitch_scale = clampf(0.6 + sr * 1.6 + (0.3 if boosting else 0.0), 0.5, 3.0)
	var sv := clampf((slip - 3.0) / 8.0, 0.0, 1.0) if grounded >= 2 else 0.0
	if handbrake and speed > 8.0 and grounded >= 2:
		sv = maxf(sv, 0.6)
	_skid.volume_db = lerpf(-60.0, -6.0 if is_player else -12.0, sv) if sv > 0.01 else -80.0
