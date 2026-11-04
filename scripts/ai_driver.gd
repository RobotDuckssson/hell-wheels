extends RefCounted
## Datorförare. I racet följer den banan, planerar farten inför kurvorna och kör om.
## I "Sist kvar" väljer den ett offer, kör mot det längs banan och rammar.

var game
var track
var mode := "race"
var skill := 0.9          # hur nära greppgränsen den vågar köra i kurvorna
var aggression := 0.3     # hur gärna den knuffar och jagar spelaren
var lane := 0.0
var lane_target := 0.0
var dir := 1.0            # 1 = med banan, -1 = mot (bara i Sist kvar)
var target = null
var _retarget := 0.0
var _commit := 0.0
var _stuck := 0.0
var _reverse := 0.0
var _reverse_steer := 1.0
var _drift := 0.0
var _rng := RandomNumberGenerator.new()
var mistake_rate := 0.0   # chans per sekund att göra ett misstag
var _mistake := ""
var _mistake_t := 0.0
var _wobble := 0.0


func _init(p_game, p_track, p_mode: String, p_skill: float, p_aggr: float) -> void:
	game = p_game
	track = p_track
	mode = p_mode
	skill = p_skill
	aggression = p_aggr
	_rng.randomize()
	lane = _rng.randf_range(-0.5, 0.5)
	lane_target = lane


func drive(car, delta: float) -> void:
	if not car.alive:
		return
	var L: float = track.length
	var hw: float = track.width * 0.5
	var spd: float = car.speed
	var off: float = car.track_offset

	if mode == "derby":
		_derby_think(car, delta)

	# Omkörning: byt fil om någon är i vägen framför
	var xf: Transform3D = car.global_transform
	var inv := xf.affine_inverse()
	for other in game.cars:
		if other == car or not other.alive:
			continue
		var lp: Vector3 = inv * other.global_position
		if lp.z < -3.0 and lp.z > -28.0 and absf(lp.x) < 2.6 and (mode == "race" or other != target):
			if other.speed < spd + 3.0:
				lane_target = clampf(lane + (0.55 if lp.x < 0.0 else -0.55), -0.75, 0.75)
	lane = move_toward(lane, lane_target, delta * 0.35)
	if absf(lane - lane_target) < 0.02 and _rng.randf() < delta * 0.15:
		lane_target = _rng.randf_range(-0.55, 0.55)

	# Misstag: för hög fart in i kurvan, sen inbromsning, slarvig styrning eller tappad koncentration
	if _mistake_t > 0.0:
		_mistake_t -= delta
		if _mistake_t <= 0.0:
			_mistake = ""
	elif mistake_rate > 0.0 and car.can_drive and _rng.randf() < mistake_rate * delta:
		_mistake = ["overcook", "late", "wobble", "lift"][_rng.randi() % 4]
		_mistake_t = _rng.randf_range(1.5, 3.5)
		_wobble = _rng.randf() * TAU

	var near_jump: bool = track.jump_ahead(off, 140.0, dir)
	var edge_open: bool = track.open[car.track_idx] == 1 or track.open[(car.track_idx + int(25 * dir) + track.n) % track.n] == 1
	var look := 9.0 + spd * 0.5
	var lane_k := 0.15 if near_jump else (0.45 if edge_open else 1.0)
	var lat := lane * (hw - 2.5) * lane_k
	# Knuffas i racet om spelaren kör bredvid
	if mode == "race" and aggression > 0.4 and game.player != null and game.player != car and game.player.alive:
		var pl: Vector3 = inv * game.player.global_position
		if absf(pl.z) < 8.0 and absf(pl.x) < 7.0:
			lat += signf(pl.x) * aggression * 2.5 * dir
	var aim: Vector3 = track.point_at(off + look * dir, lat)

	var attack := false
	if mode == "derby" and target != null and is_instance_valid(target) and target.alive:
		var to: Vector3 = target.global_position - car.global_position
		var d := to.length()
		var df: float = absf(_track_delta(off, target.track_offset))
		if d < 55.0 and df < 70.0:
			attack = true
			aim = target.global_position + target.linear_velocity * clampf(d / maxf(spd, 5.0), 0.0, 0.9) * 0.8

	var local: Vector3 = inv * aim
	var ang := atan2(local.x, -local.z)
	var steer := clampf(ang * 2.4, -1.0, 1.0)

	# Fartplanering inför kurvor
	var a_lat: float = float(car.stats["grip"]) * car.grip_mult * car.GRIP_SCALE * 9.81 * 0.95 * skill
	if _mistake == "overcook":
		a_lat *= 1.45
	var decel := 20.0 * skill
	if _mistake == "late":
		decel *= 2.4   # bromsar för sent
	var v_allow := 999.0
	var idx: int = car.track_idx
	var n: int = track.n
	var horizon := int(clampf((spd * spd / (2.0 * decel) + 25.0) / track.STEP, 8.0, 110.0))
	for k in range(2, horizon, 2):
		var j := (idx + int(k * dir) + n) % n
		var vs := sqrt(a_lat * track.radius[j])
		var va := sqrt(vs * vs + 2.0 * decel * k * track.STEP)
		v_allow = minf(v_allow, va)
	if absf(ang) > 1.0:
		v_allow = minf(v_allow, 13.0)
	if near_jump:
		v_allow = maxf(v_allow, 34.0)
	if attack:
		v_allow = maxf(v_allow, 30.0) if absf(ang) < 0.5 else v_allow

	var thr := 1.0
	if spd > v_allow + 1.5:
		thr = -1.0
	elif spd > v_allow - 1.5:
		thr = 0.25
	# Gummiband: håll ihop fältet lite
	if mode == "race" and game.player != null and game.player != car:
		var gap: float = car.progress - game.player.progress
		if gap > 180.0:
			thr = minf(thr, 0.8)
	if _mistake == "lift":
		thr = minf(thr, 0.45)
	if _mistake == "wobble":
		steer = clampf(steer + sin(Time.get_ticks_msec() * 0.006 + _wobble) * 0.45, -1.0, 1.0)
	car.boost_in = false
	if thr > 0.9 and car.boost > 0.35 and absf(ang) < 0.12 and v_allow > spd + 20.0 and _rng.randf() < 0.02 + skill * 0.02:
		car.boost_in = true
	if attack and absf(ang) < 0.2 and car.boost > 0.1:
		car.boost_in = true
	if car.boosting and (absf(ang) > 0.25 or v_allow < spd + 5.0):
		car.boost_in = false

	# Sladd i snäva kurvor
	car.handbrake = false
	if absf(steer) > 0.95 and spd > 22.0 and spd < 45.0 and skill > 0.85:
		_drift = 0.25
	if _drift > 0.0:
		_drift -= delta
		car.handbrake = true

	# Fastkörd?
	if car.can_drive:
		if spd < 2.0 and thr > 0.0 and _reverse <= 0.0:
			_stuck += delta
		else:
			_stuck = maxf(0.0, _stuck - delta * 0.5)
		if _stuck > 1.2:
			_stuck = 0.0
			_reverse = 1.3
			_reverse_steer = -signf(steer) if absf(steer) > 0.1 else (1.0 if _rng.randf() < 0.5 else -1.0)
	if _reverse > 0.0:
		_reverse -= delta
		thr = -1.0
		steer = _reverse_steer
		car.boost_in = false
	car.throttle = thr
	car.steer_in = steer


func _track_delta(a: float, b: float) -> float:
	var L: float = track.length
	var d := fposmod(b - a, L)
	if d > L * 0.5:
		d -= L
	return d


func _derby_think(car, delta: float) -> void:
	_retarget -= delta
	_commit -= delta
	if _retarget <= 0.0 or target == null or not is_instance_valid(target) or not target.alive:
		_retarget = _rng.randf_range(2.5, 5.0)
		var best = null
		var bs := 1e9
		for other in game.cars:
			if other == car or not other.alive:
				continue
			var s: float = absf(_track_delta(car.track_offset, other.track_offset))
			s += car.global_position.distance_to(other.global_position) * 0.5
			if other == game.player:
				s *= lerpf(1.0, 0.45, aggression)
			s *= _rng.randf_range(0.8, 1.2)
			if s < bs:
				bs = s
				best = other
		target = best
	if target != null and _commit <= 0.0:
		var d := _track_delta(car.track_offset, target.track_offset)
		var nd := 1.0 if d >= 0.0 else -1.0
		if nd != dir:
			dir = nd
		_commit = 5.0
