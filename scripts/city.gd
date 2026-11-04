extends Node3D
## Staden runt banan: skyskrapor, neonskyltar, hologram, flygande trafik,
## luftskepp, skorstenar med lågor, regn, himmel, dimma och belysning.

var track
var def: Dictionary
var quality := 1
var rng := RandomNumberGenerator.new()
var _traffic_mm: MultiMesh
var _traffic: Array = []
var _blimp: Node3D
var _blimp_t := 0.0
var _rain: GPUParticles3D
var _blinkers: Array = []
var _roofs: Array = []
var _kmodels: Array = []     # Kenney-hus: [mesh, nodtransform, aabb, material, ljus]
var _khouses: Array = []     # [modellindex, transform, färg]
const KENNEY := [
	["res://assets/hus/modular/building-sample-house-a.glb", 0.35], ["res://assets/hus/modular/building-sample-house-b.glb", 0.35],
	["res://assets/hus/modular/building-sample-house-c.glb", 0.35], ["res://assets/hus/modular/building-sample-tower-a.glb", 0.35],
	["res://assets/hus/modular/building-sample-tower-b.glb", 0.35], ["res://assets/hus/modular/building-sample-tower-c.glb", 0.35],
	["res://assets/hus/modular/building-sample-tower-d.glb", 0.35],
	["res://assets/hus/commercial/building-a.glb", 0.75], ["res://assets/hus/commercial/building-c.glb", 0.75],
	["res://assets/hus/commercial/building-e.glb", 0.75], ["res://assets/hus/commercial/building-g.glb", 0.75],
	["res://assets/hus/commercial/building-i.glb", 0.75], ["res://assets/hus/commercial/building-k.glb", 0.75],
	["res://assets/hus/commercial/building-m.glb", 0.75], ["res://assets/hus/commercial/building-n.glb", 0.75],
]
const STHLM := [Color(0.82, 0.6, 0.28), Color(0.9, 0.78, 0.42), Color(0.7, 0.34, 0.2), Color(0.86, 0.58, 0.48),
	Color(0.62, 0.7, 0.52), Color(0.84, 0.77, 0.64), Color(0.84, 0.84, 0.8), Color(0.58, 0.64, 0.7)]
var env: Environment
var day := false
var _esc_mm: MultiMesh
var _escorts: Array = []
var _beams: Array = []
var _t := 0.0

const WORDS := ["NEXUS", "SYNTH", "HOTEL", "RAMEN", "KRONOS", "NOVA", "ZENIT", "OMNI", "BAR 24", "LUMEN",
	"VEGA", "ORBITAL", "KAFFE", "NUDLAR", "PHARMA", "SOMA", "OASIS", "DATA", "AURORA", "HYPER",
	"ATLAS", "TITAN", "JADE", "ONYX", "KOI", "MOTEL", "KLINIK", "SUSHI", "ARKAD", "BIO"]
const HSIGNS := ["HOTEL NOVA", "24H", "OFF-WORLD", "SYNTHCORP", "RAMEN", "KLUBB ZERO", "GARAGE", "NEON DREAMS", "ZENIT BANK", "DATAKAFÉ"]


func build(p_track, p_quality: int) -> void:
	track = p_track
	def = track.def
	quality = p_quality
	rng.seed = hash(def["name"])
	day = def.get("day", false)
	_environment()
	_buildings()
	_traffic_build()
	_blimp_build()
	if day:
		_landmarks()
	else:
		_chimneys()
		_searchlights()


func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = def["sky_top"]
	psm.sky_horizon_color = def["sky_horizon"]
	psm.sky_curve = 0.12
	psm.ground_bottom_color = Color(0.02, 0.02, 0.03)
	psm.ground_horizon_color = Color(def["sky_horizon"]).darkened(0.4)
	psm.sun_angle_max = 8.0
	psm.sun_curve = 0.08
	psm.sky_energy_multiplier = 1.35
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.ambient_light_sky_contribution = 0.7
	env.ambient_light_color = Color(0.55, 0.5, 0.7)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = float(def.get("exposure", 1.4))
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.1
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = def["fog"]
	env.fog_density = float(def["fog_density"]) * 0.75
	env.fog_sky_affect = 0.35
	env.fog_height = 30.0
	env.fog_height_density = 0.012
	env.fog_aerial_perspective = 0.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	if quality > 0:
		env.ssr_enabled = true
		env.ssr_max_steps = 48
		env.ssr_fade_in = 0.1
		env.ssr_fade_out = 2.0
		env.ssao_enabled = true
		env.ssao_radius = 1.5
		env.ssao_intensity = 1.5
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.004
		env.volumetric_fog_albedo = Color(def["fog"]).lightened(0.3)
		env.volumetric_fog_emission = Color(def["fog"]) * 0.05
		env.volumetric_fog_length = 160.0
		env.volumetric_fog_anisotropy = 0.5
		env.volumetric_fog_ambient_inject = 0.3
	if day:
		psm.sun_angle_max = 30.0
		psm.ground_horizon_color = Color(0.6, 0.66, 0.72)
		psm.ground_bottom_color = Color(0.2, 0.25, 0.3)
		env.ambient_light_energy = 0.45
		env.ambient_light_sky_contribution = 1.0
		env.glow_intensity = 0.3
		env.glow_hdr_threshold = 1.4
		env.fog_height_density = 0.0
		env.fog_aerial_perspective = 0.25
		env.fog_density = 0.0005
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.fog_sky_affect = 0.15
		env.adjustment_saturation = 1.1
		env.volumetric_fog_enabled = false
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = def["sun"]
	sun.light_energy = 1.45 if day else 1.1
	sun.rotation_degrees = Vector3(-46, -35, 0) if day else Vector3(-9, 35, 0)
	sun.shadow_enabled = quality > 0
	sun.directional_shadow_max_distance = 240.0 if day else 140.0
	sun.light_volumetric_fog_energy = 1.5
	add_child(sun)
	# svagt motljus så att bilarna syns mot himlen
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(def["neon2"]).lerp(Color(0.4, 0.4, 0.6), 0.6)
	fill.light_energy = 0.2 if day else 0.55
	fill.rotation_degrees = Vector3(-50, -150, 0)
	fill.shadow_enabled = false
	add_child(fill)


func _rand_neon() -> Color:
	var choices := [def["neon"], def["neon2"], Color(1.0, 0.85, 0.2), Color(0.3, 1.0, 0.4), Color(1, 0.2, 0.2), Color(0.6, 0.3, 1.0)]
	return choices[rng.randi() % choices.size()]


func _buildings() -> void:
	var hw: float = track.width * 0.5
	var list: Array = []          # [center Vector2, sx, sz, h, row]
	var occ: Dictionary = {}
	var ch: float = def["city_height"]
	var n: int = track.n
	if day:
		_load_kenney()
	for i in range(0, n, 6):
		for side in [-1.0, 1.0]:
			for row in 3:
				var fp := rng.randf_range(12.0, 30.0) if row == 0 else rng.randf_range(18.0, 42.0)
				var fz := fp * rng.randf_range(0.7, 1.4)
				var d = hw + track.WALL_T + 7.0 + maxf(fp, fz) * 0.5 + row * 48.0 + rng.randf_range(0.0, 10.0)
				var p: Vector3 = track.pts[i] + track.rgts[i] * side * d
				var c := Vector2(p.x, p.z)
				var rad := Vector2(fp, fz).length() * 0.5
				if day and row <= 1 and not _kmodels.is_empty() and rng.randf() < 0.6:
					if _try_kenney(track.pts[i], c, fp, occ):
						continue
				if not _place_ok(c, rad, occ):
					continue
				var h := rng.randf_range(25.0, 110.0)
				if row == 1:
					h = rng.randf_range(50.0, 190.0)
				elif row == 2:
					h = rng.randf_range(80.0, 280.0)
				if rng.randf() < 0.05:
					h = rng.randf_range(300.0, 460.0)
				if day:
					# Stockholmshöjd: 5–9 våningar, ibland ett modernt glastorn
					h = rng.randf_range(16.0, 30.0) + row * 4.0
					if rng.randf() < 0.04:
						h = rng.randf_range(60.0, 110.0)
				_occupy(c, rad, occ)
				list.append([c, fp, fz, h * ch, row, i, side])
	# Bakgrundsskyline
	var b: Rect2 = track.bounds.grow(700.0)
	for k in 700:
		var c := Vector2(rng.randf_range(b.position.x, b.end.x), rng.randf_range(b.position.y, b.end.y))
		var fp := rng.randf_range(25.0, 60.0)
		var fz := fp * rng.randf_range(0.7, 1.4)
		var rad := Vector2(fp, fz).length() * 0.5
		if not _place_ok(c, rad + 20.0, occ):
			continue
		_occupy(c, rad, occ)
		list.append([c, fp, fz, (rng.randf_range(18.0, 45.0) if day else rng.randf_range(60.0, 330.0)) * ch, 3, -1, 0.0])

	# Megatorn: trappstegsformade jättar i fjärran
	for k in (0 if day else 3):
		var ang := rng.randf() * TAU
		var c = track.bounds.get_center() + Vector2.from_angle(ang) * (track.bounds.size.length() * 0.5 + rng.randf_range(450.0, 800.0))
		var base := rng.randf_range(160.0, 240.0)
		var y := 0.0
		for step in 6:
			var w := base * (1.0 - step * 0.14)
			var hh := rng.randf_range(60.0, 110.0)
			list.append([c, w, w, hh, 4, -1, 0.0, y])
			y += hh

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = BoxMesh.new()
	var extra: Array = []
	for e in list:
		if e[4] < 3 and rng.randf() < 0.3 and not day:
			var c: Vector2 = e[0]
			extra.append([c + Vector2(rng.randf_range(-0.15, 0.15) * e[1], rng.randf_range(-0.15, 0.15) * e[2]),
				e[1] * rng.randf_range(0.45, 0.7), e[2] * rng.randf_range(0.45, 0.7), e[3] * rng.randf_range(0.2, 0.5), 5, -1, 0.0, e[3]])
	var all := list + extra
	mm.instance_count = all.size()
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	add_child(sb)
	var antennas: Array[Transform3D] = []
	for k in all.size():
		var e: Array = all[k]
		var c: Vector2 = e[0]
		var y0: float = e[7] if e.size() > 7 else 0.0
		var h: float = e[3]
		var xf := Transform3D(Basis.IDENTITY.scaled(Vector3(e[1], h, e[2])), Vector3(c.x, y0 + h * 0.5, c.y))
		mm.set_instance_transform(k, xf)
		var style := rng.randf()
		var lit := rng.randf_range(0.15, 0.55)
		if day and h > 55.0:
			style = 0.95
		mm.set_instance_custom_data(k, Color(rng.randf(), style, lit, rng.randf()))
		if day and style < 0.88 and rng.randf() < 0.8:
			var rh := rng.randf_range(4.0, 8.0)
			var rb: Basis
			if e[1] > e[2]:
				rb = Basis(Vector3.UP, PI * 0.5) * Basis.IDENTITY.scaled(Vector3(e[2] * 1.02, rh, e[1] * 1.02))
			else:
				rb = Basis.IDENTITY.scaled(Vector3(e[1] * 1.02, rh, e[2] * 1.02))
			var roof_cols := [Color(0.33, 0.56, 0.47), Color(0.17, 0.18, 0.2), Color(0.52, 0.2, 0.12), Color(0.33, 0.56, 0.47)]
			_roofs.append([Transform3D(rb, Vector3(c.x, y0 + h + rh * 0.5, c.y)), roof_cols[rng.randi() % roof_cols.size()]])
		if e[4] <= 1 and y0 == 0.0:
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(e[1], h, e[2])
			cs.shape = bs
			cs.position = xf.origin
			sb.add_child(cs)
		if (e[4] == 2 or e[4] == 5 or h > 200.0) and rng.randf() < 0.5:
			var ah := rng.randf_range(8.0, 30.0)
			antennas.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.6, ah, 0.6)), Vector3(c.x, y0 + h + ah * 0.5, c.y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/building.gdshader")
	sm.set_shader_parameter("neon_a", def["neon"])
	sm.set_shader_parameter("neon_b", def["neon2"])
	sm.set_shader_parameter("day", day)
	# Fototexturer om de finns i projektet
	var fac := "res://assets/fasader/"
	if ResourceLoader.exists(fac + "facade008_color.jpg") and ResourceLoader.exists(fac + "facade013_color.jpg"):
		sm.set_shader_parameter("use_fac", true)
		sm.set_shader_parameter("fac_a_col", load(fac + "facade008_color.jpg"))
		sm.set_shader_parameter("fac_a_emi", load(fac + "facade008_emission.jpg"))
		sm.set_shader_parameter("fac_b_col", load(fac + "facade013_color.jpg"))
		sm.set_shader_parameter("fac_b_emi", load(fac + "facade013_emission.jpg"))
	if ResourceLoader.exists(fac + "concrete_tile_facade_2k.jpg"):
		sm.set_shader_parameter("use_conc", true)
		sm.set_shader_parameter("conc_col", load(fac + "concrete_tile_facade_2k.jpg"))
	mmi.material_override = sm
	add_child(mmi)
	if not _roofs.is_empty():
		var rm2 := MultiMesh.new()
		rm2.transform_format = MultiMesh.TRANSFORM_3D
		rm2.use_colors = true
		rm2.mesh = PrismMesh.new()
		rm2.instance_count = _roofs.size()
		for k in _roofs.size():
			rm2.set_instance_transform(k, _roofs[k][0])
			rm2.set_instance_color(k, _roofs[k][1])
		var rmi := MultiMeshInstance3D.new()
		rmi.multimesh = rm2
		var roofm := StandardMaterial3D.new()
		roofm.vertex_color_use_as_albedo = true
		roofm.roughness = 0.6
		roofm.metallic = 0.3
		rmi.material_override = roofm
		add_child(rmi)

	# Antenner med röda varningsljus
	var am := MultiMesh.new()
	am.transform_format = MultiMesh.TRANSFORM_3D
	am.mesh = BoxMesh.new()
	am.instance_count = antennas.size()
	var tips := MultiMesh.new()
	tips.transform_format = MultiMesh.TRANSFORM_3D
	var sph := SphereMesh.new()
	sph.radius = 0.8
	sph.height = 1.6
	sph.radial_segments = 8
	sph.rings = 4
	tips.mesh = sph
	tips.instance_count = antennas.size()
	for k in antennas.size():
		am.set_instance_transform(k, antennas[k])
		var top := antennas[k].origin + Vector3.UP * antennas[k].basis.get_scale().y * 0.5
		tips.set_instance_transform(k, Transform3D(Basis.IDENTITY, top))
	var ami := MultiMeshInstance3D.new()
	ami.multimesh = am
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.05, 0.05, 0.06)
	ami.material_override = dm
	add_child(ami)
	var tmi := MultiMeshInstance3D.new()
	tmi.multimesh = tips
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1, 0.05, 0.05)
	rm.emission_enabled = true
	rm.emission = Color(1, 0.05, 0.05)
	rm.emission_energy_multiplier = 8.0
	tmi.material_override = rm
	add_child(tmi)
	_blinkers.append(rm)

	_build_kenney()
	if not day:
		_signs(list)


func _place_ok(c: Vector2, rad: float, occ: Dictionary) -> bool:
	if not track.clear_of_track(c, rad):
		return false
	if day:
		for o in [Vector2.ZERO, Vector2(rad, 0), Vector2(-rad, 0), Vector2(0, rad), Vector2(0, -rad)]:
			if not track.is_land(c + o):
				return false
	var ck := Vector2i(floori(c.x / 50.0), floori(c.y / 50.0))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var key := ck + Vector2i(dx, dz)
			if occ.has(key):
				for o in occ[key]:
					if c.distance_to(o[0]) < rad + o[1] + 3.0:
						return false
	return true


func _occupy(c: Vector2, rad: float, occ: Dictionary) -> void:
	var key := Vector2i(floori(c.x / 50.0), floori(c.y / 50.0))
	if not occ.has(key):
		occ[key] = []
	occ[key].append([c, rad])


func _signs(list: Array) -> void:
	var lights := 0
	var max_lights := 26 if quality > 0 else 10
	var holos := 0
	var holo_shader: Shader = load("res://shaders/holo.gdshader")
	for e in list:
		if e[4] != 0 or e[5] < 0:
			continue
		var c: Vector2 = e[0]
		var tp: Vector3 = track.pts[e[5]]
		var to := Vector2(tp.x, tp.z) - c
		var nrm := Vector3(signf(to.x), 0, 0) if absf(to.x) > absf(to.y) else Vector3(0, 0, signf(to.y))
		var half = (e[1] if nrm.x != 0.0 else e[2]) * 0.5
		var along = (e[2] if nrm.x != 0.0 else e[1]) * 0.5
		var tangent := Vector3(-nrm.z, 0, nrm.x)
		var h: float = e[3]
		var roll := rng.randf()
		var base = Vector3(c.x, 0, c.y) + nrm * (half + 0.35)
		if roll < 0.4 and h > 20.0:
			var col := _rand_neon()
			var lab := Label3D.new()
			var word: String = WORDS[rng.randi() % WORDS.size()]
			var vertical := rng.randf() < 0.65
			lab.text = _vertical(word) if vertical else word
			lab.font_size = 96
			lab.pixel_size = rng.randf_range(0.025, 0.04)
			lab.line_spacing = -20.0
			lab.modulate = Color(col.r * 2.2, col.g * 2.2, col.b * 2.2)
			lab.outline_modulate = Color(col.r, col.g, col.b, 0.4)
			lab.outline_size = 18
			lab.shaded = false
			lab.double_sided = false
			lab.fixed_size = false
			var sy := rng.randf_range(10.0, minf(h - 8.0, 45.0))
			var p = base + tangent * rng.randf_range(-along * 0.6, along * 0.6) + Vector3.UP * sy
			lab.transform = Transform3D(Basis.looking_at(-nrm, Vector3.UP), p)
			add_child(lab)
			if lights < max_lights and rng.randf() < 0.6:
				var l := OmniLight3D.new()
				l.light_color = col
				l.light_energy = 3.0
				l.omni_range = 18.0
				l.position = p + nrm * 3.0
				add_child(l)
				lights += 1
		elif roll < 0.58 and holos < 32 and h > 30.0:
			holos += 1
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			var w := minf(along * 1.6, rng.randf_range(12.0, 24.0))
			qm.size = Vector2(w, w * rng.randf_range(0.6, 1.4))
			q.mesh = qm
			var hm := ShaderMaterial.new()
			hm.shader = holo_shader
			hm.set_shader_parameter("col_a", _rand_neon())
			hm.set_shader_parameter("col_b", _rand_neon())
			hm.set_shader_parameter("seed", rng.randf() * 10.0)
			hm.set_shader_parameter("pattern", rng.randi() % 4)
			q.material_override = hm
			var p2 = base + nrm * 0.5 + Vector3.UP * rng.randf_range(qm.size.y * 0.5 + 12.0, maxf(qm.size.y * 0.5 + 14.0, minf(h - qm.size.y * 0.5, 70.0)))
			q.transform = Transform3D(Basis.looking_at(-nrm, Vector3.UP), p2)
			add_child(q)
		elif roll < 0.75 and h > 15.0:
			var col2 := _rand_neon()
			var lab2 := Label3D.new()
			lab2.text = HSIGNS[rng.randi() % HSIGNS.size()]
			lab2.font_size = 72
			lab2.pixel_size = 0.03
			lab2.modulate = Color(col2.r * 2.0, col2.g * 2.0, col2.b * 2.0)
			lab2.outline_size = 14
			lab2.outline_modulate = Color(col2.r, col2.g, col2.b, 0.35)
			lab2.shaded = false
			lab2.double_sided = false
			lab2.transform = Transform3D(Basis.looking_at(-nrm, Vector3.UP), base + Vector3.UP * rng.randf_range(5.0, 9.0))
			add_child(lab2)


func _vertical(w: String) -> String:
	var out := ""
	for k in w.length():
		if k > 0:
			out += "\n"
		out += w[k]
	return out


func _traffic_build() -> void:
	var count := 150 if quality > 0 else 70
	_traffic_mm = MultiMesh.new()
	_traffic_mm.transform_format = MultiMesh.TRANSFORM_3D
	_traffic_mm.use_custom_data = true
	_traffic_mm.mesh = BoxMesh.new()
	_traffic_mm.instance_count = count
	var b: Rect2 = track.bounds.grow(500.0)
	var dirs := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
		Vector3(1, 0, 1).normalized(), Vector3(-1, 0, -1).normalized()]
	for k in count:
		var lane := rng.randi() % 5
		var d: Vector3 = dirs[rng.randi() % dirs.size()]
		var pos := Vector3(rng.randf_range(b.position.x, b.end.x), float(def.get("base_y", 40.0)) + 40.0 + lane * 24.0 + rng.randf_range(-3, 3), rng.randf_range(b.position.y, b.end.y))
		var police := rng.randf() < 0.08
		_traffic.append({"p": pos, "d": d, "s": rng.randf_range(25.0, 60.0), "bob": rng.randf() * TAU})
		_traffic_mm.set_instance_custom_data(k, Color(0.95 if police else 0.0, rng.randf(), rng.randf(), 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _traffic_mm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/traffic.gdshader")
	mmi.material_override = sm
	mmi.custom_aabb = AABB(Vector3(b.position.x, 0, b.position.y), Vector3(b.size.x, 300, b.size.y))
	add_child(mmi)
	_update_traffic(0.0)


func _update_traffic(delta: float) -> void:
	var b: Rect2 = track.bounds.grow(500.0)
	for k in _traffic.size():
		var t: Dictionary = _traffic[k]
		var p: Vector3 = t["p"] + t["d"] * t["s"] * delta
		if p.x < b.position.x: p.x = b.end.x
		elif p.x > b.end.x: p.x = b.position.x
		if p.z < b.position.y: p.z = b.end.y
		elif p.z > b.end.y: p.z = b.position.y
		t["p"] = p
		t["bob"] += delta
		var bp := p + Vector3.UP * sin(t["bob"] * 0.7) * 0.8
		var bs := Basis.looking_at(t["d"], Vector3.UP).scaled(Vector3(2.4, 0.9, 5.2))
		_traffic_mm.set_instance_transform(k, Transform3D(bs, bp))


func _blimp_build() -> void:
	_blimp = Node3D.new()
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	body.mesh = sm
	body.scale = Vector3(22, 22, 70)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.1)
	m.metallic = 0.6
	m.roughness = 0.4
	body.material_override = m
	_blimp.add_child(body)
	for side in [-1.0, 1.0]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(70, 26)
		q.mesh = qm
		var hm := ShaderMaterial.new()
		hm.shader = load("res://shaders/holo.gdshader")
		hm.set_shader_parameter("col_a", def["neon"])
		hm.set_shader_parameter("col_b", def["neon2"])
		hm.set_shader_parameter("pattern", 1)
		q.material_override = hm
		q.position = Vector3(side * 22.5, -2, 0)
		q.rotation.y = side * PI * 0.5
		_blimp.add_child(q)
	var l := SpotLight3D.new()
	l.rotation.x = -PI * 0.5
	l.spot_range = 260.0
	l.spot_angle = 12.0
	l.light_energy = 6.0
	l.light_color = Color(0.8, 0.9, 1.0)
	l.position = Vector3(0, -22, 10)
	l.light_volumetric_fog_energy = 4.0
	_blimp.add_child(l)
	add_child(_blimp)


func _chimneys() -> void:
	for k in 4:
		var ang := TAU * k / 4.0 + rng.randf_range(-0.4, 0.4)
		var c = track.bounds.get_center() + Vector2.from_angle(ang) * (track.bounds.size.length() * 0.5 + rng.randf_range(250.0, 450.0))
		var h := rng.randf_range(110.0, 170.0)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 4.0
		cm.bottom_radius = 9.0
		cm.height = h
		mi.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.06, 0.05, 0.05)
		mi.material_override = m
		mi.position = Vector3(c.x, h * 0.5, c.y)
		add_child(mi)
		var fire := GPUParticles3D.new()
		fire.amount = 60
		fire.lifetime = 1.4
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 12.0
		pm.initial_velocity_min = 14.0
		pm.initial_velocity_max = 22.0
		pm.gravity = Vector3(2, 4, 0)
		pm.scale_min = 4.0
		pm.scale_max = 8.0
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 2.5
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.85, 0.4, 1))
		grad.set_color(1, Color(0.8, 0.15, 0.0, 0))
		var gt := GradientTexture1D.new()
		gt.gradient = grad
		pm.color_ramp = gt
		fire.process_material = pm
		var qm := QuadMesh.new()
		qm.size = Vector2(1, 1)
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		fm.vertex_color_use_as_albedo = true
		fm.albedo_texture = _soft_dot()
		qm.material = fm
		fire.draw_pass_1 = qm
		fire.position = Vector3(c.x, h + 2.0, c.y)
		fire.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 80, 80))
		add_child(fire)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.5, 0.15)
		l.light_energy = 8.0
		l.omni_range = 120.0
		l.position = fire.position + Vector3.UP * 8.0
		add_child(l)


static var _dot_tex: Texture2D

static func _soft_dot() -> Texture2D:
	if _dot_tex != null:
		return _dot_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	_dot_tex = gt
	return gt


func make_rain(parent: Node3D) -> void:
	if not def["rain"]:
		return
	_rain = GPUParticles3D.new()
	_rain.amount = 5000 if quality > 0 else 1800
	_rain.lifetime = 1.0
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(Vector3(-60, -40, -60), Vector3(120, 80, 120))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(45, 1, 45)
	pm.direction = Vector3(0.05, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 38.0
	pm.initial_velocity_max = 46.0
	pm.gravity = Vector3(0, -9.8, 0)
	_rain.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.025, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.7, 0.8, 1.0, 0.28)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	qm.material = m
	_rain.draw_pass_1 = qm
	_rain.position = Vector3(0, 22, -12)
	parent.add_child(_rain)


func _process(delta: float) -> void:
	_t += delta
	_update_traffic(delta)
	for b in _beams:
		var node: Node3D = b[0]
		node.rotation = Vector3(0.85 + sin(_t * b[1] + b[2]) * 0.3, _t * b[1] * 0.6 + b[2], 0)
	_blimp_t += delta * 0.012
	var c: Vector2 = track.bounds.get_center()
	var r: float = track.bounds.size.length() * 0.35 + 120.0
	var bp := Vector3(c.x + cos(_blimp_t) * r, 150.0, c.y + sin(_blimp_t) * r)
	_blimp.position = bp
	_blimp.look_at(bp + Vector3(-sin(_blimp_t), 0, cos(_blimp_t)), Vector3.UP)
	var blink := 8.0 if fmod(Time.get_ticks_msec() / 1000.0, 1.6) < 0.5 else 0.6
	for m in _blinkers:
		m.emission_energy_multiplier = blink


## Svävare som följer banan på sidan och ovanför, åt båda hållen.
func _escorts_build() -> void:
	var count := 36 if quality > 0 else 18
	_esc_mm = MultiMesh.new()
	_esc_mm.transform_format = MultiMesh.TRANSFORM_3D
	_esc_mm.use_custom_data = true
	_esc_mm.mesh = BoxMesh.new()
	_esc_mm.instance_count = count
	var hw: float = track.width * 0.5
	for k in count:
		var side := -1.0 if k % 2 == 0 else 1.0
		var e := {
			"s": rng.randf() * track.length,
			"v": rng.randf_range(18.0, 50.0) * (1.0 if rng.randf() < 0.6 else -1.0),
			"lat": side * rng.randf_range(hw + 14.0, hw + 40.0),
			"h": rng.randf_range(4.0, 28.0),
			"ph": rng.randf() * TAU,
		}
		_escorts.append(e)
		_esc_mm.set_instance_custom_data(k, Color(0.95 if rng.randf() < 0.12 else 0.0, rng.randf(), 1.0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _esc_mm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/traffic.gdshader")
	mmi.material_override = sm
	var b: Rect2 = track.bounds.grow(200.0)
	mmi.custom_aabb = AABB(Vector3(b.position.x, -50, b.position.y), Vector3(b.size.x, 300, b.size.y))
	add_child(mmi)
	_update_escorts(0.0)


func _update_escorts(delta: float) -> void:
	for k in _escorts.size():
		var e: Dictionary = _escorts[k]
		e["s"] = fposmod(e["s"] + e["v"] * delta, track.length)
		var i: int = track.idx_at(e["s"])
		var p: Vector3 = track.point_at(e["s"], e["lat"]) + Vector3.UP * (e["h"] + sin(_t * 0.8 + e["ph"]) * 1.2)
		var t: Vector3 = track.tans[i] * signf(e["v"])
		var bs := Basis.looking_at(t, Vector3.UP).scaled(Vector3(2.2, 0.8, 4.8))
		_esc_mm.set_instance_transform(k, Transform3D(bs, p))


## Strålkastare som sveper över himlen från taken.
func _searchlights() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 22.0
	cone.bottom_radius = 0.6
	cone.height = 420.0
	cone.radial_segments = 16
	cone.cap_top = false
	cone.cap_bottom = false
	var count := 7
	for k in count:
		var ang := TAU * k / count + rng.randf_range(-0.3, 0.3)
		var c: Vector2 = track.bounds.get_center() + Vector2.from_angle(ang) * (track.bounds.size.length() * 0.5 + rng.randf_range(80.0, 300.0))
		var pivot := Node3D.new()
		pivot.position = Vector3(c.x, rng.randf_range(90.0, 200.0), c.y)
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.position = Vector3(0, 0, -210.0)
		mi.rotation.x = -PI * 0.5
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		var col: Color = Color(0.75, 0.85, 1.0) if k % 3 != 0 else Color(def["neon"])
		m.albedo_color = Color(col.r, col.g, col.b, 0.07)
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 20.0
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		add_child(pivot)
		_beams.append([pivot, rng.randf_range(0.15, 0.35), rng.randf() * TAU])


## Kyrktorn med kopparspiror och ett tegeltorn, som landmärken på dagbanan.
func _landmarks() -> void:
	var placed := 0
	var tries := 0
	var occ := {}
	while placed < 4 and tries < 400:
		tries += 1
		var i: int = rng.randi() % int(track.n)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var p: Vector3 = track.pts[i] + track.rgts[i] * side * rng.randf_range(60.0, 180.0)
		var c := Vector2(p.x, p.z)
		if not track.clear_of_track(c, 14.0) or not track.is_land(c):
			continue
		var ok := true
		for o in occ:
			if c.distance_to(o) < 250.0:
				ok = false
		if not ok:
			continue
		occ[c] = true
		var brick := placed == 2
		var tw := 14.0 if brick else 10.0
		var th := rng.randf_range(55.0, 75.0) if brick else rng.randf_range(35.0, 48.0)
		var wall := StandardMaterial3D.new()
		wall.albedo_color = Color(0.55, 0.24, 0.16) if brick else Color(0.86, 0.72, 0.45)
		wall.roughness = 0.85
		var tower := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(tw, th, tw)
		tower.mesh = bm
		tower.material_override = wall
		tower.position = Vector3(c.x, th * 0.5, c.y)
		add_child(tower)
		var spire := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = tw * 0.72
		cm.height = th * (0.35 if brick else 0.7)
		cm.radial_segments = 4
		cm.rings = 1
		spire.mesh = cm
		var cu := StandardMaterial3D.new()
		cu.albedo_color = Color(0.36, 0.6, 0.5)
		cu.metallic = 0.5
		cu.roughness = 0.45
		spire.material_override = cu
		spire.rotation.y = PI * 0.25
		spire.position = Vector3(c.x, th + cm.height * 0.5, c.y)
		add_child(spire)
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.9
		sm.height = 1.8
		ball.mesh = sm
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(1.0, 0.8, 0.35)
		gold.metallic = 1.0
		gold.roughness = 0.2
		ball.material_override = gold
		ball.position = Vector3(c.x, th + cm.height + 0.6, c.y)
		add_child(ball)
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		cs.shape = bs
		cs.position = tower.position
		sb.add_child(cs)
		add_child(sb)
		placed += 1


# ---------------------------------------------------------------- Kenney-hus (dagbanan)

func _load_kenney() -> void:
	_kmodels.clear()
	for k in KENNEY:
		if not ResourceLoader.exists(k[0]):
			continue
		var ps = load(k[0])
		if not (ps is PackedScene):
			continue
		var inst: Node = ps.instantiate()
		var found := _find_mesh(inst, Transform3D.IDENTITY)
		inst.free()
		if found.is_empty():
			continue
		var mesh: Mesh = found[0]
		var orig: Material = found[2]
		var m := StandardMaterial3D.new()
		if orig is BaseMaterial3D:
			m.albedo_texture = (orig as BaseMaterial3D).albedo_texture
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		var xf: Transform3D = found[1]
		_kmodels.append([mesh, xf, xf * mesh.get_aabb(), m, k[1]])


func _find_mesh(n: Node, xf: Transform3D) -> Array:
	var x2 := xf
	if n is Node3D:
		x2 = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		var mat: Material = mi.get_active_material(0)
		return [mi.mesh, x2, mat]
	for c in n.get_children():
		var r := _find_mesh(c, x2)
		if not r.is_empty():
			return r
	return []


## Försöker ställa ett Kenney-hus på platsen, vänt mot banan.
func _try_kenney(tp: Vector3, c: Vector2, fp: float, occ: Dictionary) -> bool:
	var mi := rng.randi() % _kmodels.size()
	var km: Array = _kmodels[mi]
	var ab: AABB = km[2]
	var sc := minf(fp / maxf(ab.size.x, 0.01), 32.0 / maxf(ab.size.y, 0.01))
	sc = maxf(sc, 8.0)
	var rad := Vector2(ab.size.x, ab.size.z).length() * 0.5 * sc
	if not _place_ok(c, rad, occ):
		return false
	var to := Vector2(tp.x, tp.z) - c
	var yaw := atan2(to.x, to.y)
	var b := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sc, sc, sc))
	var center := Vector3(ab.get_center().x, ab.position.y, ab.get_center().z)
	var origin := Vector3(c.x, 0.0, c.y) - b * center
	var xf := Transform3D(b, origin) * (km[1] as Transform3D)
	var col: Color = STHLM[rng.randi() % STHLM.size()].lerp(Color.WHITE, km[4])
	_khouses.append([mi, xf, col, ab, sc, yaw, Vector2(c.x, c.y)])
	_occupy(c, rad, occ)
	return true


func _build_kenney() -> void:
	if _khouses.is_empty():
		return
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	add_child(sb)
	for mi in _kmodels.size():
		var items := _khouses.filter(func(h): return h[0] == mi)
		if items.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _kmodels[mi][0]
		mm.instance_count = items.size()
		for k in items.size():
			mm.set_instance_transform(k, items[k][1])
			mm.set_instance_color(k, items[k][2])
			var ab: AABB = items[k][3]
			var sc: float = items[k][4]
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = ab.size * sc
			cs.shape = bs
			cs.transform = Transform3D(Basis(Vector3.UP, items[k][5]), Vector3(items[k][6].x, bs.size.y * 0.5, items[k][6].y))
			sb.add_child(cs)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _kmodels[mi][3]
		add_child(mmi)
