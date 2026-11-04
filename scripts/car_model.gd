extends RefCounted
## Bygger bilarnas utseende av delarna i car_types.gd.

const CarTypes = preload("res://scripts/car_types.gd")
const Geo = preload("res://scripts/geo.gd")

static var _mesh_cache: Dictionary = {}


static func build(type_id: int, paint: Color, accent: Color) -> Dictionary:
	var t: Dictionary = CarTypes.TYPES[type_id]
	var root := Node3D.new()
	root.name = "Model"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	var mats := _materials(paint, accent)
	var loose: Array = []
	var parts: Array = t["parts"]
	# Egen modell? Lägg models/<namn>.glb/.gltf/.fbx (t.ex. models/vektor.glb) så används den istället.
	var kres := _kenney_car(t, paint)
	var custom: Node3D = null
	if not kres.is_empty():
		custom = kres["holder"]
		body.add_child(custom)
		parts = []
		_custom_lights(custom, body, mats)
	else:
		custom = _custom_model(String(t["name"]), t)
	if custom != null and kres.is_empty():
		body.add_child(custom)
		parts = []
		_paint_custom(custom, mats)
		_custom_lights(custom, body, mats)
	for i in parts.size():
		var p: Array = parts[i]
		var key := "%d_%d" % [type_id, i]
		var mesh: Mesh = _mesh_cache.get(key)
		var mi := MeshInstance3D.new()
		match p[0]:
			"hull":
				if mesh == null:
					mesh = _hull_mesh(p[2], p[3])
				mi.mesh = mesh
			"box":
				if mesh == null:
					var bm := BoxMesh.new()
					bm.size = p[2]
					mesh = bm
				mi.mesh = mesh
				mi.position = p[3]
			"cyl":
				if mesh == null:
					var cm := CylinderMesh.new()
					cm.top_radius = p[2]
					cm.bottom_radius = p[2]
					cm.height = p[3]
					cm.radial_segments = 12
					mesh = cm
				mi.mesh = mesh
				mi.position = p[4]
				match p[5]:
					"x": mi.rotation.z = PI * 0.5
					"z": mi.rotation.x = PI * 0.5
		_mesh_cache[key] = mesh
		mi.material_override = mats[p[1]]
		body.add_child(mi)
		if p[p.size() - 1] == true:
			loose.append(mi)

	# Hjul
	var wheels: Array = []
	var r: float = t["wheel_r"]
	var w: float = t["wheel_w"]
	var zs: Array = [t["wheel_zf"], t["wheel_zb"]]
	for ez in t["extra_wheels"]:
		zs.append(ez)
	var wkey := "wheel_%d" % type_id
	if not _mesh_cache.has(wkey):
		_mesh_cache[wkey] = _wheel_meshes(r, w)
	var wm: Array = _mesh_cache[wkey]
	if custom != null:
		zs = []
	if not kres.is_empty():
		wheels = kres["wheels"]
	for zi in zs.size():
		for side in [-1, 1]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * float(t["wheel_x"]), r, float(zs[zi]))
			var spin := Node3D.new()
			pivot.add_child(spin)
			var tyre := MeshInstance3D.new()
			tyre.mesh = wm[0]
			tyre.rotation.z = PI * 0.5
			tyre.material_override = mats["tyre"]
			spin.add_child(tyre)
			var rim := MeshInstance3D.new()
			rim.mesh = wm[1]
			rim.rotation.z = PI * 0.5
			rim.material_override = mats["rim"]
			spin.add_child(rim)
			var spoke := MeshInstance3D.new()
			spoke.mesh = wm[2]
			spoke.material_override = mats["accent"]
			spin.add_child(spoke)
			root.add_child(pivot)
			wheels.append({"pivot": pivot, "spin": spin, "front": zi == 0, "z": float(zs[zi]), "x": side * float(t["wheel_x"])})

	# Strålkastare
	var sl := SpotLight3D.new()
	sl.position = Vector3(0, 0.7, -float(t["box"].z) * 0.5 - 0.1)
	sl.rotation.x = deg_to_rad(-8)
	sl.spot_range = 55.0
	sl.spot_angle = 38.0
	sl.spot_attenuation = 0.8
	sl.light_energy = 3.0
	sl.light_color = Color(0.85, 0.92, 1.0)
	sl.shadow_enabled = false
	root.add_child(sl)
	var tl := OmniLight3D.new()
	tl.position = Vector3(0, 0.7, float(t["box"].z) * 0.5 + 0.4)
	tl.omni_range = 5.0
	tl.light_energy = 0.3
	tl.light_color = Color(1.0, 0.1, 0.1)
	root.add_child(tl)
	# Neonljus under bilen: lyser upp vägen runt bilen så att den syns mot asfalten
	var ug := OmniLight3D.new()
	ug.position = Vector3(0, 0.25, 0)
	ug.omni_range = 3.2
	ug.omni_attenuation = 1.5
	ug.light_energy = 0.6
	ug.light_color = accent
	ug.shadow_enabled = false
	root.add_child(ug)

	# Boostlågor
	var flames := Node3D.new()
	flames.visible = false
	var bz: float = float(t["box"].z) * 0.5
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.17
	cone.height = 1.3
	cone.radial_segments = 8
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.albedo_color = Color(accent.r * 0.6 + 0.4, accent.g * 0.6 + 0.3, accent.b * 0.6 + 0.2)
	fm.emission_enabled = true
	for side in [-0.45, 0.45]:
		var f := MeshInstance3D.new()
		f.mesh = cone
		f.material_override = fm
		f.rotation.x = PI * 0.5
		f.position = Vector3(side, 0.42, bz + 0.7)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.add_child(f)
	root.add_child(flames)

	var res := {"root": root, "body": body, "wheels": wheels, "loose": loose, "mats": mats, "lights": [sl, tl, ug], "flames": flames}
	if not kres.is_empty():
		res["kmat"] = kres["mat"]
		res["kscale"] = kres["scale"]
		res["loose"] = kres["loose"]
	return res


## Kenneys bilar (assets/bilar). Hjulen blir egna noder som snurrar och svänger.
static func _kenney_car(t: Dictionary, paint: Color) -> Dictionary:
	if not t.has("kenney"):
		return {}
	var path: String = t["kenney"][0]
	if not ResourceLoader.exists(path):
		return {}
	var ps = load(path)
	if not (ps is PackedScene):
		return {}
	var inst: Node3D = ps.instantiate()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/kenney_car.gdshader")
	mat.set_shader_parameter("colormap", load("res://assets/bilar/Textures/colormap.png"))
	mat.set_shader_parameter("body_cell", int(t["kenney"][1]))
	mat.set_shader_parameter("paint", paint)
	_set_mat(inst, mat)
	var aabb := _aabb_of(inst, Transform3D.IDENTITY)
	var k: float = float(t["box"].z) / maxf(aabb.size.z, 0.01)
	var holder := Node3D.new()
	# Kenneys bilar har fronten åt +Z, spelet åt -Z
	holder.basis = Basis(Vector3.UP, PI) * Basis.from_scale(Vector3(k, k, k))
	inst.position = Vector3(-aabb.get_center().x, -aabb.position.y, -aabb.get_center().z)
	holder.add_child(inst)
	var wheels: Array = []
	var loose: Array = []
	for c in inst.get_children():
		var nm := String(c.name)
		if nm.begins_with("wheel") and c is Node3D:
			var w := c as Node3D
			var pivot := Node3D.new()
			pivot.position = w.position
			var spin := Node3D.new()
			pivot.add_child(spin)
			inst.add_child(pivot)
			var keep := w.basis
			inst.remove_child(w)
			w.transform = Transform3D(keep, Vector3.ZERO)
			spin.add_child(w)
			wheels.append({"pivot": pivot, "spin": spin, "front": nm.contains("front"), "x": -w.position.x, "z": 0.0, "kenney": true})
		elif nm == "spoiler" or nm == "grill":
			loose.append(c)
	return {"holder": holder, "wheels": wheels, "mat": mat, "scale": k, "loose": loose}


static func _set_mat(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = m
	for c in n.get_children():
		_set_mat(c, m)


static func _custom_model(name_s: String, t: Dictionary) -> Node3D:
	var path := ""
	for ext in ["glb", "gltf", "fbx"]:
		var cand := "res://models/%s.%s" % [name_s.to_lower().replace("-", ""), ext]
		if ResourceLoader.exists(cand):
			path = cand
			break
	if path == "":
		return null
	var ps = load(path)
	if not (ps is PackedScene):
		return null
	var inst: Node3D = ps.instantiate()
	var holder := Node3D.new()
	holder.add_child(inst)
	# Skala så att modellen blir lika lång som bilens krocklåda och står på marken
	var aabb := _aabb_of(inst, Transform3D.IDENTITY)
	if aabb.size.length() > 0.01:
		var k: float = float(t["box"].z) / maxf(aabb.size.z, 0.01)
		holder.scale = Vector3(k, k, k)
		inst.position = Vector3(-aabb.get_center().x, -aabb.position.y, -aabb.get_center().z)
	return holder


## Delarna i de konverterade modellerna heter paint, glass, tyre, rim och dark.
## De får spelets material, så att lacken kan färgas och mörkna vid skador.
static func _paint_custom(n: Node, mats: Dictionary) -> void:
	if n is MeshInstance3D:
		var nm := String(n.name).to_lower()
		for key in ["paint", "glass", "tyre", "rim", "dark"]:
			if nm.begins_with(key):
				(n as MeshInstance3D).material_override = mats[key]
	for c in n.get_children():
		_paint_custom(c, mats)


## Strålkastare och bakljus läggs på modellens front och bakdel.
static func _custom_lights(holder: Node3D, body: Node3D, mats: Dictionary) -> void:
	var a := _aabb_of(holder, Transform3D.IDENTITY)
	a = AABB(a.position, a.size)
	var hl := a.size.y * 0.42
	for side in [-1.0, 1.0]:
		var hm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(a.size.x * 0.18, 0.06, 0.08)
		hm.mesh = bm
		hm.material_override = mats["head"]
		hm.position = Vector3(side * a.size.x * 0.3, hl, a.position.z + 0.12)
		body.add_child(hm)
	var tm := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(a.size.x * 0.75, 0.07, 0.08)
	tm.mesh = tb
	tm.material_override = mats["tail"]
	tm.position = Vector3(0, a.size.y * 0.5, a.end.z - 0.1)
	body.add_child(tm)


static func _aabb_of(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var x2 := xf
	if n is Node3D:
		x2 = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = x2 * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for c in n.get_children():
		var a := _aabb_of(c, x2)
		if a.size.length() > 0.0:
			out = a if first else out.merge(a)
			first = false
	return out


static func _materials(paint: Color, accent: Color) -> Dictionary:
	var m := {}
	var p := StandardMaterial3D.new()
	p.albedo_color = paint
	p.metallic = 0.3
	p.roughness = 0.32
	p.clearcoat_enabled = true
	p.clearcoat = 0.8
	p.clearcoat_roughness = 0.1
	m["paint"] = p
	var p2 := p.duplicate()
	p2.albedo_color = paint.darkened(0.3)
	m["paint2"] = p2
	m["dark"] = _std(Color(0.05, 0.05, 0.06), 0.3, 0.55)
	m["metal"] = _std(Color(0.45, 0.46, 0.5), 0.9, 0.3)
	var g := _std(Color(0.03, 0.05, 0.09), 0.4, 0.05)
	g.emission_enabled = true
	g.emission = Color(0.05, 0.12, 0.2)
	m["glass"] = g
	m["head"] = _glow(Color(0.85, 0.95, 1.0), 2.2)
	m["tail"] = _glow(Color(1.0, 0.05, 0.08), 1.6)
	m["accent"] = _glow(accent, 2.0)
	m["amber"] = _glow(Color(1.0, 0.6, 0.05), 2.0)
	m["tyre"] = _std(Color(0.03, 0.03, 0.03), 0.0, 0.85)
	m["rim"] = _std(Color(0.3, 0.3, 0.33), 0.9, 0.25)
	return m


static func _std(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.metallic = metal
	s.roughness = rough
	return s


static func _glow(c: Color, e: float) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.emission_enabled = true
	s.emission = c
	s.emission_energy_multiplier = e
	return s


static func _wheel_meshes(r: float, w: float) -> Array:
	var tyre := CylinderMesh.new()
	tyre.top_radius = r
	tyre.bottom_radius = r
	tyre.height = w
	tyre.radial_segments = 18
	var rim := CylinderMesh.new()
	rim.top_radius = r * 0.62
	rim.bottom_radius = r * 0.62
	rim.height = w + 0.03
	rim.radial_segments = 12
	var spoke := BoxMesh.new()
	spoke.size = Vector3(w + 0.05, r * 1.15, 0.07)
	return [tyre, rim, spoke]


## Sex sidor mellan en bottenyta och en toppyta. Varje yta: [zf, zb, wf, wb, yf, yb].
static func _hull_mesh(b: Array, t: Array) -> ArrayMesh:
	var bfl := Vector3(-b[2] * 0.5, b[4], b[0])
	var bfr := Vector3(b[2] * 0.5, b[4], b[0])
	var bbr := Vector3(b[3] * 0.5, b[5], b[1])
	var bbl := Vector3(-b[3] * 0.5, b[5], b[1])
	var tfl := Vector3(-t[2] * 0.5, t[4], t[0])
	var tfr := Vector3(t[2] * 0.5, t[4], t[0])
	var tbr := Vector3(t[3] * 0.5, t[5], t[1])
	var tbl := Vector3(-t[3] * 0.5, t[5], t[1])
	var c := (bfl + bfr + bbr + bbl + tfl + tfr + tbr + tbl) / 8.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [
		[tfl, tfr, tbr, tbl], [bfl, bbl, bbr, bfr], [bfl, bfr, tfr, tfl],
		[bbl, tbl, tbr, bbr], [bfl, tfl, tbl, bbl], [bfr, bbr, tbr, tfr],
	]
	for f in faces:
		var fc: Vector3 = (f[0] + f[1] + f[2] + f[3]) * 0.25
		Geo.quad(st, f[0], f[1], f[2], f[3], fc - c)
	return st.commit()
