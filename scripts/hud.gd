extends CanvasLayer
## HUD: fart, hälsa, boost, placering, varv, minikarta, meddelanden, resultat och paus.

const CarTypes = preload("res://scripts/car_types.gd")

var game
var root: Control
var _pos_l: Label
var _pos_small: Label
var _lap_l: Label
var _time_l: Label
var _speed_l: Label
var _name_l: Label
var _msg_l: Label
var _msg_t := 0.0
var _feed: VBoxContainer
var _gauge: Control
var _bars: Control
var _map: Control
var _results: PanelContainer
var _pause: PanelContainer
var _wreck_l: Label
var _help_l: Label
var _mode := "race"
var _map_pts := PackedVector2Array()
var _map_xf := Transform2D()
const PINK := Color(1.0, 0.2, 0.65)
const CYAN := Color(0.2, 0.9, 1.0)


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_pos_small = _lbl(22, CYAN)
	_pos_small.text = "PLACERING"
	_pos_small.position = Vector2(34, 22)
	_pos_l = _lbl(78, Color.WHITE, PINK)
	_pos_l.position = Vector2(30, 40)
	_lap_l = _lbl(30, Color.WHITE)
	_lap_l.position = Vector2(34, 140)
	_time_l = _lbl(24, Color(0.8, 0.85, 1.0))
	_time_l.position = Vector2(34, 180)

	_map = Control.new()
	_map.custom_minimum_size = Vector2(250, 250)
	_map.size = Vector2(250, 250)
	_place(_map, Control.PRESET_TOP_RIGHT, Rect2(-270, 20, 250, 250))
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_map)
	root.add_child(_map)

	_gauge = Control.new()
	_place(_gauge, Control.PRESET_BOTTOM_RIGHT, Rect2(-300, -250, 280, 230))
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	root.add_child(_gauge)
	_speed_l = _lbl(64, Color.WHITE, CYAN)
	_speed_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_l.size = Vector2(280, 80)
	_speed_l.position = Vector2(0, 80)
	_speed_l.reparent(_gauge, false)
	var kmh := _lbl(20, Color(0.7, 0.8, 1.0))
	kmh.text = "KM/H"
	kmh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kmh.size = Vector2(280, 30)
	kmh.position = Vector2(0, 155)
	kmh.reparent(_gauge, false)

	_bars = Control.new()
	_place(_bars, Control.PRESET_BOTTOM_LEFT, Rect2(30, -140, 420, 120))
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	root.add_child(_bars)
	_name_l = _lbl(22, Color.WHITE)
	_name_l.position = Vector2(0, 0)
	_name_l.reparent(_bars, false)

	_msg_l = _lbl(96, Color.WHITE, PINK)
	_msg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_msg_l, Control.PRESET_CENTER_TOP, Rect2(-600, 150, 1200, 150))

	_wreck_l = _lbl(30, Color(1, 0.7, 0.4))
	_wreck_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_wreck_l, Control.PRESET_CENTER_TOP, Rect2(-400, 300, 800, 50))

	_feed = VBoxContainer.new()
	_place(_feed, Control.PRESET_CENTER_RIGHT, Rect2(-470, -60, 450, 200))
	_feed.alignment = BoxContainer.ALIGNMENT_END
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_feed)

	_help_l = _lbl(16, Color(0.75, 0.8, 0.95, 0.7))
	_help_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_help_l, Control.PRESET_CENTER_BOTTOM, Rect2(-450, -34, 900, 24))
	_help_l.text = "W/S gas/broms   A/D styr   SPACE sladd   SHIFT boost   R tillbaka på banan   C kamera   ESC paus"

	_results = _panel()
	_pause = _panel()
	hide_all()


## Placerar en kontroll relativt ett ankare: rect.position är förskjutningen från ankaret.
static func _place(c: Control, preset: int, r: Rect2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y


func _center(p: Control) -> void:
	var sz := p.get_combined_minimum_size()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -sz.x * 0.5
	p.offset_right = sz.x * 0.5
	p.offset_top = -sz.y * 0.5
	p.offset_bottom = sz.y * 0.5


func _lbl(size: int, col: Color, outline := Color(0, 0, 0, 0.8)) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = col
	ls.outline_size = maxi(4, size / 8)
	ls.outline_color = outline if outline.a > 0.0 else Color(0, 0, 0, 0.8)
	if outline != Color(0, 0, 0, 0.8):
		ls.outline_color = Color(outline.r, outline.g, outline.b, 0.55)
	ls.shadow_size = 6
	ls.shadow_color = Color(0, 0, 0, 0.5)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.07, 0.88)
	sb.border_color = PINK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	sb.shadow_color = Color(PINK.r, PINK.g, PINK.b, 0.35)
	sb.shadow_size = 18
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.visible = false
	root.add_child(p)
	return p


func hide_all() -> void:
	for c in root.get_children():
		c.visible = false


func start(mode: String) -> void:
	_mode = mode
	hide_all()
	for c in [_pos_small, _pos_l, _lap_l, _time_l, _map, _gauge, _bars, _msg_l, _wreck_l, _feed, _help_l]:
		c.visible = true
	for f in _feed.get_children():
		f.queue_free()
	_msg_l.text = ""
	_build_map()


func _build_map() -> void:
	var t = game.track
	_map_pts = PackedVector2Array()
	for i in range(0, t.n, 3):
		_map_pts.append(Vector2(t.pts[i].x, t.pts[i].z))
	var b: Rect2 = t.bounds
	var s := 210.0 / maxf(b.size.x, b.size.y)
	var off := Vector2(125, 125) - b.get_center() * s
	_map_xf = Transform2D(0.0, Vector2(s, s), 0.0, off)


func message(text: String, col: Color, dur: float, big: bool) -> void:
	_msg_l.text = text
	_msg_l.label_settings.font_size = 110 if big else 60
	_msg_l.label_settings.font_color = col
	_msg_t = dur
	_msg_l.modulate.a = 1.0


func feed(text: String, highlight: bool) -> void:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = 22
	ls.font_color = Color(1, 0.85, 0.3) if highlight else Color(0.85, 0.9, 1.0)
	ls.outline_size = 4
	ls.outline_color = Color(0, 0, 0, 0.8)
	l.label_settings = ls
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)
	while _feed.get_child_count() > 5:
		_feed.get_child(0).free()


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t < 0.4:
			_msg_l.modulate.a = maxf(0.0, _msg_t / 0.4)
	var p = game.player
	if p == null or not is_instance_valid(p) or not _gauge.visible:
		return
	var total: int = game.cars.size()
	if _mode == "race":
		_pos_small.text = "PLACERING"
		_pos_l.text = "%d/%d" % [p.place, total]
		var laps: int = game.settings["laps"]
		_lap_l.text = "VARV %d/%d" % [clampi(p.laps_done, 1, laps), laps]
		var lt := ""
		if p.best_lap > 0.0:
			lt = "   BÄSTA %s" % game.fmt_time(p.best_lap)
		_time_l.text = "TID %s%s" % [game.fmt_time(game.race_time), lt]
	else:
		_pos_small.text = "KVAR"
		_pos_l.text = "%d/%d" % [game._alive_count(), total]
		_lap_l.text = "VRAKADE: %d" % p.kills
		_time_l.text = "TID %s" % game.fmt_time(game.race_time)
	_speed_l.text = str(int(absf(p.fwd_speed) * 3.6))
	_name_l.text = "%s" % CarTypes.TYPES[p.type_id]["name"]
	if not p.alive and game.settings["mode"] == 0:
		var left: float = 2.8 - (game.race_time - p.wreck_time)
		_wreck_l.text = "Tillbaka om %d ..." % int(ceil(maxf(left, 0.0)))
	else:
		_wreck_l.text = ""
	_gauge.queue_redraw()
	_bars.queue_redraw()
	_map.queue_redraw()


func _draw_gauge() -> void:
	var p = game.player
	if p == null or not is_instance_valid(p):
		return
	var c := Vector2(140, 125)
	var r := 105.0
	var a0 := deg_to_rad(140)
	var a1 := deg_to_rad(400)
	_gauge.draw_arc(c, r, a0, a1, 48, Color(1, 1, 1, 0.12), 14.0, true)
	var top: float = p.stats["top"] * 1.25
	var f := clampf(absf(p.fwd_speed) / top, 0.0, 1.0)
	var col := CYAN.lerp(PINK, f)
	if f > 0.01:
		_gauge.draw_arc(c, r, a0, lerpf(a0, a1, f), 48, col, 14.0, true)
	# boost
	var b: float = p.boost
	_gauge.draw_arc(c, r - 20.0, a0, a1, 48, Color(1, 1, 1, 0.08), 6.0, true)
	if b > 0.01:
		_gauge.draw_arc(c, r - 20.0, a0, lerpf(a0, a1, b), 48, Color(1, 0.75, 0.1) if not p.boosting else Color(1, 1, 0.6), 6.0, true)


func _draw_bars() -> void:
	var p = game.player
	if p == null or not is_instance_valid(p):
		return
	var hpf: float = clampf(p.hp / p.max_hp, 0.0, 1.0)
	var y := 38.0
	_bars.draw_string(ThemeDB.fallback_font, Vector2(0, y + 18), "SKICK", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.8, 1.0))
	_bars.draw_rect(Rect2(70, y, 330, 22), Color(1, 1, 1, 0.1))
	var hc := Color(0.2, 1.0, 0.45).lerp(Color(1, 0.8, 0.1), clampf((0.7 - hpf) * 2.5, 0, 1))
	if hpf < 0.3:
		hc = Color(1, 0.15, 0.1) * (0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.015))
	_bars.draw_rect(Rect2(70, y, 330 * hpf, 22), hc)
	for k in range(1, 10):
		_bars.draw_line(Vector2(70 + 33 * k, y), Vector2(70 + 33 * k, y + 22), Color(0, 0, 0, 0.5), 2.0)
	y += 34.0
	_bars.draw_string(ThemeDB.fallback_font, Vector2(0, y + 14), "BOOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.8, 1.0))
	_bars.draw_rect(Rect2(70, y, 330, 14), Color(1, 1, 1, 0.1))
	_bars.draw_rect(Rect2(70, y, 330 * p.boost, 14), Color(1, 0.75, 0.1))


func _draw_map() -> void:
	if _map_pts.size() < 2:
		return
	_map.draw_rect(Rect2(Vector2.ZERO, Vector2(250, 250)), Color(0.02, 0.02, 0.06, 0.78))
	var pts := _map_xf * _map_pts
	pts.append(pts[0])
	_map.draw_polyline(pts, Color(1, 1, 1, 0.12), 9.0, true)
	_map.draw_polyline(pts, Color(game.track.def["neon2"]) * Color(1, 1, 1, 0.8), 3.0, true)
	var sp: Vector2 = _map_xf * Vector2(game.track.pts[0].x, game.track.pts[0].z)
	_map.draw_circle(sp, 4.0, Color.WHITE)
	for c in game.cars:
		if not is_instance_valid(c):
			continue
		var mp: Vector2 = _map_xf * Vector2(c.global_position.x, c.global_position.z)
		if c == game.player:
			continue
		var col: Color = c.accent if c.alive else Color(0.4, 0.4, 0.4)
		_map.draw_circle(mp, 5.0, col)
	var p = game.player
	if p != null and is_instance_valid(p):
		var mp2: Vector2 = _map_xf * Vector2(p.global_position.x, p.global_position.z)
		var f: Vector3 = -p.global_basis.z
		var d := Vector2(f.x, f.z).normalized()
		var rt := Vector2(-d.y, d.x)
		var tri := PackedVector2Array([mp2 + d * 10.0, mp2 - d * 6.0 + rt * 6.0, mp2 - d * 6.0 - rt * 6.0])
		_map.draw_colored_polygon(tri, Color.WHITE)


func show_results(title: String, rows: Array, mode: int) -> void:
	for c in _results.get_children():
		c.free()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_results.add_child(vb)
	var t := Label.new()
	t.text = title
	var ls := LabelSettings.new()
	ls.font_size = 64
	ls.font_color = Color.WHITE
	ls.outline_size = 10
	ls.outline_color = Color(PINK.r, PINK.g, PINK.b, 0.6)
	t.label_settings = ls
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)
	var heads := ["#", "FÖRARE", "BIL", "TID", "BÄSTA VARV"] if mode == 0 else ["#", "FÖRARE", "BIL", "VRAKADE", "STATUS"]
	for h in heads:
		grid.add_child(_cell(h, CYAN, 20))
	for r in rows:
		var col := Color(1, 0.85, 0.3) if r[5] else Color(0.9, 0.92, 1.0)
		for k in 5:
			grid.add_child(_cell(str(r[k]), col, 24))
	var hint := Label.new()
	hint.text = "ENTER  kör igen        ESC  till menyn"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	vb.add_child(hint)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 24)
	vb.add_child(btns)
	var again := _button("KÖR IGEN", func(): game.start_race())
	btns.add_child(again)
	btns.add_child(_button("MENY", func(): game.show_menu()))
	_msg_l.text = ""
	_results.visible = true
	_results.reset_size()
	_center(_results)
	again.grab_focus.call_deferred()


func _cell(text: String, col: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 48)
	b.add_theme_font_size_override("font_size", 22)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.1, 0.05, 0.18, 0.9)
	n.border_color = CYAN
	n.set_border_width_all(2)
	n.set_corner_radius_all(4)
	var h := n.duplicate()
	h.bg_color = Color(PINK.r, PINK.g, PINK.b, 0.5)
	h.border_color = PINK
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)
	b.pressed.connect(func():
		game.sfx.play("select", -6.0)
		cb.call())
	return b


func show_pause(on: bool) -> void:
	for c in _pause.get_children():
		c.free()
	_pause.visible = on
	if not on:
		return
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_pause.add_child(vb)
	var t := Label.new()
	t.text = "PAUS"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 56)
	vb.add_child(t)
	var cont := _button("FORTSÄTT", func(): game.toggle_pause())
	vb.add_child(cont)
	vb.add_child(_button("STARTA OM", func(): game.start_race()))
	vb.add_child(_button("MENY", func(): game.show_menu()))
	_pause.reset_size()
	_center(_pause)
	cont.grab_focus.call_deferred()
