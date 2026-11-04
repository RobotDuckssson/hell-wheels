extends CanvasLayer
## Banredigeraren. Rita banan uppifrån med punkter, ställ in höjd och kurvradie per punkt
## och tunnel, räcken och hopp per sträcka. Banorna sparas i user://banor/ som JSON.

const Tracks = preload("res://scripts/tracks.gd")
const TrackScript = preload("res://scripts/track.gd")

const PINK := Color(1.0, 0.2, 0.65)
const CYAN := Color(0.2, 0.9, 1.0)
const THEMES := ["NEON (rosa/cyan, regn)", "SMOG (orange)", "GRÖNT (grönt/lila, regn)", "STOCKHOLM (soligt dagsljus)"]
const JUMP_CHOICES := [["Inget hopp", -1.0], ["Krön", 0.0], ["Lucka 12 m", 12.0], ["Lucka 16 m", 16.0], ["Lucka 20 m", 20.0]]

var game
var root: Control
var canvas: Control

# Banans data
var tname := "MIN BANA"
var theme := 0
var width := 18.0
var base_y := 40.0
var rain := true
var points: Array = []      # [x, z, höjd, radie]
var tunnels: Array = []     # sträckindex
var opens: Array = []
var jumps: Array = []       # [sträcka, lucka]
var file_name := ""

# Vy
var cam := Vector2.ZERO
var zoom := 0.9
var sel := 0
var _drag := false
var _pan := false
var _preview = null
var _warnings: Array = []
var _dirty := true
var _updating := false

# Kontroller
var _name_e: LineEdit
var _theme_o: OptionButton
var _rain_c: CheckBox
var _width_s: HSlider
var _base_s: HSlider
var _h_s: HSlider
var _r_s: HSlider
var _tun_c: CheckBox
var _open_c: CheckBox
var _jump_o: OptionButton
var _sel_l: Label
var _info_l: Label
var _warn_l: Label
var _load_o: OptionButton
var _vals: Dictionary = {}
var _help: Label
const HELP_2D := "Vänsterklick: lägg till punkt (på en linje: infoga)   Dra: flytta   Högerdra: panorera   Hjul: zooma   Delete: ta bort   Tab: 3D-vy"
const HELP_3D := "3D-VY   Vänsterdra: snurra   Högerdra: flytta vyn   Hjul: zooma   Klicka på en punkt: välj   Shift+dra punkt: ändra höjd   Tab: 2D-vy"

# 3D-vyn
var view3d := false
var _svc: SubViewportContainer
var _vp: SubViewport
var _cam3: Camera3D
var _yaw := 0.6
var _pitch := 0.55
var _dist := 900.0
var _target := Vector3.ZERO
var _ribbon: MeshInstance3D
var _marks: Node3D
var _drag3 := ""
var _view_btn: Button


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.offset_right = -400
	canvas.clip_contents = true
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_canvas_input)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(canvas)
	_build_3d()
	_build_panel()
	var help := Label.new()
	_help = help
	help.text = HELP_2D
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color(0.7, 0.75, 0.95))
	help.position = Vector2(16, 10)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(help)
	visible = false


# ---------------------------------------------------------------- panelen

func _build_panel() -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.02, 0.1, 0.97)
	sb.border_color = PINK
	sb.border_width_left = 2
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -400
	panel.clip_contents = true
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(340, 0)
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)

	var title := Label.new()
	title.text = "BANEDITOR"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(title)

	_view_btn = _btn("VISA I 3D  (Tab)", toggle_view)
	vb.add_child(_view_btn)
	vb.add_child(_head("BANAN"))
	_name_e = LineEdit.new()
	_name_e.max_length = 24
	_name_e.text_changed.connect(func(t): tname = t.to_upper())
	vb.add_child(_name_e)
	_theme_o = OptionButton.new()
	for t in THEMES:
		_theme_o.add_item(t)
	_theme_o.item_selected.connect(func(i):
		theme = i
		_changed())
	vb.add_child(_theme_o)
	_rain_c = CheckBox.new()
	_rain_c.text = "Regn"
	_rain_c.toggled.connect(func(on): rain = on)
	vb.add_child(_rain_c)
	_width_s = _slider(vb, "Vägbredd", 12, 26, 1, func(v):
		width = v
		_changed())
	_base_s = _slider(vb, "Höjd över gatan", 10, 90, 1, func(v):
		base_y = v
		_changed())

	vb.add_child(_head("VALD PUNKT"))
	_sel_l = Label.new()
	_sel_l.add_theme_color_override("font_color", PINK)
	vb.add_child(_sel_l)
	_h_s = _slider(vb, "Höjd (m, relativt)", -30, 70, 1, func(v):
		if not _updating and sel < points.size():
			points[sel][2] = v
			_changed())
	_r_s = _slider(vb, "Kurvradie (0 = skarp)", 0, 160, 1, func(v):
		if not _updating and sel < points.size():
			points[sel][3] = v
			_changed())
	var del := _btn("TA BORT PUNKT", func(): _delete_point(sel))
	vb.add_child(del)

	vb.add_child(_head("STRÄCKAN EFTER PUNKTEN"))
	_tun_c = CheckBox.new()
	_tun_c.text = "Tunnel"
	_tun_c.toggled.connect(func(on):
		if not _updating:
			_set_flag(tunnels, sel, on))
	vb.add_child(_tun_c)
	_open_c = CheckBox.new()
	_open_c.text = "Utan räcken (man kan åka av)"
	_open_c.toggled.connect(func(on):
		if not _updating:
			_set_flag(opens, sel, on))
	vb.add_child(_open_c)
	_jump_o = OptionButton.new()
	for j in JUMP_CHOICES:
		_jump_o.add_item(j[0])
	_jump_o.item_selected.connect(func(i):
		if _updating:
			return
		for k in range(jumps.size() - 1, -1, -1):
			if int(jumps[k][0]) == sel:
				jumps.remove_at(k)
		if JUMP_CHOICES[i][1] >= 0.0:
			jumps.append([sel, JUMP_CHOICES[i][1]])
		_changed())
	vb.add_child(_jump_o)

	vb.add_child(_head("KONTROLL"))
	_info_l = Label.new()
	_info_l.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	_info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_l.custom_minimum_size = Vector2(320, 0)
	vb.add_child(_info_l)
	_warn_l = Label.new()
	_warn_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warn_l.custom_minimum_size = Vector2(320, 0)
	_warn_l.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	vb.add_child(_warn_l)

	vb.add_child(_head("ARKIV"))
	vb.add_child(_btn("SPARA", _save))
	vb.add_child(_btn("PROVKÖR  ▶", _play))
	var hb := HBoxContainer.new()
	_load_o = OptionButton.new()
	_load_o.custom_minimum_size = Vector2(200, 0)
	_load_o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(_load_o)
	hb.add_child(_btn("ÖPPNA", _load_selected))
	vb.add_child(hb)
	var hb2 := HBoxContainer.new()
	hb2.add_child(_btn("NY BANA", _new_track))
	hb2.add_child(_btn("KOPIERA FÄRDIG", _copy_builtin))
	vb.add_child(hb2)
	vb.add_child(_btn("TILLBAKA TILL MENYN", func(): game.close_editor()))


func _head(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", CYAN)
	return l


func _slider(parent: Control, label: String, mn: float, mx: float, step: float, cb: Callable) -> HSlider:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(240, 0)
	l.add_theme_font_size_override("font_size", 15)
	hb.add_child(l)
	var v := Label.new()
	v.custom_minimum_size = Vector2(50, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(v)
	parent.add_child(hb)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.custom_minimum_size = Vector2(320, 20)
	s.value_changed.connect(func(x):
		v.text = str(int(x))
		cb.call(x))
	parent.add_child(s)
	_vals[s] = v
	return s


func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 36)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


func _set_flag(arr: Array, seg: int, on: bool) -> void:
	arr.erase(seg)
	if on:
		arr.append(seg)
	_changed()


# ---------------------------------------------------------------- öppna/spara

func open() -> void:
	visible = true
	if points.is_empty():
		_copy_builtin_index(0)
	_refresh_load_list()
	_sync_controls()
	_changed()


func close() -> void:
	visible = false


func _new_track() -> void:
	tname = "MIN BANA"
	file_name = ""
	points = [[0, -120, 0, 0], [250, -120, 6, 40], [250, 120, 16, 40], [-250, 120, 10, 40], [-250, -120, 2, 40]]
	tunnels = []
	opens = []
	jumps = []
	sel = 0
	_fit_view()
	_sync_controls()
	_changed()


func _copy_builtin() -> void:
	_copy_builtin_index(theme)


func _copy_builtin_index(i: int) -> void:
	var d: Dictionary = Tracks.TRACKS[i]
	tname = "KOPIA AV " + String(d["name"])
	file_name = ""
	theme = i
	width = d["width"]
	base_y = d["base_y"]
	rain = d["rain"]
	points = []
	for p in d["points"]:
		points.append([float(p[0]), float(p[1]), float(p[2]), float(p[3])])
	tunnels = d["tunnels"].duplicate()
	opens = d["open"].duplicate()
	jumps = d["jumps"].duplicate(true)
	sel = 0
	_fit_view()
	_sync_controls()
	_changed()


func to_dict() -> Dictionary:
	return {"name": tname, "theme": theme, "width": width, "base_y": base_y, "rain": rain,
		"points": points, "tunnels": tunnels, "open": opens, "jumps": jumps, "version": 1}


func _slug() -> String:
	var s := ""
	for ch in tname.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			s += ch
		elif ch in "åä":
			s += "a"
		elif ch == "ö":
			s += "o"
		else:
			s += "_"
	return s if s != "" else "bana"


func _save() -> bool:
	if points.size() < 3:
		_warn_l.text = "Banan behöver minst 3 punkter."
		return false
	DirAccess.make_dir_recursive_absolute("user://banor")
	if file_name == "":
		file_name = _slug() + ".json"
	var f := FileAccess.open("user://banor/" + file_name, FileAccess.WRITE)
	if f == null:
		_warn_l.text = "Kunde inte spara."
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	game.load_custom_tracks()
	_refresh_load_list()
	_info_l.text += "\nSparad som " + file_name
	return true


func _refresh_load_list() -> void:
	_load_o.clear()
	var d := DirAccess.open("user://banor")
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".json"):
			_load_o.add_item(f)


func _load_selected() -> void:
	if _load_o.item_count == 0:
		return
	var fn := _load_o.get_item_text(_load_o.selected)
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://banor/" + fn))
	if not (data is Dictionary):
		_warn_l.text = "Filen gick inte att läsa."
		return
	file_name = fn
	tname = String(data.get("name", "BANA"))
	theme = int(data.get("theme", 0))
	width = float(data.get("width", 18))
	base_y = float(data.get("base_y", 40))
	rain = bool(data.get("rain", true))
	points = []
	for p in data.get("points", []):
		points.append([float(p[0]), float(p[1]), float(p[2]), float(p[3])])
	tunnels = data.get("tunnels", []).map(func(x): return int(x))
	opens = data.get("open", []).map(func(x): return int(x))
	jumps = data.get("jumps", []).map(func(x): return [int(x[0]), float(x[1])])
	sel = 0
	_fit_view()
	_sync_controls()
	_changed()


func _play() -> void:
	if not _save():
		return
	game.play_custom(file_name)


# ---------------------------------------------------------------- redigering

func _changed() -> void:
	_dirty = true
	canvas.queue_redraw()


func _sync_controls() -> void:
	_updating = true
	_name_e.text = tname
	_theme_o.selected = theme
	_rain_c.button_pressed = rain
	_width_s.value = width
	_base_s.value = base_y
	sel = clampi(sel, 0, maxi(points.size() - 1, 0))
	if points.size() > 0:
		_h_s.value = points[sel][2]
		_r_s.value = points[sel][3]
	_sel_l.text = "Punkt %d av %d%s" % [sel, points.size(), "  (START)" if sel == 0 else ""]
	_tun_c.button_pressed = tunnels.has(sel)
	_open_c.button_pressed = opens.has(sel)
	var ji := 0
	for j in jumps:
		if int(j[0]) == sel:
			for k in JUMP_CHOICES.size():
				if absf(JUMP_CHOICES[k][1] - float(j[1])) < 0.5:
					ji = k
	_jump_o.selected = ji
	for s in _vals:
		_vals[s].text = str(int(s.value))
	_updating = false
	if view3d and _marks != null:
		_rebuild_marks()


func _shift_segments(from: int, d: int) -> void:
	for arr in [tunnels, opens]:
		for k in arr.size():
			if arr[k] >= from:
				arr[k] += d
	for j in jumps:
		if j[0] >= from:
			j[0] += d


func _insert_point(idx: int, p: Vector2) -> void:
	var prev: Array = points[(idx - 1 + points.size()) % points.size()]
	_shift_segments(idx, 1)
	points.insert(idx, [snappedf(p.x, 5.0), snappedf(p.y, 5.0), prev[2], 30.0])
	sel = idx


func _delete_point(i: int) -> void:
	if points.size() <= 3:
		_warn_l.text = "En bana behöver minst 3 punkter."
		return
	tunnels.erase(i)
	opens.erase(i)
	for k in range(jumps.size() - 1, -1, -1):
		if int(jumps[k][0]) == i:
			jumps.remove_at(k)
	_shift_segments(i + 1, -1)
	points.remove_at(i)
	sel = clampi(i - 1, 0, points.size() - 1)
	_sync_controls()
	_changed()


func _to_screen(w: Vector2) -> Vector2:
	return (w - cam) * zoom + canvas.size * 0.5


func _to_world(s: Vector2) -> Vector2:
	return (s - canvas.size * 0.5) / zoom + cam


func _fit_view() -> void:
	if points.is_empty():
		return
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for p in points:
		mn = mn.min(Vector2(p[0], p[1]))
		mx = mx.max(Vector2(p[0], p[1]))
	cam = (mn + mx) * 0.5
	var sz := canvas.size if canvas.size.x > 10.0 else Vector2(1200, 860)
	zoom = clampf(minf(sz.x / (mx.x - mn.x + 200.0), sz.y / (mx.y - mn.y + 200.0)), 0.15, 4.0)


func _canvas_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var before := _to_world(mb.position)
				zoom = clampf(zoom * (1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.1, 6.0)
				cam += before - _to_world(mb.position)
				canvas.queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_pan = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_click(mb.position)
			else:
				_drag = false
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _pan:
			cam -= mm.relative / zoom
			canvas.queue_redraw()
		elif _drag and sel < points.size():
			var w := _to_world(mm.position)
			points[sel][0] = snappedf(w.x, 5.0)
			points[sel][1] = snappedf(w.y, 5.0)
			_changed()


func _click(pos: Vector2) -> void:
	# träff på en punkt?
	for i in points.size():
		if _to_screen(Vector2(points[i][0], points[i][1])).distance_to(pos) < 12.0:
			sel = i
			_drag = true
			_sync_controls()
			canvas.queue_redraw()
			return
	# träff på en linje mellan punkter: infoga
	var w := _to_world(pos)
	for i in points.size():
		var a := _to_screen(Vector2(points[i][0], points[i][1]))
		var b := _to_screen(Vector2(points[(i + 1) % points.size()][0], points[(i + 1) % points.size()][1]))
		var cp := Geometry2D.get_closest_point_to_segment(pos, a, b)
		if cp.distance_to(pos) < 9.0:
			_insert_point(i + 1, w)
			_drag = true
			_sync_controls()
			_changed()
			return
	# annars: lägg till efter vald punkt
	_insert_point(sel + 1, w)
	_drag = true
	_sync_controls()
	_changed()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			if not _name_e.has_focus():
				_delete_point(sel)
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB and not _name_e.has_focus():
			toggle_view()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			game.close_editor()
			get_viewport().set_input_as_handled()


func make_def() -> Dictionary:
	return game.custom_to_def(to_dict(), file_name)


func _process(_d: float) -> void:
	if not visible or not _dirty:
		return
	_dirty = false
	if _preview != null:
		_preview.free()
		_preview = null
	if points.size() < 3:
		return
	_preview = TrackScript.new()
	_preview.def = make_def()
	_preview.width = width
	_preview._make_path()
	if _drag3 != "height":
		_check()
	canvas.queue_redraw()
	if view3d:
		_rebuild_3d()


func _check() -> void:
	_warnings.clear()
	var t = _preview
	var bad := 0
	var worst := 999.0
	var where := Vector2.ZERO
	for i in range(0, t.n, 3):
		for k in range(i + 30, t.n, 3):
			var dk: int = mini(k - i, t.n - (k - i))
			if dk < 30:
				continue
			var a: Vector3 = t.pts[i]
			var b: Vector3 = t.pts[k]
			if Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) < width + 4.0:
				var dy := absf(a.y - b.y)
				if dy < worst:
					worst = dy
					where = Vector2(a.x, a.z)
				if dy < 11.0:
					bad += 1
	if bad > 0:
		_warnings.append("Korsning eller för nära väg med bara %.0f m höjdskillnad (markerad med rött). Behöver minst 11 m." % worst)
		_warn_pos = where
	else:
		_warn_pos = Vector2.INF
	for j in jumps:
		var seg := int(j[0])
		if seg >= points.size():
			continue
		var a2 := Vector2(points[seg][0], points[seg][1])
		var b2 := Vector2(points[(seg + 1) % points.size()][0], points[(seg + 1) % points.size()][1])
		if a2.distance_to(b2) < 110.0:
			_warnings.append("Hoppet efter punkt %d ligger på en kort sträcka (under 110 m). Det blir svårt att få fart." % seg)
	if t.min_y < 3.0:
		_warnings.append("Banan går ner under gatan. Höj grundhöjden eller punkterna.")
	_info_l.text = "Längd %d m · höjd %d–%d m · %d punkter" % [int(t.length), int(t.min_y), int(t.max_y), points.size()]
	_warn_l.text = "\n".join(_warnings) if not _warnings.is_empty() else "Inga problem hittade."
	_warn_l.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if not _warnings.is_empty() else Color(0.4, 1.0, 0.5))


var _warn_pos := Vector2.INF


func _height_color(y: float) -> Color:
	var f := clampf((y - 10.0) / 80.0, 0.0, 1.0)
	return Color(0.15, 0.55, 1.0).lerp(Color(1.0, 0.25, 0.7), f)


func _draw_canvas() -> void:
	# rutnät var 50:e meter
	var tl := _to_world(Vector2.ZERO)
	var br := _to_world(canvas.size)
	var step := 50.0 if zoom > 0.35 else 200.0
	var x := floorf(tl.x / step) * step
	while x < br.x:
		canvas.draw_line(_to_screen(Vector2(x, tl.y)), _to_screen(Vector2(x, br.y)), Color(1, 1, 1, 0.08 if fmod(absf(x), 200.0) < 1.0 else 0.035))
		x += step
	var z := floorf(tl.y / step) * step
	while z < br.y:
		canvas.draw_line(_to_screen(Vector2(tl.x, z)), _to_screen(Vector2(br.x, z)), Color(1, 1, 1, 0.08 if fmod(absf(z), 200.0) < 1.0 else 0.035))
		z += step
	canvas.draw_string(ThemeDB.fallback_font, Vector2(16, canvas.size.y - 16), "Rutnät: %d m" % int(step), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.4))

	var t = _preview
	if t != null:
		# rita vägen sorterad efter höjd så att det som ligger högst hamnar överst
		var order: Array = []
		for i in t.n:
			order.append(i)
		order.sort_custom(func(a, b): return t.pts[a].y < t.pts[b].y)
		var wpx := maxf(width * zoom, 3.0)
		for i in order:
			var j: int = (i + 1) % t.n
			if t.gap[i] == 1:
				continue
			var a := _to_screen(Vector2(t.pts[i].x, t.pts[i].z))
			var b := _to_screen(Vector2(t.pts[j].x, t.pts[j].z))
			canvas.draw_line(a, b, Color(0, 0, 0, 0.8), wpx + 4.0)
			var c := _height_color(t.pts[i].y)
			if t.tunnel[i] == 1:
				c = c.darkened(0.55)
			canvas.draw_line(a, b, c, wpx)
			if t.open[i] == 1 and i % 4 < 2:
				var r: Vector3 = t.rgts[i] * width * 0.5
				canvas.draw_line(_to_screen(Vector2(t.pts[i].x + r.x, t.pts[i].z + r.z)), _to_screen(Vector2(t.pts[j].x + r.x, t.pts[j].z + r.z)), Color(1, 0.3, 0.2), 2.0)
				canvas.draw_line(_to_screen(Vector2(t.pts[i].x - r.x, t.pts[i].z - r.z)), _to_screen(Vector2(t.pts[j].x - r.x, t.pts[j].z - r.z)), Color(1, 0.3, 0.2), 2.0)
		for z2 in t.jump_zones:
			var li: int = t.idx_at(z2[2])
			var p := _to_screen(Vector2(t.pts[li].x, t.pts[li].z))
			canvas.draw_circle(p, 7.0, Color(1, 0.8, 0.1))
			canvas.draw_string(ThemeDB.fallback_font, p + Vector2(10, -8), "HOPP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.2))
		# startpil
		var s0 := _to_screen(Vector2(t.pts[0].x, t.pts[0].z))
		var dir := Vector2(t.tans[0].x, t.tans[0].z).normalized()
		canvas.draw_line(s0, s0 + dir * 40.0, Color.WHITE, 3.0)
		canvas.draw_circle(s0 + dir * 40.0, 5.0, Color.WHITE)
		if _warn_pos != Vector2.INF:
			canvas.draw_arc(_to_screen(_warn_pos), 26.0, 0, TAU, 32, Color(1, 0.2, 0.2), 3.0)
	# kontrollpunkter
	for i in points.size():
		var p2 := _to_screen(Vector2(points[i][0], points[i][1]))
		var on := i == sel
		canvas.draw_circle(p2, 9.0 if on else 7.0, PINK if on else Color.WHITE)
		canvas.draw_circle(p2, 5.0, Color(0.05, 0.02, 0.1))
		var lbl := "%d  h%d" % [i, int(points[i][2])]
		if i == 0:
			lbl = "START  h%d" % int(points[i][2])
		canvas.draw_string(ThemeDB.fallback_font, p2 + Vector2(12, -10), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PINK if on else Color(0.85, 0.9, 1.0))
	# färgskala
	for k in 10:
		canvas.draw_rect(Rect2(16 + k * 18, 44, 18, 10), _height_color(10.0 + k * 8.0))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(16, 72), "låg  →  hög", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))


# ---------------------------------------------------------------- 3D-vyn

func _build_3d() -> void:
	_svc = SubViewportContainer.new()
	_svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_svc.offset_right = -400
	_svc.stretch = true
	_svc.visible = false
	_svc.mouse_filter = Control.MOUSE_FILTER_STOP
	_svc.gui_input.connect(_input_3d)
	root.add_child(_svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_svc.add_child(_vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.03, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.7)
	env.ambient_light_energy = 0.35
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 1.0
	_vp.add_child(sun)
	# marken med rutnät var 50:e meter
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	g.mesh = pm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 c = abs(fract(wp.xz / 50.0 + 0.5) - 0.5) * 50.0;
	vec2 c2 = abs(fract(wp.xz / 200.0 + 0.5) - 0.5) * 200.0;
	float l = 1.0 - smoothstep(0.0, 0.6 + fwidth(wp.x) * 1.5, min(c.x, c.y));
	float l2 = 1.0 - smoothstep(0.0, 1.0 + fwidth(wp.x) * 2.0, min(c2.x, c2.y));
	ALBEDO = vec3(0.03, 0.025, 0.06) + vec3(0.05, 0.05, 0.1) * l + vec3(0.12, 0.12, 0.2) * l2;
}"""
	var gm := ShaderMaterial.new()
	gm.shader = sh
	g.material_override = gm
	_vp.add_child(g)
	_ribbon = MeshInstance3D.new()
	var rm := StandardMaterial3D.new()
	rm.vertex_color_use_as_albedo = true
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.roughness = 0.7
	_ribbon.material_override = rm
	_vp.add_child(_ribbon)
	_marks = Node3D.new()
	_vp.add_child(_marks)
	_cam3 = Camera3D.new()
	_cam3.far = 8000.0
	_cam3.fov = 55.0
	_vp.add_child(_cam3)


func toggle_view() -> void:
	view3d = not view3d
	_svc.visible = view3d
	canvas.visible = not view3d
	_help.text = HELP_3D if view3d else HELP_2D
	_view_btn.text = "VISA I 2D  (Tab)" if view3d else "VISA I 3D  (Tab)"
	if view3d:
		if _preview != null:
			var b: Rect2 = _preview.bounds
			_target = Vector3(b.get_center().x, base_y, b.get_center().y)
			_dist = maxf(b.size.length() * 0.9, 300.0)
		_rebuild_3d()
		_update_cam()


func _update_cam() -> void:
	var off := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw)) * _dist
	_cam3.position = _target + off
	_cam3.look_at(_target, Vector3.UP)


func _rebuild_3d() -> void:
	if _preview == null:
		return
	var t = _preview
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw: float = width * 0.5
	var up := Vector3.UP
	for i in t.n:
		var j: int = (i + 1) % t.n
		if t.gap[i] == 1 or t.gap[j] == 1:
			continue
		var c := _height_color(t.pts[i].y)
		if t.tunnel[i] == 1:
			c = c.darkened(0.5)
		var li: Vector3 = t.pts[i] - t.rgts[i] * hw
		var ri: Vector3 = t.pts[i] + t.rgts[i] * hw
		var lj: Vector3 = t.pts[j] - t.rgts[j] * hw
		var rj: Vector3 = t.pts[j] + t.rgts[j] * hw
		for q in [[li, lj, rj], [li, rj, ri]]:
			for v in q:
				st.set_color(c)
				st.set_normal(up)
				st.add_vertex(v)
		# kanter: röda där räcke saknas, annars ljusa
		var ec := Color(1, 0.25, 0.2) if t.open[i] == 1 else Color(0.85, 0.85, 1.0)
		for side in [-1.0, 1.0]:
			var a: Vector3 = t.pts[i] + t.rgts[i] * side * hw
			var b: Vector3 = t.pts[j] + t.rgts[j] * side * hw
			var eh := 0.4 if t.open[i] == 1 else 1.6
			for q2 in [[a, b, b + up * eh], [a, b + up * eh, a + up * eh]]:
				for v2 in q2:
					st.set_color(ec)
					st.set_normal(t.rgts[i] * side)
					st.add_vertex(v2)
		# pelare var 30:e meter så att höjden syns
		if i % 15 == 0:
			var p: Vector3 = t.pts[i]
			var s2 = t.rgts[i] * 0.8
			var f2: Vector3 = t.tans[i] * 0.8
			for q3 in [[p - s2, p + s2, Vector3(p.x, 0, p.z) + s2], [p - s2, Vector3(p.x, 0, p.z) + s2, Vector3(p.x, 0, p.z) - s2],
					[p - f2, p + f2, Vector3(p.x, 0, p.z) + f2], [p - f2, Vector3(p.x, 0, p.z) + f2, Vector3(p.x, 0, p.z) - f2]]:
				for v3 in q3:
					st.set_color(Color(0.3, 0.3, 0.4))
					st.set_normal(t.rgts[i])
					st.add_vertex(v3)
	_ribbon.mesh = st.commit()
	_rebuild_marks()


func _rebuild_marks() -> void:
	for c in _marks.get_children():
		c.free()
	if _preview == null:
		return
	var sph := SphereMesh.new()
	sph.radius = 4.0
	sph.height = 8.0
	for i in points.size():
		var wp := _point_world(i)
		var mi := MeshInstance3D.new()
		mi.mesh = sph
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = PINK if i == sel else Color.WHITE
		mi.material_override = m
		mi.position = wp + Vector3.UP * 3.0
		mi.scale = Vector3.ONE * (1.5 if i == sel else 1.0)
		_marks.add_child(mi)
		var lab := Label3D.new()
		lab.text = ("START" if i == 0 else str(i)) + "  h%d" % int(points[i][2])
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.fixed_size = true
		lab.pixel_size = 0.0015
		lab.font_size = 22
		lab.outline_size = 6
		lab.no_depth_test = true
		lab.modulate = PINK if i == sel else Color(0.9, 0.92, 1.0)
		lab.position = wp + Vector3.UP * 12.0
		_marks.add_child(lab)
	for z in _preview.jump_zones:
		var li: int = _preview.idx_at(z[2])
		var jl := Label3D.new()
		jl.text = "HOPP"
		jl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		jl.fixed_size = true
		jl.pixel_size = 0.0015
		jl.font_size = 20
		jl.modulate = Color(1, 0.8, 0.1)
		jl.outline_size = 6
		jl.position = _preview.pts[li] + Vector3.UP * 8.0
		_marks.add_child(jl)


## Kontrollpunktens läge i 3D: närmaste punkt på den beräknade banan.
func _point_world(i: int) -> Vector3:
	var p := Vector3(points[i][0], 0, points[i][1])
	var best := Vector3(p.x, base_y + float(points[i][2]), p.z)
	if _preview != null:
		var bd := 1e18
		for k in range(0, _preview.n, 2):
			var q: Vector3 = _preview.pts[k]
			var d := Vector2(q.x - p.x, q.z - p.z).length_squared()
			if d < bd:
				bd = d
				best = q
	return best


func _input_3d(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = maxf(_dist / 1.15, 40.0)
			_update_cam()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = minf(_dist * 1.15, 5000.0)
			_update_cam()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag3 = "orbit"
				var best := -1
				var bd := 18.0
				for i in points.size():
					var wp := _point_world(i) + Vector3.UP * 3.0
					if _cam3.is_position_behind(wp):
						continue
					var sp := _cam3.unproject_position(wp)
					var d := sp.distance_to(mb.position)
					if d < bd:
						bd = d
						best = i
				if best >= 0:
					sel = best
					_drag3 = "height" if mb.shift_pressed else "none"
					_sync_controls()
			else:
				if _drag3 == "height":
					_changed()
				_drag3 = ""
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag3 = "pan" if mb.pressed else ""
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		match _drag3:
			"orbit":
				_yaw -= mm.relative.x * 0.006
				_pitch = clampf(_pitch + mm.relative.y * 0.006, 0.05, 1.5)
				_update_cam()
			"pan":
				var right := _cam3.global_basis.x
				var fwd := Vector3(-_cam3.global_basis.z.x, 0, -_cam3.global_basis.z.z).normalized()
				_target += (-right * mm.relative.x + fwd * mm.relative.y) * _dist * 0.0012
				_update_cam()
			"height":
				if sel < points.size():
					points[sel][2] = clampf(float(points[sel][2]) - mm.relative.y * _dist * 0.0012, -30.0, 70.0)
					_updating = true
					_h_s.value = points[sel][2]
					_vals[_h_s].text = str(int(points[sel][2]))
					_updating = false
					_changed()
