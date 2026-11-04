extends Node
## Alla ljud räknas fram när spelet startar, så projektet behöver inga ljudfiler.

const RATE := 22050

var streams: Dictionary = {}
var _p2d: Array[AudioStreamPlayer] = []
var _p3d: Array[AudioStreamPlayer3D] = []
var _i2 := 0
var _i3 := 0
var _rng := RandomNumberGenerator.new()
var music: AudioStreamPlayer


func _ready() -> void:
	_rng.seed = 777
	streams["engine"] = _engine()
	streams["whine"] = _whine()
	streams["skid"] = _skid()
	streams["crash"] = _crash(0.35, 0.8)
	streams["crash_big"] = _crash(0.8, 1.0)
	streams["scrape"] = _scrape()
	streams["explosion"] = _explosion()
	streams["beep"] = _tone([880.0], 0.2, 0.5)
	streams["go"] = _tone([1320.0, 1760.0], 0.5, 0.5)
	streams["click"] = _tone([1200.0], 0.04, 0.3)
	streams["select"] = _tone([660.0, 990.0], 0.12, 0.35)
	streams["boost"] = _whoosh()
	streams["lap"] = _chime([784.0, 1046.0, 1318.0], 0.14)
	streams["win"] = _chime([523.0, 659.0, 784.0, 1046.0], 0.22)
	streams["lose"] = _chime([392.0, 330.0, 262.0], 0.3)
	streams["music"] = _music()
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_p2d.append(p)
	for i in 24:
		var q := AudioStreamPlayer3D.new()
		q.unit_size = 14.0
		q.max_distance = 260.0
		add_child(q)
		_p3d.append(q)
	music = AudioStreamPlayer.new()
	music.stream = streams["music"]
	music.volume_db = -13.0
	add_child(music)


func play(name: String, vol := 0.0, pitch := 1.0) -> void:
	var p := _p2d[_i2]
	_i2 = (_i2 + 1) % _p2d.size()
	p.stream = streams[name]
	p.volume_db = vol
	p.pitch_scale = pitch
	p.play()


func play3d(name: String, pos: Vector3, vol := 0.0) -> void:
	var p := _p3d[_i3]
	_i3 = (_i3 + 1) % _p3d.size()
	p.stream = streams[name]
	p.volume_db = vol
	p.pitch_scale = _rng.randf_range(0.85, 1.15)
	p.global_position = pos
	p.play()


func make_loop(name: String, parent: Node3D, vol: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[name]
	p.volume_db = vol
	p.unit_size = 10.0
	p.max_distance = 180.0
	p.autoplay = true
	parent.add_child(p)
	return p


# ------------------------------------------------------------------ syntes

func _wav(data: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		var v := int(clampf(data[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = data.size()
	return s


func _engine() -> AudioStreamWAV:
	var n := RATE / 2
	var d := PackedFloat32Array()
	d.resize(n)
	var base := 56.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for h in range(1, 9):
			v += sin(TAU * base * h * t + h * 1.3) / pow(h, 0.9)
		# tändpulser
		var pulse := pow(0.5 + 0.5 * sin(TAU * base * 2.0 * t), 6.0)
		lp = lerpf(lp, _rng.randf_range(-1, 1), 0.08)
		d[i] = (v * 0.22 + pulse * 0.25 + lp * 0.6) * 0.55
	return _wav(d, true)


func _whine() -> AudioStreamWAV:
	var n := RATE / 2
	var d := PackedFloat32Array()
	d.resize(n)
	for i in n:
		var t := float(i) / RATE
		d[i] = (sin(TAU * 440.0 * t) * 0.5 + sin(TAU * 886.0 * t) * 0.2 + sin(TAU * 1330.0 * t) * 0.08) * 0.5
	return _wav(d, true)


func _skid() -> AudioStreamWAV:
	var n := RATE
	var d := PackedFloat32Array()
	d.resize(n)
	var a := 0.0
	var b := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := _rng.randf_range(-1, 1)
		a = lerpf(a, x, 0.35)
		b = lerpf(b, a, 0.35)
		var squeal := sin(TAU * 1150.0 * t + sin(TAU * 7.0 * t) * 2.0) * 0.25
		d[i] = ((a - b) * 1.6 + squeal) * 0.6
	return _wav(d, true)


func _crash(dur: float, power: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := 0.0
	var parts := [_rng.randf_range(300, 500), _rng.randf_range(700, 1100), _rng.randf_range(1500, 2300)]
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * (9.0 / dur))
		lp = lerpf(lp, _rng.randf_range(-1, 1), 0.5)
		var ring := 0.0
		for f in parts:
			ring += sin(TAU * f * t) * exp(-t * 14.0)
		var thud := sin(TAU * 55.0 * t * (1.0 - t)) * exp(-t * 12.0)
		d[i] = (lp * 0.8 * env + ring * 0.18 + thud * 0.7) * power
	return _wav(d, false)


func _scrape() -> AudioStreamWAV:
	var n := int(RATE * 0.18)
	var d := PackedFloat32Array()
	d.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := sin(PI * t / 0.18)
		d[i] = _rng.randf_range(-1, 1) * env * 0.4 * (0.6 + 0.4 * sin(TAU * 90.0 * t))
	return _wav(d, false)


func _explosion() -> AudioStreamWAV:
	var n := int(RATE * 1.8)
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 2.2) * minf(1.0, t * 200.0)
		lp = lerpf(lp, _rng.randf_range(-1, 1), 0.12)
		lp2 = lerpf(lp2, lp, 0.1)
		var crack := _rng.randf_range(-1, 1) * exp(-t * 25.0)
		d[i] = clampf((lp2 * 5.0 + crack * 0.6) * env, -1.0, 1.0)
	return _wav(d, false)


func _tone(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var d := PackedFloat32Array()
	d.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for f in freqs:
			v += sin(TAU * f * t)
		d[i] = v / freqs.size() * vol * minf(1.0, (dur - t) * 30.0) * minf(1.0, t * 400.0)
	return _wav(d, false)


func _chime(freqs: Array, step: float) -> AudioStreamWAV:
	var dur := step * freqs.size() + 0.5
	var n := int(RATE * dur)
	var d := PackedFloat32Array()
	d.resize(n)
	for k in freqs.size():
		var start := int(k * step * RATE)
		for i in range(start, n):
			var t := float(i - start) / RATE
			d[i] += sin(TAU * freqs[k] * t) * exp(-t * 5.0) * 0.3 + sin(TAU * freqs[k] * 2.0 * t) * exp(-t * 8.0) * 0.08
	return _wav(d, false)


func _whoosh() -> AudioStreamWAV:
	var n := int(RATE * 0.7)
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := lerpf(0.05, 0.6, t / 0.7)
		lp = lerpf(lp, _rng.randf_range(-1, 1), k)
		d[i] = lp * sin(PI * t / 0.7) * 0.7
	return _wav(d, false)


## Enkel synthwave-slinga: bas, ackord och trummor. 8 takter i 100 bpm.
func _music() -> AudioStreamWAV:
	var bpm := 100.0
	var beat := 60.0 / bpm
	var bars := 8
	var n := int(RATE * beat * 4.0 * bars)
	var d := PackedFloat32Array()
	d.resize(n)
	var roots := [45, 45, 41, 41, 43, 43, 40, 40]       # A A F F G G E E (midi)
	var chords := [[0, 3, 7], [0, 3, 7], [0, 4, 7], [0, 4, 7], [0, 4, 7], [0, 4, 7], [0, 3, 7], [0, 4, 7]]
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var bar := int(t / (beat * 4.0)) % bars
		var tb := fmod(t, beat)
		var t8 := fmod(t, beat * 0.5)
		var root: int = roots[bar]
		var fb := 440.0 * pow(2.0, (root - 12 - 69) / 12.0)
		var bass := (fmod(t * fb, 1.0) * 2.0 - 1.0) * exp(-t8 * 6.0) * 0.32
		var pad := 0.0
		for iv in chords[bar]:
			var f := 440.0 * pow(2.0, (root + 12 + iv - 69) / 12.0)
			pad += (fmod(t * f, 1.0) * 2.0 - 1.0) + (fmod(t * f * 1.004, 1.0) * 2.0 - 1.0)
		lp = lerpf(lp, pad, 0.04)
		var kick := sin(TAU * 50.0 * tb * (1.0 - tb * 2.0)) * exp(-tb * 18.0) * 0.8
		var beat_i := int(t / beat) % 4
		var snare := 0.0
		if beat_i == 1 or beat_i == 3:
			snare = _rng.randf_range(-1, 1) * exp(-tb * 16.0) * 0.32
		var hat := _rng.randf_range(-1, 1) * exp(-t8 * 60.0) * 0.08
		d[i] = clampf(bass + lp * 0.05 + kick + snare + hat, -1.0, 1.0) * 0.75
	return _wav(d, true)
