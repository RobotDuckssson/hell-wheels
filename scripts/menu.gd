extends CanvasLayer
## Huvudmenyn: välj spelläge, bana, svårighet, bil, antal varv, grafik och musik.

const CarTypes = preload("res://scripts/car_types.gd")
const Tracks = preload("res://scripts/tracks.gd")

const PINK := Color(1.0, 0.2, 0.65)
const CYAN := Color(0.2, 0.9, 1.0)

var game
var root: Control
var _rows: Array = []        # [key, value_label, row_panel]
var _sel := 0
var _info: Label
var _car_name: Label
var _car_desc: Label
var _stats: Control
var _start: Button
var _loading: Label
var _t := 0.0
var _title: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.04, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var side := ColorRect.new()
	side.color = Color(0.02, 0.0, 0.06, 0.72)
	side.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	side.offset_right = 620
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(side)

	_title = Label.new()
	_title.text = "HELL WHEELS"
	var ts := LabelSettings.new()
	ts.font_size = 92
	ts.font_color = Color(1.0, 0.92, 0.98)
	ts.outline_size = 16
	ts.outline_color = Color(PINK.r, PINK.g, PINK.b, 0.8)
	ts.shadow_size = 24
	ts.shadow_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.45)
	ts.shadow_offset = Vector2(5, 5)
	_title.label_settings = ts
	_title.position = Vector2(44, 30)
	root.add_child(_title)
	var sub := Label.new()
	sub.text = "GATURACE I SKYMNINGSSTADEN · ÅR 2089"
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", CYAN)
	sub.position = Vector2(50, 142)
	root.add_child(sub)

	var vb := VBoxContainer.new()
	vb.position = Vector2(44, 196)
	vb.size = Vector2(540, 520)
	vb.add_theme_constant_override("separation", 6)
	root.add_child(vb)
	for key in ["mode", "track", "diff", "car", "laps", "quality", "music"]:
		vb.add_child(_make_row(key))
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(540, 70)
	_info.add_theme_font_size_override("font_size", 17)
	_info.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95))
	vb.add_child(_info)
	_start = Button.new()
	_start.text = "STARTA  ▶"
	_start.custom_minimum_size = Vector2(540, 64)
	_start.add_theme_font_size_override("font_size", 30)
	_style_button(_start, true)
	_start.pressed.connect(_go)
	vb.add_child(_start)
	var ed := Button.new()
	ed.text = "BANEDITOR"
	ed.custom_minimum_size = Vector2(540, 40)
	ed.add_theme_font_size_override("font_size", 20)
	_style_button(ed, false)
	ed.pressed.connect(func(): game.open_editor())
	vb.add_child(ed)

	# Bilkort till höger
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.0, 0.06, 0.72)
	sb.border_color = CYAN
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(460, 290)
	card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	card.offset_left = -500
	card.offset_top = -340
	card.offset_right = -40
	card.offset_bottom = -50
	root.add_child(card)
	var cv := VBoxContainer.new()
	card.add_child(cv)
	_car_name = Label.new()
	_car_name.add_theme_font_size_override("font_size", 40)
	_car_name.add_theme_color_override("font_color", Color.WHITE)
	cv.add_child(_car_name)
	_car_desc = Label.new()
	_car_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_car_desc.custom_minimum_size = Vector2(410, 50)
	_car_desc.add_theme_font_size_override("font_size", 17)
	_car_desc.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95))
	cv.add_child(_car_desc)
	_stats = Control.new()
	_stats.custom_minimum_size = Vector2(410, 150)
	_stats.draw.connect(_draw_stats)
	cv.add_child(_stats)

	var help := Label.new()
	help.text = "↑↓ välj   ←→ ändra   ENTER starta        I spelet: W/S gas/broms · A/D styr · SPACE sladd · SHIFT boost · R tillbaka · C kamera · ESC paus"
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9, 0.8))
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 44
	help.offset_top = -36
	help.offset_right = 1560
	help.offset_bottom = -10
	root.add_child(help)

	_loading = Label.new()
	_loading.text = "BYGGER STADEN ..."
	_loading.add_theme_font_size_override("font_size", 28)
	_loading.add_theme_color_override("font_color", PINK)
	_loading.set_anchors_preset(Control.PRESET_CENTER)
	_loading.offset_left = 0
	_loading.offset_top = -20
	_loading.offset_right = 400
	_loading.offset_bottom = 20
	_loading.visible = false
	root.add_child(_loading)
	visible = false


func _make_row(key: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.03)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	p.add_child(hb)
	var name_l := Label.new()
	name_l.text = {"mode": "SPELLÄGE", "track": "BANA", "diff": "SVÅRIGHET", "car": "BIL", "laps": "VARV", "quality": "GRAFIK", "music": "MUSIK"}[key]
	name_l.custom_minimum_size = Vector2(170, 0)
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", CYAN)
	hb.add_child(name_l)
	var left := Button.new()
	left.text = "◀"
	left.flat = true
	left.focus_mode = Control.FOCUS_NONE
	left.add_theme_font_size_override("font_size", 22)
	left.pressed.connect(func(): _select(_index_of(key)); _change(key, -1))
	hb.add_child(left)
	var val := Label.new()
	val.custom_minimum_size = Vector2(260, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 24)
	hb.add_child(val)
	var right := Button.new()
	right.text = "▶"
	right.flat = true
	right.focus_mode = Control.FOCUS_NONE
	right.add_theme_font_size_override("font_size", 22)
	right.pressed.connect(func(): _select(_index_of(key)); _change(key, 1))
	hb.add_child(right)
	_rows.append([key, val, p, sb])
	return p


func _index_of(key: String) -> int:
	for i in _rows.size():
		if _rows[i][0] == key:
			return i
	return 0


func _style_button(b: Button, big: bool) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(PINK.r, PINK.g, PINK.b, 0.35 if big else 0.15)
	n.border_color = PINK
	n.set_border_width_all(2)
	n.set_corner_radius_all(4)
	var h := n.duplicate()
	h.bg_color = Color(PINK.r, PINK.g, PINK.b, 0.7)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)


func open() -> void:
	visible = true
	_loading.visible = false
	_refresh()


func close() -> void:
	visible = false


func _refresh() -> void:
	var s: Dictionary = game.settings
	for i in _rows.size():
		var key: String = _rows[i][0]
		var val: Label = _rows[i][1]
		var sb: StyleBoxFlat = _rows[i][3]
		match key:
			"mode": val.text = game.MODE_NAMES[s["mode"]]
			"track": val.text = game.all_tracks()[s["track"]]["name"]
			"diff": val.text = game.DIFF_NAMES[s["diff"]]
			"car": val.text = CarTypes.TYPES[s["car"]]["name"]
			"laps": val.text = str(s["laps"]) if s["mode"] == 0 else "—"
			"quality": val.text = "HÖG" if s["quality"] > 0 else "LÅG"
			"music": val.text = "PÅ" if s["music"] else "AV"
		var on := i == _sel
		val.add_theme_color_override("font_color", Color.WHITE if on else Color(0.8, 0.82, 0.9))
		sb.bg_color = Color(PINK.r, PINK.g, PINK.b, 0.28) if on else Color(1, 1, 1, 0.03)
		sb.border_color = PINK
		sb.border_width_left = 4 if on else 0
	var key2: String = _rows[_sel][0] if _sel < _rows.size() else ""
	var d: Dictionary = game.DIFFS[s["diff"]]
	match key2:
		"mode": _info.text = game.MODE_DESC[s["mode"]]
		"track": _info.text = game.all_tracks()[s["track"]]["desc"]
		"diff": _info.text = ["Långsammare motståndare som sällan knuffas. Du tål mer.",
			"Jämn match. Motståndarna knuffas när du kör bredvid.",
			"Snabba, hänsynslösa motståndare. Du tål mindre och lagas sämre."][s["diff"]] + "  (%d motståndare)" % d["opponents"]
		"car": _info.text = "Bilen står vid startlinjen bakom menyn."
		"laps": _info.text = "Antal varv i Först i mål."
		"quality": _info.text = "Låg: inga reflexer, mindre dimma och färre ljus. Välj Låg om spelet hackar."
		"music": _info.text = "Synthslinga i bakgrunden."
		_: _info.text = ""
	var t: Dictionary = CarTypes.TYPES[s["car"]]
	_car_name.text = t["name"]
	_car_desc.text = t["desc"]
	_stats.queue_redraw()


func _draw_stats() -> void:
	var t: Dictionary = CarTypes.TYPES[game.settings["car"]]
	var vals := [
		["TOPPFART", inverse_lerp(55.0, 85.0, t["top"])],
		["ACCELERATION", inverse_lerp(7.0, 14.0, t["accel"])],
		["VÄGGREPP", inverse_lerp(1.4, 2.1, t["grip"])],
		["TÅLIGHET", inverse_lerp(50.0, 320.0, float(t["hp"]) * float(t["armor"]))],
		["VIKT", inverse_lerp(700.0, 2800.0, t["mass"])],
	]
	var f := ThemeDB.fallback_font
	for i in vals.size():
		var y := 8.0 + i * 28.0
		_stats.draw_string(f, Vector2(0, y + 15), vals[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.8, 1.0))
		_stats.draw_rect(Rect2(150, y, 250, 16), Color(1, 1, 1, 0.08))
		var v := clampf(vals[i][1], 0.05, 1.0)
		_stats.draw_rect(Rect2(150, y, 250 * v, 16), CYAN.lerp(PINK, v))


func _select(i: int) -> void:
	_sel = clampi(i, 0, _rows.size())
	_refresh()


func _change(key: String, d: int) -> void:
	var s: Dictionary = game.settings
	match key:
		"mode": s["mode"] = posmod(s["mode"] + d, 2)
		"track": s["track"] = posmod(s["track"] + d, game.all_tracks().size())
		"diff": s["diff"] = clampi(s["diff"] + d, 0, 2)
		"car": s["car"] = posmod(s["car"] + d, CarTypes.TYPES.size())
		"laps":
			var i: int = game.LAP_CHOICES.find(s["laps"])
			s["laps"] = game.LAP_CHOICES[clampi(i + d, 0, game.LAP_CHOICES.size() - 1)]
		"quality": s["quality"] = 1 - s["quality"]
		"music": s["music"] = not s["music"]
	game.sfx.play("click", -8.0)
	if key == "track" or key == "quality":
		_loading.visible = true
		_refresh()
		await get_tree().process_frame
		await get_tree().process_frame
		game.on_setting_changed(key)
		_loading.visible = false
	else:
		game.on_setting_changed(key)
	_refresh()


func _go() -> void:
	game.sfx.play("select", -4.0)
	game.start_race()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_down"):
		_select((_sel + 1) % (_rows.size() + 1))
		if _sel == _rows.size():
			_start.grab_focus()
		else:
			_start.release_focus()
		game.sfx.play("click", -12.0)
	elif event.is_action_pressed("ui_up"):
		_select((_sel - 1 + _rows.size() + 1) % (_rows.size() + 1))
		if _sel == _rows.size():
			_start.grab_focus()
		else:
			_start.release_focus()
		game.sfx.play("click", -12.0)
	elif event.is_action_pressed("ui_left") and _sel < _rows.size():
		_change(_rows[_sel][0], -1)
	elif event.is_action_pressed("ui_right") and _sel < _rows.size():
		_change(_rows[_sel][0], 1)
	elif event.is_action_pressed("ui_accept"):
		if _sel == _rows.size() or not _start.has_focus():
			_go()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	if visible:
		var g := 0.75 + 0.25 * sin(_t * 2.3) + (0.3 if fmod(_t, 4.0) < 0.08 else 0.0)
		_title.label_settings.outline_color = Color(PINK.r, PINK.g, PINK.b, clampf(g, 0, 1))
