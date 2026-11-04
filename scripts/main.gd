extends Node3D
## Hell Wheels – bygger världen, startar lopp, håller koll på placeringar,
## vrak, återstarter och vem som vinner.

const Tracks = preload("res://scripts/tracks.gd")
const CarTypes = preload("res://scripts/car_types.gd")
const TrackScript = preload("res://scripts/track.gd")
const CityScript = preload("res://scripts/city.gd")
const CarScript = preload("res://scripts/car.gd")
const AIDriver = preload("res://scripts/ai_driver.gd")
const PlayerDriver = preload("res://scripts/player_driver.gd")
const FxScript = preload("res://scripts/fx.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const HudScript = preload("res://scripts/hud.gd")
const MenuScript = preload("res://scripts/menu.gd")
const CamScript = preload("res://scripts/chase_cam.gd")
const TrackEditorScript = preload("res://scripts/editor.gd")

const MODE_NAMES := ["FÖRST I MÅL", "SIST KVAR"]
const MODE_DESC := ["Kör varven först av alla. Vrakade bilar kommer tillbaka efter några sekunder.",
	"Ramma de andra tills bara en bil är hel. Vrakad är vrakad."]
const DIFF_NAMES := ["LÄTT", "MEDEL", "SVÅR"]
## opponents: antal motståndare, skill: hur hårt AI vågar ta kurvorna, top: AI-bilarnas toppfart,
## aggr: hur gärna AI knuffar och jagar dig, player_dmg/ai_dmg: skadefaktor, heal: hälsa efter vrak
const DIFFS := [
	{"opponents": 5, "skill": 0.74, "top": 0.86, "aggr": 0.15, "player_dmg": 0.5, "ai_dmg": 1.3, "heal": 0.9, "mistakes": 0.09},
	{"opponents": 6, "skill": 0.84, "top": 0.93, "aggr": 0.45, "player_dmg": 0.75, "ai_dmg": 1.0, "heal": 0.7, "mistakes": 0.055},
	{"opponents": 7, "skill": 0.93, "top": 0.99, "aggr": 0.8, "player_dmg": 1.0, "ai_dmg": 0.85, "heal": 0.5, "mistakes": 0.03},
]
const LAP_CHOICES := [1, 2, 3, 5]

var settings := {"mode": 0, "track": 0, "diff": 1, "car": 0, "laps": 3, "quality": 1, "music": true}
var state := "menu"
var world: Node3D
var track
var city
var fx
var sfx
var hud
var menu
var cam
var cars: Array = []
var player = null
var debris_root: Node3D
var _debris: Array = []
var race_time := 0.0
var countdown := 0.0
var finish_order: Array = []
var autotest := false
var shots := false
var paused := false
var preview_car = null
var editor
var custom_tracks: Array = []
var _custom_version := 0
var sudden := false
var _built := ""
var _reset_cd := 0.0
var _off_t: Dictionary = {}
var _flip_t: Dictionary = {}
var _stuck_t: Dictionary = {}
var _result_timer := -1.0
var _last_beep := 99
var _log_t := 0.0
var _shot_i := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load_settings()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--autotest":
			autotest = true
		elif a == "--shots":
			shots = true
		elif a.begins_with("track="):
			settings["track"] = int(a.substr(6))
		elif a.begins_with("mode="):
			settings["mode"] = int(a.substr(5))
		elif a.begins_with("diff="):
			settings["diff"] = int(a.substr(5))
		elif a.begins_with("car="):
			settings["car"] = int(a.substr(4))
		elif a.begins_with("laps="):
			settings["laps"] = int(a.substr(5))
		elif a.begins_with("quality="):
			settings["quality"] = int(a.substr(8))
	sfx = SfxScript.new()
	add_child(sfx)
	cam = CamScript.new()
	add_child(cam)
	hud = HudScript.new()
	hud.game = self
	add_child(hud)
	menu = MenuScript.new()
	menu.game = self
	add_child(menu)
	editor = TrackEditorScript.new()
	editor.game = self
	add_child(editor)
	if autotest and "--edtest" in args:
		Engine.max_fps = 0
		show_menu()
		open_editor()
		editor._copy_builtin_index(1)
		editor.tname = "TESTBANA"
		editor._insert_point(3, Vector2(500, 0))
		editor._process(0.0)
		print("EDITOR: ", editor._info_l.text, " | ", editor._warn_l.text)
		editor._play()
	elif autotest:
		Engine.max_fps = 0
		start_race()
	else:
		show_menu()
		if "--editor" in args:
			open_editor()
			if "--editor3d" in args:
				editor._process(0.0)
				editor.toggle_view()
		if shots:
			await get_tree().create_timer(4.0).timeout
			_shot(("editor3d" if "--editor3d" in args else "editor") if "--editor" in args else "menu")
			get_tree().quit()


func _setup_input() -> void:
	var keys := {
		"gas": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"handbrake": [KEY_SPACE], "boost": [KEY_SHIFT], "reset": [KEY_R], "camera": [KEY_C], "pause": [KEY_ESCAPE, KEY_P],
	}
	for act in keys:
		if not InputMap.has_action(act):
			InputMap.add_action(act, 0.15)
		for k in keys[act]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(act, e)
	var pads := {"handbrake": JOY_BUTTON_B, "boost": JOY_BUTTON_A, "reset": JOY_BUTTON_Y, "camera": JOY_BUTTON_X, "pause": JOY_BUTTON_START}
	for act in pads:
		var j := InputEventJoypadButton.new()
		j.button_index = pads[act]
		InputMap.action_add_event(act, j)
	var axes := {"gas": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "brake": [JOY_AXIS_TRIGGER_LEFT, 1.0], "left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0]}
	for act in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = axes[act][0]
		m.axis_value = axes[act][1]
		InputMap.action_add_event(act, m)


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://hellwheels.cfg") == OK:
		for k in settings:
			settings[k] = cf.get_value("spel", k, settings[k])
	load_custom_tracks()
	settings["track"] = clampi(int(settings["track"]), 0, all_tracks().size() - 1)
	settings["car"] = clampi(int(settings["car"]), 0, CarTypes.TYPES.size() - 1)


# ------------------------------------------------------------------ egna banor

func all_tracks() -> Array:
	return Tracks.TRACKS + custom_tracks


func load_custom_tracks() -> void:
	custom_tracks.clear()
	DirAccess.make_dir_recursive_absolute("user://banor")
	var d := DirAccess.open("user://banor")
	if d == null:
		return
	var files := d.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string("user://banor/" + f))
		if data is Dictionary and data.has("points") and data["points"].size() >= 3:
			custom_tracks.append(custom_to_def(data, f))
	_custom_version += 1


## Gör om en sparad bana till samma form som de inbyggda banorna.
func custom_to_def(data: Dictionary, file: String) -> Dictionary:
	var th := clampi(int(data.get("theme", 0)), 0, Tracks.TRACKS.size() - 1)
	var d: Dictionary = Tracks.TRACKS[th].duplicate(true)
	d["name"] = "★ " + String(data.get("name", "EGEN BANA"))
	d["desc"] = "Egen bana (%s)." % file
	d["width"] = clampf(float(data.get("width", 18.0)), 10.0, 30.0)
	d["lanes"] = 3 if d["width"] >= 17.0 else 2
	d["base_y"] = float(data.get("base_y", 40.0))
	d["rain"] = bool(data.get("rain", d["rain"]))
	var pts: Array = []
	for p in data["points"]:
		pts.append([float(p[0]), float(p[1]), float(p[2]), float(p[3])])
	d["points"] = pts
	var cnt := pts.size()
	d["tunnels"] = data.get("tunnels", []).map(func(x): return int(x)).filter(func(x): return x >= 0 and x < cnt)
	d["open"] = data.get("open", []).map(func(x): return int(x)).filter(func(x): return x >= 0 and x < cnt)
	d["jumps"] = data.get("jumps", []).map(func(x): return [int(x[0]), float(x[1])]).filter(func(x): return x[0] >= 0 and x[0] < cnt)
	d["file"] = file
	return d


func open_editor() -> void:
	menu.close()
	if world != null:
		world.visible = false
	editor.open()


func close_editor() -> void:
	editor.close()
	if world != null:
		world.visible = true
	settings["track"] = clampi(int(settings["track"]), 0, all_tracks().size() - 1)
	show_menu()


func play_custom(file: String) -> void:
	for i in custom_tracks.size():
		if custom_tracks[i]["file"] == file:
			settings["track"] = Tracks.TRACKS.size() + i
	settings["mode"] = 0
	save_settings()
	editor.close()
	if world != null:
		world.visible = true
	start_race()


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("spel", k, settings[k])
	cf.save("user://hellwheels.cfg")


func diff(key: String):
	return DIFFS[settings["diff"]][key]


# ------------------------------------------------------------------ världen

func build_world() -> void:
	var key := "%d_%d_%d" % [settings["track"], settings["quality"], _custom_version]
	if key == _built and world != null:
		return
	clear_cars()
	if world != null:
		world.free()
	for c in cam.get_children():
		c.free()
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	track = TrackScript.new()
	world.add_child(track)
	track.build(all_tracks()[settings["track"]], settings["quality"])
	city = CityScript.new()
	world.add_child(city)
	city.build(track, settings["quality"])
	city.make_rain(cam)
	fx = FxScript.new()
	world.add_child(fx)
	debris_root = Node3D.new()
	world.add_child(debris_root)
	_built = key


func clear_cars() -> void:
	for c in cars:
		if is_instance_valid(c):
			c.free()
	cars.clear()
	player = null
	if preview_car != null and is_instance_valid(preview_car):
		preview_car.free()
	preview_car = null
	for d in _debris:
		if is_instance_valid(d[0]):
			d[0].free()
	_debris.clear()
	if fx != null:
		fx.clear_skids()
	finish_order.clear()
	_off_t.clear()
	_flip_t.clear()
	_stuck_t.clear()


func spawn_car(type_id: int, paint: Color, accent: Color, name_s: String, is_player: bool, xf: Transform3D):
	var car = CarScript.new()
	car.game = self
	car.is_player = is_player
	car.racer_name = name_s
	car.setup(type_id, paint, accent)
	car.transform = xf
	world.add_child(car)
	car.wrecked.connect(_on_wrecked)
	car.track_idx = track.nearest(car.global_position)
	car.track_offset = track.offset_of(car.track_idx, car.global_position)
	return car


func show_menu() -> void:
	get_tree().paused = false
	paused = false
	state = "menu"
	hud.hide_all()
	build_world()
	clear_cars()
	_spawn_preview()
	menu.open()
	cam.set_orbit(preview_car)
	if settings["music"] and not sfx.music.playing:
		sfx.music.play()


func _spawn_preview() -> void:
	if preview_car != null and is_instance_valid(preview_car):
		preview_car.free()
	var t: Dictionary = CarTypes.TYPES[settings["car"]]
	var xf: Transform3D = track.transform_at(track.length - 16.0, 0.0)
	preview_car = spawn_car(settings["car"], t["paint"], t["accent"], "DU", true, xf)
	preview_car.can_drive = false
	cam.set_orbit(preview_car)


func on_setting_changed(key: String) -> void:
	save_settings()
	if key == "track" or key == "quality":
		build_world()
		_spawn_preview()
	elif key == "car":
		_spawn_preview()
	elif key == "music":
		if settings["music"]:
			sfx.music.play()
		else:
			sfx.music.stop()


func start_race() -> void:
	get_tree().paused = false
	paused = false
	menu.close()
	build_world()
	clear_cars()
	race_time = 0.0
	sudden = false
	_result_timer = -1.0
	_last_beep = 99
	var mode := "race" if settings["mode"] == 0 else "derby"
	var opp: int = diff("opponents")
	var total := opp + 1
	var names := CarTypes.AI_NAMES.duplicate()
	names.shuffle()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var hw: float = track.width * 0.5
	for slot in total:
		var xf: Transform3D
		var reverse := false
		if mode == "race":
			var row := slot / 2
			var col := slot % 2
			xf = track.transform_at(track.length - 12.0 - row * 11.0, (col * 2 - 1) * hw * 0.42)
		else:
			reverse = slot % 2 == 1
			var s: float = track.length * float(slot) / total + 20.0
			xf = track.transform_at(s, rng.randf_range(-hw * 0.3, hw * 0.3), reverse)
		var is_p := slot == total - 1
		var car
		if is_p:
			var t: Dictionary = CarTypes.TYPES[settings["car"]]
			car = spawn_car(settings["car"], t["paint"], t["accent"], "DU", true, xf)
			car.damage_mult = diff("player_dmg")
			if autotest:
				car.driver = AIDriver.new(self, track, mode, 0.92, 0.3)
			else:
				car.driver = PlayerDriver.new()
			player = car
		else:
			var tid := rng.randi() % CarTypes.TYPES.size()
			var paint: Color = CarTypes.AI_PAINTS[rng.randi() % CarTypes.AI_PAINTS.size()]
			var acc: Color = CarTypes.AI_ACCENTS[rng.randi() % CarTypes.AI_ACCENTS.size()]
			car = spawn_car(tid, paint, acc, names[slot % names.size()], false, xf)
			var ai = AIDriver.new(self, track, mode, float(diff("skill")) * rng.randf_range(0.96, 1.03), diff("aggr"))
			ai.mistake_rate = diff("mistakes")
			if reverse:
				ai.dir = -1.0
			car.driver = ai
			car.damage_mult = diff("ai_dmg")
			car.top_mult = float(diff("top")) * rng.randf_range(0.97, 1.03)
			car.accel_mult = car.top_mult
		car.can_drive = false
		cars.append(car)
	state = "countdown"
	countdown = 4.0
	track.set_start_lights(0, false)
	cam.follow(player)
	hud.start(mode)
	if settings["music"] and not sfx.music.playing:
		sfx.music.play()


func _on_wrecked(car) -> void:
	if state == "menu":
		return
	if autotest:
		print("  VRAK %s t=%.1f" % [car.racer_name, race_time])
	var now := race_time
	var killer = car.last_hitter if car.last_hitter != null and now - car.last_hit_time < 5.0 and car.last_hitter != car else null
	if killer != null:
		killer.kills += 1
	if settings["mode"] == 1:
		car.eliminated = true
		var alive := _alive_count()
		car.place = alive + 1
		if killer != null:
			hud.feed("%s VRAKADE %s" % [killer.racer_name, car.racer_name], killer == player or car == player)
		else:
			hud.feed("%s ÄR UTE" % car.racer_name, car == player)
		if car == player and not autotest:
			hud.message("DU ÄR UTE", Color(1, 0.2, 0.2), 3.0, true)
			sfx.play("lose")
			_result_timer = 3.5
			state = "done"
		elif alive <= 1:
			for c in cars:
				if c.alive:
					c.place = 1
			if player.alive:
				hud.message("SIST KVAR!", Color(0.3, 1, 0.5), 3.0, true)
				sfx.play("win")
			_result_timer = 3.0
			state = "done"
	else:
		if car == player:
			hud.message("VRAKAD!", Color(1, 0.3, 0.1), 2.0, true)
		elif killer == player:
			hud.feed("DU VRAKADE %s" % car.racer_name, true)


func _alive_count() -> int:
	var n := 0
	for c in cars:
		if c.alive:
			n += 1
	return n


func add_debris(rb: Node) -> void:
	_debris.append([rb, Time.get_ticks_msec() / 1000.0])
	while _debris.size() > 50:
		var d: Array = _debris.pop_front()
		if is_instance_valid(d[0]):
			d[0].queue_free()


func shake(amount: float) -> void:
	cam.shake = maxf(cam.shake, amount)


# ------------------------------------------------------------------ loppet

func _physics_process(delta: float) -> void:
	if get_tree().paused or track == null:
		return
	if state == "menu":
		return
	for c in cars:
		_update_progress(c)
	match state:
		"countdown":
			countdown -= delta
			var lit := clampi(int((4.0 - countdown) / 0.75), 0, 5)
			track.set_start_lights(lit, false)
			var sec := int(ceil(countdown))
			if sec != _last_beep and sec <= 3 and sec >= 1:
				_last_beep = sec
				sfx.play("beep", -4.0)
				hud.message(str(sec), Color(1, 0.9, 0.3), 0.9, true)
			if countdown <= 0.0:
				state = "race"
				track.set_start_lights(5, true)
				sfx.play("go", -3.0)
				hud.message("KÖR!", Color(0.3, 1, 0.5), 1.0, true)
				for c in cars:
					c.can_drive = true
		"race", "done":
			race_time += delta
			_race_logic(delta)
	_update_places()
	if _result_timer > 0.0:
		_result_timer -= delta
		if _result_timer <= 0.0:
			_show_results()
	if autotest:
		_autotest_log(delta)
	if shots and state != "menu":
		var marks := [-1.0, 12.0]
		var tnow := race_time if state != "countdown" else -countdown
		if _shot_i < marks.size() and tnow >= marks[_shot_i]:
			_shot(str(_shot_i))
			_shot_i += 1
			if _shot_i >= marks.size():
				get_tree().quit()


func _update_progress(c) -> void:
	var L: float = track.length
	var prev: float = c.track_offset
	c.track_idx = track.nearest(c.global_position, c.track_idx)
	var off: float = track.offset_of(c.track_idx, c.global_position)
	c.track_offset = off
	if prev > L * 0.75 and off < L * 0.25:
		if c.half_ok:
			c.laps_done += 1
			c.half_ok = false
			if c.laps_done >= 2:
				var lt: float = race_time - c.lap_start
				c.lap_times.append(lt)
				if c.best_lap <= 0.0 or lt < c.best_lap:
					c.best_lap = lt
			c.lap_start = race_time
			if c == player and state == "race" and settings["mode"] == 0:
				_player_lap()
	elif prev < L * 0.25 and off > L * 0.75:
		c.laps_done -= 1
		c.half_ok = true
	if off > L * 0.4 and off < L * 0.6:
		c.half_ok = true
	c.progress = c.laps_done * L + off


func _player_lap() -> void:
	var laps: int = settings["laps"]
	if player.laps_done == laps:
		hud.message("SISTA VARVET", Color(1, 0.4, 0.8), 2.0, false)
		sfx.play("lap", -4.0)
	elif player.laps_done > 1 and player.laps_done <= laps:
		hud.message("VARV %d / %d" % [player.laps_done, laps], Color(0.4, 0.9, 1), 1.5, false)
		sfx.play("lap", -6.0)


func _race_logic(delta: float) -> void:
	var now := race_time
	var laps: int = settings["laps"]
	var hw: float = track.width * 0.5
	_reset_cd -= delta
	for c in cars:
		# mål
		if settings["mode"] == 0 and not c.finished and c.laps_done > laps:
			c.finished = true
			c.finish_time = race_time
			finish_order.append(c)
			if c == player:
				var pl := finish_order.size()
				hud.message("MÅL!  %d:a" % pl, Color(0.3, 1, 0.5) if pl == 1 else Color(1, 0.9, 0.3), 3.0, true)
				sfx.play("win" if pl <= 3 else "lose")
				c.driver = AIDriver.new(self, track, "race", 0.8, 0.0)
				state = "done"
				_result_timer = 3.0
		# vrak i racet kommer tillbaka
		if not c.alive:
			if settings["mode"] == 0 and now - c.wreck_time > 2.8:
				respawn(c, diff("heal") if c == player else 0.6)
			continue
		# utanför banan, upp och ner eller fast
		var p: Vector3 = c.global_position
		var tp: Vector3 = track.pts[c.track_idx]
		var lat: float = absf((p - tp).dot(track.rgts[c.track_idx]))
		var vy: float = p.y - tp.y
		var off := lat > hw + 4.0 or vy < -5.0
		_off_t[c] = (_off_t.get(c, 0.0) + delta) if off else 0.0
		var flip: bool = c.global_basis.y.y < 0.3 and c.speed < 5.0
		_flip_t[c] = (_flip_t.get(c, 0.0) + delta) if flip else 0.0
		var stuck: bool = c != player and c.speed < 1.5 and c.can_drive
		_stuck_t[c] = (_stuck_t.get(c, 0.0) + delta) if stuck else 0.0
		if _off_t[c] > 1.6 or _flip_t[c] > 2.2 or _stuck_t[c] > 7.0 or vy < -20.0:
			if c == player:
				hud.message("TILLBAKA PÅ BANAN", Color(0.5, 0.8, 1), 1.2, false)
			if autotest:
				print("  återstart %s s=%d off=%.1f flip=%.1f stuck=%.1f vy=%.1f lat=%.1f" % [c.racer_name, int(c.track_offset), _off_t[c], _flip_t[c], _stuck_t[c], vy, lat])
			respawn(c, 0.0)
	# Sudden death i Sist kvar
	if settings["mode"] == 1 and state == "race":
		if race_time > 150.0 and not sudden:
			sudden = true
			hud.message("SUDDEN DEATH", Color(1, 0.2, 0.2), 2.5, true)
		if sudden:
			for c in cars:
				if c.alive:
					c.take_damage(c.max_hp * 0.012 * delta)


func respawn(c, heal: float) -> void:
	var dirv := 1.0
	if c.driver != null and "dir" in c.driver:
		dirv = c.driver.dir
	var s: float = c.track_offset - 6.0 * dirv
	s = track.safe_respawn_offset(s)
	var hw: float = track.width * 0.5
	var lat := 0.0
	for cand in [0.0, -hw * 0.45, hw * 0.45, -hw * 0.2, hw * 0.2]:
		var p: Vector3 = track.point_at(s, cand)
		var free := true
		for o in cars:
			if o != c and o.global_position.distance_to(p) < 6.0:
				free = false
		if free:
			lat = cand
			break
	var xf: Transform3D = track.transform_at(s, lat, dirv < 0.0)
	c.respawn_at(xf, heal)
	_off_t[c] = 0.0
	_flip_t[c] = 0.0
	_stuck_t[c] = 0.0


func _update_places() -> void:
	if settings["mode"] == 0:
		var order := cars.duplicate()
		order.sort_custom(func(a, b):
			if a.finished != b.finished:
				return a.finished
			if a.finished:
				return a.finish_time < b.finish_time
			return a.progress > b.progress)
		for i in order.size():
			order[i].place = i + 1
	else:
		var alive := cars.filter(func(c): return c.alive)
		alive.sort_custom(func(a, b): return a.hp > b.hp)
		for i in alive.size():
			alive[i].place = i + 1


func _show_results() -> void:
	var rows: Array = []
	var order := cars.duplicate()
	order.sort_custom(func(a, b): return a.place < b.place)
	for c in order:
		var tname: String = CarTypes.TYPES[c.type_id]["name"]
		if settings["mode"] == 0:
			var t := _fmt(c.finish_time) if c.finished else "—"
			var bl := _fmt(c.best_lap) if c.best_lap > 0.0 else "—"
			rows.append([str(c.place), c.racer_name, tname, t, bl, c == player])
		else:
			var st := "HEL" if c.alive else "VRAK"
			rows.append([str(c.place), c.racer_name, tname, str(c.kills), st, c == player])
	var title := ""
	if settings["mode"] == 0:
		title = "VINST!" if player.place == 1 else "%d:A PLATS" % player.place
	else:
		title = "SIST KVAR!" if player.alive else "%d:A PLATS" % player.place
	hud.show_results(title, rows, settings["mode"])
	state = "results"
	if autotest:
		var airs := ""
		for c in cars:
			airs += "%s:%.1fs/%d " % [c.racer_name, c.get_meta("maxair", 0.0), c.get_meta("jumps", 0)]
		print("LUFTTID ", airs)
		print("RESULTAT: ", title)
		for r in rows:
			print("  ", r)
		get_tree().quit()


static func _fmt(t: float) -> String:
	var cs := int(round(t * 100.0))
	return "%d:%02d.%02d" % [cs / 6000, (cs / 100) % 60, cs % 100]


func fmt_time(t: float) -> String:
	return _fmt(t)


func toggle_pause() -> void:
	if state != "race" and state != "countdown" and state != "done":
		return
	paused = not paused
	get_tree().paused = paused
	hud.show_pause(paused)


func _unhandled_input(event: InputEvent) -> void:
	if state == "menu":
		return
	if event.is_action_pressed("pause"):
		if state == "results":
			show_menu()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if paused:
		return
	if state == "results":
		if event.is_action_pressed("ui_accept"):
			start_race()
		return
	if event.is_action_pressed("camera"):
		cam.mode = (cam.mode + 1) % 3
	if event.is_action_pressed("reset") and player != null and player.alive and _reset_cd <= 0.0 and state == "race":
		_reset_cd = 2.0
		respawn(player, 0.0)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	while not _debris.is_empty() and now - _debris[0][1] > 14.0:
		var d: Array = _debris.pop_front()
		if is_instance_valid(d[0]):
			d[0].queue_free()


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://shots")
	img.save_jpg("res://shots/t%d_%s.jpg" % [settings["track"], tag], 0.85)
	print("bild ", tag)


func _autotest_log(delta: float) -> void:
	for c in cars:
		if c.air_time > c.get_meta("maxair", 0.0):
			c.set_meta("maxair", c.air_time)
		if c.air_time > 0.5 and not c.get_meta("inair", false):
			c.set_meta("jumps", c.get_meta("jumps", 0) + 1)
		c.set_meta("inair", c.air_time > 0.5)
	_log_t += delta
	if _log_t >= 10.0:
		_log_t = 0.0
		var s := "t=%.0f " % race_time
		for c in cars:
			s += "| %s %s p%d v%d hp%d l%d %s " % [c.racer_name, CarTypes.TYPES[c.type_id]["name"], c.place, int(c.speed * 3.6), int(c.hp), c.laps_done, "" if c.alive else "VRAK"]
		print(s)
	if race_time > 420.0 and state != "results":
		print("TIDSGRÄNS")
		_show_results()
