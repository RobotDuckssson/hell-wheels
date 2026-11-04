extends Node3D
## Bygger en bana: mittlinje, vägbana, räcken med neon, lyktstolpar, pelare,
## tunnlar, startportal och kurvskyltar. Har också hjälpfunktioner för
## var på banan en bil befinner sig.

const Geo = preload("res://scripts/geo.gd")
const STEP := 2.0
const CELL := 25.0
const WALL_H := 1.6
const WALL_T := 0.7
const TUNNEL_H := 8.5

var def: Dictionary
var width := 18.0
var pts := PackedVector3Array()
var tans := PackedVector3Array()
var rgts := PackedVector3Array()
var dists := PackedFloat32Array()
var radius := PackedFloat32Array()
var tunnel := PackedByteArray()
var gap := PackedByteArray()       # ingen vägbana (lucka efter hoppramp)
var open := PackedByteArray()      # inga räcken
var jump_zones: Array = []         # [ramp_start, landning_slut, krön]
var jump_lips: Array = []          # [index vid krönet, index där landningen börjar]
var _gates: Array = []
var _gate_t := 0.0
var length := 0.0
var n := 0
var grid: Dictionary = {}
var start_lights: Array = []
var min_y := 0.0
var max_y := 0.0
var lamp_lights: Array = []
var bounds := Rect2()

var _faces := PackedVector3Array()


func build(d: Dictionary, quality: int) -> void:
	def = d
	width = d["width"]
	_make_path()
	_make_grid()
	_build_ground()
	_build_road()
	_build_lamps(quality)
	_build_pillars()
	_build_tunnels(quality)
	_build_gantry()
	_build_corner_signs()
	_build_jumps()
	_build_gates()
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.backface_collision = true
	sh.set_faces(_faces)
	cs.shape = sh
	sb.add_child(cs)
	add_child(sb)


# ---------------------------------------------------------------- mittlinjen

func _make_path() -> void:
	var P: Array = def["points"]
	var cnt := P.size()
	var dense: Array[Vector2] = []
	var apex: Array[int] = []
	var seg_start: Array[int] = []   # index i dense där raksträckan efter hörn i börjar
	var seg_end: Array[int] = []     # index där hörn i börjar (slutet på raksträckan före)
	for i in cnt:
		var p := Vector2(P[i][0], P[i][1])
		var pp := Vector2(P[(i - 1 + cnt) % cnt][0], P[(i - 1 + cnt) % cnt][1])
		var pn := Vector2(P[(i + 1) % cnt][0], P[(i + 1) % cnt][1])
		var d1 := (p - pp).normalized()
		var d2 := (pn - p).normalized()
		var cr := d1.cross(d2)
		var th := acos(clampf(d1.dot(d2), -1.0, 1.0))
		var r := float(P[i][3])
		seg_end.append(dense.size())
		if r <= 0.0 or th < 0.01:
			apex.append(dense.size())
			dense.append(p)
		else:
			var t := r * tan(th * 0.5)
			var lim := 0.45 * minf((p - pp).length(), (pn - p).length())
			if t > lim:
				t = lim
				r = t / tan(th * 0.5)
			var e := p - d1 * t
			var perp := Vector2(-d1.y, d1.x) * signf(cr)
			var c := e + perp * r
			var a0 := (e - c).angle()
			var sweep := signf(cr) * th
			var steps := maxi(3, int(ceil(r * th / 1.0)))
			for k in steps + 1:
				if k == steps / 2:
					apex.append(dense.size())
				dense.append(c + Vector2.from_angle(a0 + sweep * float(k) / steps) * r)
		seg_start.append(dense.size() - 1)

	# Kumulativ längd längs den täta linjen
	var cum := PackedFloat32Array()
	cum.resize(dense.size() + 1)
	cum[0] = 0.0
	for i in dense.size():
		var a: Vector2 = dense[i]
		var b: Vector2 = dense[(i + 1) % dense.size()]
		cum[i + 1] = cum[i] + a.distance_to(b)
	var total := cum[dense.size()]
	n = int(round(total / STEP))
	var step := total / n
	var apex_s: Array[float] = []
	for ai in apex:
		apex_s.append(cum[ai])
	var tun_ranges: Array = []
	for ti in def.get("tunnels", []):
		var s0 := cum[seg_start[ti]] + 6.0
		var s1 := cum[seg_end[(ti + 1) % cnt]] - 6.0
		tun_ranges.append([s0, s1])

	pts.resize(n)
	dists.resize(n)
	tunnel.resize(n)
	gap.resize(n)
	open.resize(n)
	var open_ranges: Array = []
	for oi in def.get("open", []):
		open_ranges.append([cum[seg_start[oi]] + 4.0, cum[seg_end[(oi + 1) % cnt]] - 4.0])
	var jumps: Array = []
	for jd in def.get("jumps", []):
		var a0 := cum[seg_start[jd[0]]]
		var a1 := cum[seg_end[(jd[0] + 1) % cnt]]
		if a1 < a0:
			a1 += total
		var lip := (a0 + a1) * 0.5 + 10.0
		jumps.append([lip, float(jd[1])])
		jump_zones.append([lip - 45.0, lip + float(jd[1]) + 25.0, lip])
	var base_y: float = def.get("base_y", 0.0)
	var j := 0
	min_y = 1e9
	max_y = -1e9
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for i in n:
		var s := i * step
		while j < dense.size() - 1 and cum[j + 1] < s:
			j += 1
		var a: Vector2 = dense[j]
		var b: Vector2 = dense[(j + 1) % dense.size()]
		var seg_len := cum[j + 1] - cum[j]
		var f := 0.0 if seg_len < 1e-5 else (s - cum[j]) / seg_len
		var xz := a.lerp(b, f)
		var y := _height_at(s, apex_s, P, total) + base_y
		var gf := 0
		for jp in jumps:
			var lip: float = jp[0]
			var g: float = jp[1]
			var ds := fposmod(s - lip + total * 0.5, total) - total * 0.5   # avstånd till krönet
			if ds > -32.0 and ds <= 0.0:
				var fr := (ds + 32.0) / 32.0
				y += 3.2 * fr * fr
			elif ds > 0.0 and ds < g:
				gf = 1
				y += 3.2
			elif g > 0.0 and ds >= g and ds < g + 50.0:
				var f2 := (ds - g) / 50.0
				y -= 1.5 * (1.0 - f2 * f2 * (3.0 - 2.0 * f2))
			elif g <= 0.0 and ds > 0.0 and ds < 30.0:
				var f3 := ds / 30.0
				y += 3.2 * (1.0 - f3) * (1.0 - f3)
		gap[i] = gf
		var of := 0
		for orr in open_ranges:
			if s > orr[0] and s < orr[1]:
				of = 1
		open[i] = of
		pts[i] = Vector3(xz.x, y, xz.y)
		dists[i] = s
		var tf := 0
		for tr in tun_ranges:
			if s > tr[0] and s < tr[1]:
				tf = 1
		tunnel[i] = tf
		min_y = minf(min_y, y)
		max_y = maxf(max_y, y)
		mn = mn.min(xz)
		mx = mx.max(xz)
	length = total
	bounds = Rect2(mn, mx - mn)

	tans.resize(n)
	rgts.resize(n)
	radius.resize(n)
	for i in n:
		var t := (pts[(i + 1) % n] - pts[(i - 1 + n) % n]).normalized()
		tans[i] = t
		var flat := Vector3(t.x, 0, t.z).normalized()
		rgts[i] = flat.cross(Vector3.UP).normalized()
	for i in n:
		var ta := tans[(i - 4 + n) % n]
		var tb := tans[(i + 4) % n]
		var ang := absf(Vector2(ta.x, ta.z).angle_to(Vector2(tb.x, tb.z)))
		radius[i] = clampf((8.0 * STEP) / maxf(ang, 1e-4), 5.0, 5000.0)


func _height_at(s: float, apex_s: Array[float], P: Array, total: float) -> float:
	var cnt := apex_s.size()
	for i in cnt:
		var s0: float = apex_s[i]
		var s1: float = apex_s[(i + 1) % cnt]
		if i == cnt - 1:
			s1 += total
		var ss := s
		if ss < s0:
			ss += total
		if ss >= s0 and ss <= s1:
			var f := (ss - s0) / maxf(s1 - s0, 0.001)
			f = f * f * (3.0 - 2.0 * f)
			return lerpf(float(P[i][2]), float(P[(i + 1) % cnt][2]), f)
	return float(P[0][2])


func _make_grid() -> void:
	grid.clear()
	for i in n:
		var key := Vector2i(floori(pts[i].x / CELL), floori(pts[i].z / CELL))
		if not grid.has(key):
			grid[key] = PackedInt32Array()
		var arr: PackedInt32Array = grid[key]
		arr.append(i)
		grid[key] = arr


## Är en cirkel (i xz) fri från vägbanan?
## Land eller vatten (används på dagbanan). Samma formel finns i ground.gdshader.
static func land_value(x: float, z: float) -> float:
	return sin(x * 0.0045 + 1.3) + sin(z * 0.0052 + 0.7) + 0.7 * sin((x + z) * 0.0031 + 2.1) + 0.5 * sin((x - z) * 0.007 + 0.4)


static func is_land(c: Vector2) -> bool:
	return land_value(c.x, c.y) > -0.05


func clear_of_track(c: Vector2, rad: float) -> bool:
	var need := rad + width * 0.5 + WALL_T + 3.0
	var cr := int(ceil(need / CELL))
	var ck := Vector2i(floori(c.x / CELL), floori(c.y / CELL))
	for dx in range(-cr, cr + 1):
		for dz in range(-cr, cr + 1):
			var key := ck + Vector2i(dx, dz)
			if grid.has(key):
				for i in grid[key]:
					var p := pts[i]
					if Vector2(p.x, p.z).distance_squared_to(c) < need * need:
						return false
	return true


## Närmaste punkt på mittlinjen. Med hint söks bara närområdet först.
func nearest(pos: Vector3, hint := -1) -> int:
	var best := -1
	var bd := 1e18
	if hint >= 0:
		for k in range(-25, 50):
			var i := (hint + k + n) % n
			var d := pts[i].distance_squared_to(pos)
			if d < bd:
				bd = d
				best = i
		if bd < (width * 1.2) * (width * 1.2):
			return best
	var ck := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var key := ck + Vector2i(dx, dz)
			if grid.has(key):
				for i in grid[key]:
					var d := pts[i].distance_squared_to(pos)
					if d < bd:
						bd = d
						best = i
	if best >= 0:
		return best
	for i in n:
		var d := pts[i].distance_squared_to(pos)
		if d < bd:
			bd = d
			best = i
	return best


func offset_of(idx: int, pos: Vector3) -> float:
	return fposmod(dists[idx] + (pos - pts[idx]).dot(tans[idx]), length)


func idx_at(s: float) -> int:
	return int(fposmod(s, length) / length * n) % n


func point_at(s: float, lateral := 0.0) -> Vector3:
	var i := idx_at(s)
	var j := (i + 1) % n
	var f := clampf((fposmod(s, length) - dists[i]) / STEP, 0.0, 1.0)
	return pts[i].lerp(pts[j], f) + rgts[i] * lateral


func transform_at(s: float, lateral := 0.0, reverse := false) -> Transform3D:
	var i := idx_at(s)
	var t := tans[i]
	if reverse:
		t = -t
	var b := Basis.looking_at(t, Vector3.UP)
	return Transform3D(b, point_at(s, lateral) + Vector3.UP * 0.7)


# ---------------------------------------------------------------- geometri

func _q(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3, collide: bool,
		ua := Vector2(0, 0), ub := Vector2(1, 0), uc := Vector2(1, 1), ud := Vector2(0, 1)) -> void:
	if st != null:
		Geo.quad(st, a, b, c, d, hint, ua, ub, uc, ud)
	if collide:
		_faces.append_array([a, b, c, a, c, d])


func _build_ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000, 9000)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/ground.gdshader")
	sm.set_shader_parameter("neon", def["neon"])
	sm.set_shader_parameter("day", def.get("day", false))
	mi.material_override = sm
	mi.position = Vector3(bounds.get_center().x, -0.06, bounds.get_center().y)
	add_child(mi)
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	cs.position.y = -0.06
	sb.add_child(cs)
	add_child(sb)


func _build_road() -> void:
	var hw := width * 0.5
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var neon := SurfaceTool.new()
	neon.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := Vector3.UP
	for i in n:
		var j := (i + 1) % n
		var vi := dists[i]
		var vj := length if j == 0 else dists[j]
		var li := pts[i] - rgts[i] * hw
		var lj := pts[j] - rgts[j] * hw
		var ri := pts[i] + rgts[i] * hw
		var rj := pts[j] + rgts[j] * hw
		if gap[i] == 1 or gap[j] == 1:
			continue
		_q(road, li, lj, rj, ri, up, true, Vector2(0, vi), Vector2(0, vj), Vector2(1, vj), Vector2(1, vi))
		var elevated := pts[i].y > 0.5 or pts[j].y > 0.5
		var walled := open[i] == 0 and open[j] == 0
		var obs: Array = []
		for s in [-1.0, 1.0]:
			var bi = pts[i] + rgts[i] * s * hw
			var bj = pts[j] + rgts[j] * s * hw
			if not walled:
				# Ingen räcke: bara vägkanten, med en lysande varningslist
				_q(wall, bi, bj, bj - up * 1.3, bi - up * 1.3, rgts[i] * s, true)
				_q(neon, bi - up * 0.04 + rgts[i] * s * 0.02, bj - up * 0.04 + rgts[j] * s * 0.02, bj - up * 0.3 + rgts[j] * s * 0.02, bi - up * 0.3 + rgts[i] * s * 0.02, rgts[i] * s, false)
				obs.append([bi - up * 1.3, bj - up * 1.3])
				continue
			var ti = bi + up * WALL_H
			var tj = bj + up * WALL_H
			var oi = pts[i] + rgts[i] * s * (hw + WALL_T)
			var oj = pts[j] + rgts[j] * s * (hw + WALL_T)
			var oti = oi + up * WALL_H
			var otj = oj + up * WALL_H
			var obi = oi - up * 1.3
			var obj = oj - up * 1.3
			_q(wall, bi, bj, tj, ti, -rgts[i] * s, true, Vector2(vi, 0), Vector2(vj, 0), Vector2(vj, 1), Vector2(vi, 1))
			_q(wall, ti, tj, otj, oti, up, true)
			if elevated:
				_q(wall, oti, otj, obj, obi, rgts[i] * s, true)
			else:
				_q(wall, oti, otj, oj, oi, rgts[i] * s, true)
			obs.append([obi, obj])
			var inn = -rgts[i] * s * 0.02
			_q(neon, ti - up * 0.16 + inn, tj - up * 0.16 + inn, tj - up * 0.04 + inn, ti - up * 0.04 + inn, -rgts[i] * s, false)
		if elevated:
			_q(wall, obs[0][0], obs[0][1], obs[1][1], obs[1][0], -up, false)

	var rm := ShaderMaterial.new()
	rm.shader = load("res://shaders/road.gdshader")
	rm.set_shader_parameter("width", width)
	rm.set_shader_parameter("lanes", float(def["lanes"]))
	rm.set_shader_parameter("edge_color", def["neon2"])
	rm.set_shader_parameter("wetness", 0.12 if def.get("day", false) else 1.0)
	_add_mesh(road, rm)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.3, 0.3, 0.34)
	wm.metallic = 0.4
	wm.roughness = 0.35
	_add_mesh(wall, wm)
	var nm := StandardMaterial3D.new()
	nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nm.albedo_color = def["neon"]
	nm.emission_enabled = true
	nm.emission = def["neon"]
	nm.emission_energy_multiplier = 3.0
	_add_mesh(neon, nm)


func _add_mesh(st: SurfaceTool, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	return mi


func _build_lamps(quality: int) -> void:
	var every := int(40.0 / STEP)
	var hw := width * 0.5
	var xfs_pole: Array[Transform3D] = []
	var xfs_arm: Array[Transform3D] = []
	var xfs_head: Array[Transform3D] = []
	var col: Color = Color(1.0, 0.62, 0.35).lerp(def["neon2"], 0.35)
	var side := 1.0
	var max_lights := 70 if quality > 0 else 36
	var lights := 0
	for i in range(0, n, every):
		side = -side
		if tunnel[i] == 1 or gap[i] == 1 or open[i] == 1:
			continue
		var base := pts[i] + rgts[i] * side * (hw + WALL_T + 0.6)
		var pole := Transform3D(Basis.IDENTITY.scaled(Vector3(0.25, 10.0, 0.25)), base + Vector3.UP * 5.0)
		xfs_pole.append(pole)
		var inward := -rgts[i] * side
		var arm_b := Basis.looking_at(inward, Vector3.UP).scaled(Vector3(0.18, 0.18, 4.0))
		xfs_arm.append(Transform3D(arm_b, base + Vector3.UP * 9.9 + inward * 2.0))
		var head_b := Basis.looking_at(inward, Vector3.UP).scaled(Vector3(0.7, 0.18, 1.6))
		var head_p := base + Vector3.UP * 9.75 + inward * 3.6
		xfs_head.append(Transform3D(head_b, head_p))
		if lights < max_lights and (quality > 0 or (i / every) % 2 == 0) and not def.get("day", false):
			var l := OmniLight3D.new()
			l.position = head_p - Vector3.UP * 0.6
			l.omni_range = 26.0
			l.omni_attenuation = 1.2
			l.light_energy = 2.2
			l.light_color = col
			l.shadow_enabled = false
			add_child(l)
			lamp_lights.append(l)
			lights += 1
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.1)
	dark.metallic = 0.8
	dark.roughness = 0.4
	var bm := BoxMesh.new()
	_multi(bm, xfs_pole, dark)
	_multi(bm, xfs_arm, dark)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = col
	glow.emission_enabled = true
	glow.emission = col
	glow.emission_energy_multiplier = 0.4 if def.get("day", false) else 6.0
	_multi(bm, xfs_head, glow)


func _multi(mesh: Mesh, xfs: Array[Transform3D], mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for k in xfs.size():
		mm.set_instance_transform(k, xfs[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mmi


func _build_pillars() -> void:
	var xfs: Array[Transform3D] = []
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	add_child(sb)
	var hw := width * 0.5
	for i in range(0, n, 14):
		var p := pts[i]
		if p.y < 3.0 or gap[i] == 1:
			continue
		var ok := true
		for k in n:
			var dk := absi(k - i)
			dk = mini(dk, n - dk)
			if dk < 25:
				continue
			var q := pts[k]
			if q.y < p.y - 4.0 and Vector2(q.x, q.z).distance_to(Vector2(p.x, p.z)) < hw + WALL_T + 4.0:
				ok = false
				break
		if not ok:
			continue
		var h := p.y - 1.3
		xfs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(4.0, h, 4.0)), Vector3(p.x, h * 0.5, p.z)))
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 2.0
		cyl.height = h
		cs.shape = cyl
		cs.position = Vector3(p.x, h * 0.5, p.z)
		sb.add_child(cs)
	if xfs.is_empty():
		return
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.5
	cm.height = 1.0
	cm.radial_segments = 12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.15, 0.17)
	mat.roughness = 0.8
	_multi(cm, xfs, mat)


func _build_tunnels(quality: int) -> void:
	var hw := width * 0.5 + WALL_T
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	var strips: Array[Transform3D] = []
	var lights := 0
	for i in n:
		var j := (i + 1) % n
		if tunnel[i] == 0 or tunnel[j] == 0:
			continue
		any = true
		var up := Vector3.UP
		for s in [-1.0, 1.0]:
			var bi = pts[i] + rgts[i] * s * hw + up * WALL_H
			var bj = pts[j] + rgts[j] * s * hw + up * WALL_H
			_q(st, bi, bj, bj + up * (TUNNEL_H - WALL_H), bi + up * (TUNNEL_H - WALL_H), -rgts[i] * s, true)
		var li := pts[i] - rgts[i] * hw + up * TUNNEL_H
		var lj := pts[j] - rgts[j] * hw + up * TUNNEL_H
		var ri := pts[i] + rgts[i] * hw + up * TUNNEL_H
		var rj := pts[j] + rgts[j] * hw + up * TUNNEL_H
		_q(st, li, lj, rj, ri, -up, true)
		if i % 5 == 0:
			var b := Basis.looking_at(tans[i], Vector3.UP).scaled(Vector3(width * 0.8, 0.12, 0.5))
			strips.append(Transform3D(b, pts[i] + up * (TUNNEL_H - 0.1)))
		if i % 14 == 0 and lights < (24 if quality > 0 else 10):
			var l := OmniLight3D.new()
			l.position = pts[i] + up * (TUNNEL_H - 1.2)
			l.omni_range = 20.0
			l.light_energy = 2.0
			l.light_color = Color(def["neon"]).lerp(Color.WHITE, 0.5)
			add_child(l)
			lights += 1
	if not any:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.12)
	mat.roughness = 0.6
	mat.metallic = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(st, mat)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(def["neon"]).lerp(Color.WHITE, 0.5)
	glow.emission_enabled = true
	glow.emission = glow.albedo_color
	glow.emission_energy_multiplier = 4.0
	_multi(BoxMesh.new(), strips, glow)


func _build_gantry() -> void:
	var p := pts[0]
	var t := tans[0]
	var r := rgts[0]
	var hw := width * 0.5 + WALL_T + 1.2
	var b := Basis.looking_at(t, Vector3.UP)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.07, 0.07, 0.09)
	dark.metallic = 0.8
	dark.roughness = 0.3
	var sb := StaticBody3D.new()
	add_child(sb)
	for s in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 9.0, 1.4)
		post.mesh = bm
		post.material_override = dark
		post.global_transform = Transform3D(b, p + r * s * hw + Vector3.UP * 4.5)
		add_child(post)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		cs.shape = bs
		cs.transform = post.transform
		sb.add_child(cs)
	var beam := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(hw * 2.0 + 1.4, 1.8, 1.2)
	beam.mesh = bb
	beam.material_override = dark
	beam.transform = Transform3D(b, p + Vector3.UP * 8.6)
	add_child(beam)
	for face in [-1.0, 1.0]:
		var lab := Label3D.new()
		lab.text = "HELL WHEELS"
		lab.font_size = 160
		lab.pixel_size = 0.008
		lab.outline_size = 0
		lab.modulate = def["neon"]
		lab.shaded = false
		lab.double_sided = false
		var fb := Basis.looking_at(t * face, Vector3.UP)
		lab.transform = Transform3D(fb, p + Vector3.UP * 8.6 - t * face * 0.62)
		add_child(lab)
	# Startljus på den sida bilarna kommer ifrån
	for k in 5:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.32
		sm.height = 0.64
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.1, 0.02, 0.02)
		m.emission_enabled = true
		m.emission = Color(1, 0, 0)
		m.emission_energy_multiplier = 0.0
		mi.material_override = m
		mi.position = p + Vector3.UP * 7.35 + r * (k - 2) * 1.1 - t * 0.7
		add_child(mi)
		start_lights.append(m)


func set_start_lights(lit: int, green: bool) -> void:
	for k in start_lights.size():
		var m: StandardMaterial3D = start_lights[k]
		if green:
			m.emission = Color(0.1, 1.0, 0.3)
			m.emission_energy_multiplier = 6.0
		else:
			m.emission = Color(1.0, 0.05, 0.02)
			m.emission_energy_multiplier = 6.0 if k < lit else 0.0


func _build_corner_signs() -> void:
	var hw := width * 0.5
	var i := 0
	var done := {}
	while i < n:
		if radius[i] < 45.0 and not done.has(i / 30):
			# hitta toppen på kurvan
			var best := i
			for k in range(i, mini(i + 40, n)):
				if radius[k] < radius[best]:
					best = k
			var ta := tans[(best - 6 + n) % n]
			var tb := tans[(best + 6) % n]
			var turn := Vector2(ta.x, ta.z).cross(Vector2(tb.x, tb.z))
			var right_turn := turn > 0.0
			var outer := -1.0 if right_turn else 1.0
			var entry := (best - 10 + n) % n
			var lab := Label3D.new()
			lab.text = ">>>" if right_turn else "<<<"
			lab.font_size = 200
			lab.pixel_size = 0.012
			lab.modulate = Color(def["neon"]) * 1.0
			lab.shaded = false
			lab.double_sided = false
			var face := -tans[entry]
			lab.transform = Transform3D(Basis.looking_at(-face, Vector3.UP), pts[best] + rgts[best] * outer * (hw + 0.4) + Vector3.UP * 3.2)
			add_child(lab)
			done[i / 30] = true
			i = best + 40
		else:
			i += 1


## Gula ränder vid hoppkrönen och landningarna, plus en skylt.
func _build_jumps() -> void:
	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Color(1.0, 0.75, 0.05)
	stripe.emission_enabled = true
	stripe.emission = Color(1.0, 0.7, 0.05)
	stripe.emission_energy_multiplier = 4.0
	for z in jump_zones:
		var lip: float = z[2]
		var li := idx_at(lip)
		# sista vägbitens index före luckan
		var k := li
		while gap[k] == 1:
			k = (k - 1 + n) % n
		var land := (k + 1) % n
		var has_gap := false
		while gap[land] == 1:
			land = (land + 1) % n
			has_gap = true
		var marks := [k]
		if has_gap:
			marks.append(land)
		for m in marks:
			var bm := BoxMesh.new()
			bm.size = Vector3(width, 0.08, 0.7)
			var mi := MeshInstance3D.new()
			mi.mesh = bm
			mi.material_override = stripe
			mi.transform = Transform3D(Basis.looking_at(tans[m], Vector3.UP), pts[m] + Vector3.UP * 0.03)
			add_child(mi)
		var lab := Label3D.new()
		lab.text = "HOPP!" if has_gap else "KRÖN"
		lab.font_size = 220
		lab.pixel_size = 0.014
		lab.modulate = Color(2.2, 1.6, 0.2)
		lab.outline_size = 24
		lab.outline_modulate = Color(0.6, 0.2, 0.0, 0.6)
		lab.shaded = false
		lab.double_sided = false
		var before := (k - 30 + n) % n
		lab.transform = Transform3D(Basis.looking_at(tans[before], Vector3.UP), pts[before] + Vector3.UP * 9.0)
		add_child(lab)
		jump_lips.append([k, land])


## Lysande ringar runt vägen med jämna mellanrum. De pulserar i takt.
func _build_gates() -> void:
	var tm := TorusMesh.new()
	var r := width * 0.5 + 5.0
	tm.inner_radius = r - 0.45
	tm.outer_radius = r
	tm.rings = 48
	tm.ring_segments = 8
	var every := int(260.0 / STEP)
	var k := 0
	for i in range(every / 2, n - every / 3, every):
		if tunnel[i] == 1 or gap[i] == 1:
			continue
		var m := StandardMaterial3D.new()
		var col: Color = def["neon"] if k % 2 == 0 else def["neon2"]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 3.0
		var mi := MeshInstance3D.new()
		mi.mesh = tm
		mi.material_override = m
		var b := Basis.looking_at(tans[i], Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
		mi.transform = Transform3D(b, pts[i] + Vector3.UP * 3.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_gates.append([m, float(k)])
		k += 1


func _process(delta: float) -> void:
	_gate_t += delta
	for g in _gates:
		var m: StandardMaterial3D = g[0]
		m.emission_energy_multiplier = 2.0 + 2.5 * maxf(0.0, sin(_gate_t * 4.0 - g[1] * 0.9))


## Ligger ett hopp inom dist meter framåt (dir = 1) eller bakåt (dir = -1)?
func jump_ahead(s: float, dist: float, dir := 1.0) -> bool:
	for z in jump_zones:
		var d := fposmod((z[2] - s) * dir, length)
		if d < dist:
			return true
	return false


## Flyttar en återstartspunkt förbi ett hopp om den hamnar i hoppzonen.
func safe_respawn_offset(s: float) -> float:
	for z in jump_zones:
		var a: float = z[0]
		var d := fposmod(s - a, length)
		if d < z[1] - a:
			return z[1] + 6.0
	return s
