extends Node3D
## Effekter: gnistor, explosioner, rök, eld, däckrök och sladdspår.

var _pools: Dictionary = {}
var _pool_idx: Dictionary = {}
var _skid_mm: MultiMesh
var _skid_i := 0
const SKIDS := 1600
var _dot: Texture2D


func _ready() -> void:
	# Effekterna flyttas mellan platser. Utan detta startar de där de var förra gången.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_dot = _soft_dot()
	_pools["sparks"] = _make_pool(10, _sparks_template)
	_pools["fireball"] = _make_pool(5, _fireball_template)
	_pools["boom_smoke"] = _make_pool(5, func(): return _smoke_template(false, true))
	_pools["puff"] = _make_pool(16, _puff_template)
	_pools["spray"] = _make_pool(40, _spray_template)
	for k in _pools:
		_pool_idx[k] = 0
	_skid_mm = MultiMesh.new()
	_skid_mm.transform_format = MultiMesh.TRANSFORM_3D
	_skid_mm.use_colors = true
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	_skid_mm.mesh = pm
	_skid_mm.instance_count = SKIDS
	for i in SKIDS:
		_skid_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(0.001, 0.001, 0.001)), Vector3(0, -100, 0)))
		_skid_mm.set_instance_color(i, Color(0, 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _skid_mm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.01, 0.01, 0.01, 1)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.9
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-5000, -50, -5000), Vector3(10000, 200, 10000))
	add_child(mmi)


func _make_pool(count: int, maker: Callable) -> Array:
	var arr: Array = []
	for i in count:
		var p: GPUParticles3D = maker.call()
		p.emitting = false
		add_child(p)
		arr.append(p)
	return arr


func _next(kind: String) -> GPUParticles3D:
	var arr: Array = _pools[kind]
	var i: int = _pool_idx[kind]
	_pool_idx[kind] = (i + 1) % arr.size()
	return arr[i]


func _quad_mat(add: bool, color := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _dot
	m.albedo_color = color
	return m


func _ramp(cols: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, cols[0])
	g.set_color(1, cols[cols.size() - 1])
	for k in range(1, cols.size() - 1):
		g.add_point(float(k) / (cols.size() - 1), cols[k])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _sparks_template() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 15.0
	pm.gravity = Vector3(0, -18, 0)
	pm.scale_min = 0.015
	pm.scale_max = 0.04
	pm.color_ramp = _ramp([Color(1, 1, 0.8, 1), Color(1, 0.6, 0.1, 1), Color(1, 0.2, 0.0, 0)])
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.material = _quad_mat(true, Color(1.2, 0.9, 0.55))
	p.draw_pass_1 = qm
	return p


func _fireball_template() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 12.0
	pm.gravity = Vector3(0, 3, 0)
	pm.damping_min = 4.0
	pm.damping_max = 6.0
	pm.scale_min = 1.2
	pm.scale_max = 2.6
	pm.color_ramp = _ramp([Color(1, 0.95, 0.7, 1), Color(1, 0.5, 0.1, 0.9), Color(0.4, 0.05, 0.0, 0)])
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.material = _quad_mat(true, Color(3, 2, 1.2))
	p.draw_pass_1 = qm
	return p


func _smoke_template(fire: bool, burst: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40 if burst else (20 if fire else 18)
	p.lifetime = 2.5 if burst else (0.55 if fire else 1.5)
	p.one_shot = burst
	p.explosiveness = 0.9 if burst else 0.0
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0 if not burst else 180.0
	pm.initial_velocity_min = (0.8 if fire else 1.2) if not burst else 3.0
	pm.initial_velocity_max = (1.8 if fire else 2.8) if not burst else 8.0
	pm.gravity = Vector3(0, 2.5, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_min = 0.3 if fire else 0.6
	pm.scale_max = 0.6 if fire else 1.3
	if burst:
		pm.scale_min = 3.0
		pm.scale_max = 6.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	if fire:
		pm.color_ramp = _ramp([Color(1, 0.9, 0.5, 1), Color(1, 0.4, 0.05, 0.8), Color(0.2, 0.05, 0.02, 0)])
	else:
		pm.color_ramp = _ramp([Color(0.25, 0.24, 0.26, 0.0), Color(0.18, 0.17, 0.19, 0.55), Color(0.1, 0.1, 0.1, 0)])
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.material = _quad_mat(fire, Color(2.5, 1.6, 1.0) if fire else Color.WHITE)
	p.draw_pass_1 = qm
	return p


func _puff_template() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 4
	p.lifetime = 1.2
	p.one_shot = true
	p.explosiveness = 0.8
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 50.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, 0.8, 0)
	pm.scale_min = 0.8
	pm.scale_max = 1.5
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(1, 2.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.color_ramp = _ramp([Color(0.6, 0.6, 0.65, 0.14), Color(0.5, 0.5, 0.55, 0)])
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.material = _quad_mat(false)
	p.draw_pass_1 = qm
	return p


func _fire(kind: String, pos: Vector3, dir := Vector3.UP, ratio := 1.0) -> void:
	var p := _next(kind)
	p.global_position = pos
	p.reset_physics_interpolation()
	if dir.length_squared() > 0.01:
		var pm: ParticleProcessMaterial = p.process_material
		pm.direction = dir.normalized()
	p.amount_ratio = clampf(ratio, 0.05, 1.0)
	p.restart()
	p.emitting = true


func sparks(pos: Vector3, dir: Vector3, count: int) -> void:
	_fire("sparks", pos, dir + Vector3.UP * 0.5, count / 40.0)


func tyre_smoke(pos: Vector3) -> void:
	_fire("puff", pos)


func spray(pos: Vector3, vel: Vector3) -> void:
	var p := _next("spray")
	p.global_position = pos
	p.reset_physics_interpolation()
	var pm: ParticleProcessMaterial = p.process_material
	pm.direction = (-vel.normalized() * 0.4 + Vector3.UP * 0.6).normalized()
	p.restart()
	p.emitting = true


func _spray_template() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 5
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -6, 0)
	pm.scale_min = 0.4
	pm.scale_max = 0.9
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(1, 1.8))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.color_ramp = _ramp([Color(0.75, 0.82, 0.95, 0.16), Color(0.7, 0.78, 0.9, 0)])
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.material = _quad_mat(false)
	p.draw_pass_1 = qm
	return p


func explosion(pos: Vector3) -> void:
	_fire("fireball", pos)
	_fire("boom_smoke", pos + Vector3.UP)
	_fire("sparks", pos, Vector3.UP, 1.0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 16.0
	l.omni_range = 30.0
	add_child(l)
	l.global_position = pos + Vector3.UP * 2.0
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.7)
	tw.tween_callback(l.queue_free)


func attach_smoke(car: Node3D, local_pos: Vector3, fire: bool) -> Node3D:
	var holder := Node3D.new()
	holder.position = local_pos
	var s := _smoke_template(false, false)
	s.emitting = true
	holder.add_child(s)
	if fire:
		var f := _smoke_template(true, false)
		f.local_coords = true   # lågorna följer bilen i stället för att bli ett spår av eldklot
		f.emitting = true
		holder.add_child(f)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.5, 0.15)
		l.light_energy = 0.8
		l.omni_range = 4.0
		l.position = Vector3(0, 0.6, 0)
		holder.add_child(l)
	car.add_child(holder)
	return holder


func skid_mark(pos: Vector3, vel: Vector3, w: float) -> void:
	var d := Vector3(vel.x, 0, vel.z)
	if d.length() < 1.0:
		return
	var len := clampf(d.length() * 0.035 + 0.2, 0.3, 3.0)
	var b := Basis.looking_at(d.normalized(), Vector3.UP).scaled(Vector3(w, 1, len))
	_skid_mm.set_instance_transform(_skid_i, Transform3D(b, pos + Vector3.UP * 0.035))
	_skid_mm.set_instance_color(_skid_i, Color(0, 0, 0, 0.55))
	_skid_i = (_skid_i + 1) % SKIDS


func clear_skids() -> void:
	for i in SKIDS:
		_skid_mm.set_instance_color(i, Color(0, 0, 0, 0))


func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.4, Color(1, 1, 1, 0.6))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	return gt
