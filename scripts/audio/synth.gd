class_name Synth
extends RefCounted
## М'які «живі» звуки, синтезовані в коді (без аудіофайлів):
##  - glass(): скляний дзвін / дзвіночок — неповні гармоніки з різним згасанням;
##  - marimba(): теплий дерев'яний удар;
##  - pluck(): щипок струни (Karplus–Strong);
##  - whoosh(): м'який шелест (шум через фільтр, що повільно закривається);
##  - reverb(): невелика «кімнатна» реверберація (Schroeder), додає теплоти.
## Усі функції повертають PackedFloat32Array у діапазоні приблизно −1…1.

const RATE := 22050


static func silence(seconds: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(seconds * RATE))
	return s


## Додає звук `src` у `dst` з позиції `at_seconds` (з масштабом гучності).
static func mix(dst: PackedFloat32Array, src: PackedFloat32Array, at_seconds: float, gain: float = 1.0) -> void:
	var start := int(at_seconds * RATE)
	var n := mini(src.size(), dst.size() - start)
	for i in n:
		dst[start + i] += src[i] * gain


## Скло / дзвіночок. Партії: (множник частоти, амплітуда, швидкість згасання).
static func glass(freq: float, seconds: float, volume: float, bright: float = 1.0) -> PackedFloat32Array:
	var partials := [
		[1.0, 1.0, 5.0], [2.76, 0.42 * bright, 8.0],
		[5.40, 0.18 * bright, 13.0], [8.93, 0.06 * bright, 20.0],
	]
	var s := silence(seconds)
	var detune := 1.0035  # легкий «хорус» робить звук об'ємнішим
	for i in s.size():
		var t := float(i) / RATE
		var attack := minf(1.0, t / 0.003)
		var v := 0.0
		for p in partials:
			var f: float = freq * float(p[0])
			if f > RATE * 0.45:
				continue
			var env := exp(-t * float(p[2]))
			v += float(p[1]) * env * (sin(TAU * f * t) + 0.5 * sin(TAU * f * detune * t))
		s[i] = v * attack * volume / 1.5
	return s


## Тепла маримба: основний тон + 4-й і 10-й обертони, швидке згасання.
static func marimba(freq: float, seconds: float, volume: float) -> PackedFloat32Array:
	var s := silence(seconds)
	for i in s.size():
		var t := float(i) / RATE
		var attack := minf(1.0, t / 0.002)
		var v := sin(TAU * freq * t) * exp(-t * 9.0)
		v += 0.25 * sin(TAU * freq * 3.93 * t) * exp(-t * 22.0)
		v += 0.06 * sin(TAU * freq * 9.2 * t) * exp(-t * 40.0)
		s[i] = v * attack * volume
	return s


## Щипок струни (Karplus–Strong): шум у буфері, що поступово згладжується.
static func pluck(freq: float, seconds: float, volume: float, damping: float = 0.996, seed_value: int = 1) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var period := maxi(2, int(RATE / freq))
	var buf := PackedFloat32Array()
	buf.resize(period)
	var prev := 0.0
	for i in period:
		# Згладжений шум — м'якший, «дерев'яний» початок.
		prev = lerpf(prev, rng.randf_range(-1.0, 1.0), 0.5)
		buf[i] = prev
	var s := silence(seconds)
	var idx := 0
	for i in s.size():
		var cur := buf[idx]
		var nxt := buf[(idx + 1) % period]
		buf[idx] = (cur + nxt) * 0.5 * damping
		s[i] = cur * volume
		idx = (idx + 1) % period
	return s


## М'який шелест: шум через однополюсний фільтр, частота зрізу падає.
static func whoosh(seconds: float, volume: float, cutoff_from: float, cutoff_to: float, seed_value: int = 3) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var s := silence(seconds)
	var y := 0.0
	var y2 := 0.0
	for i in s.size():
		var k := float(i) / s.size()
		var fc := lerpf(cutoff_from, cutoff_to, k)
		var a := 1.0 - exp(-TAU * fc / RATE)
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		y2 += a * (y - y2)  # другий полюс — ще м'якше
		var env := sin(PI * minf(1.0, k * 1.15)) * (1.0 - k * 0.3)
		s[i] = y2 * env * volume * 3.0
	return s


## Однополюсний НЧ-фільтр — прибирає різкі верхи.
static func lowpass(s: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var out := s.duplicate()
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in out.size():
		y += a * (out[i] - y)
		out[i] = y
	return out


## Невелика реверберація (4 гребінчасті + 2 all-pass фільтри).
## `tail` — скільки секунд «хвоста» додати в кінці.
static func reverb(s: PackedFloat32Array, wet: float = 0.25, tail: float = 0.6, room: float = 0.78) -> PackedFloat32Array:
	var n := s.size() + int(tail * RATE)
	var dry := s.duplicate()
	dry.resize(n)
	var out := PackedFloat32Array()
	out.resize(n)
	for d in [1116, 1188, 1277, 1356]:
		var delay := int(d * RATE / 44100.0)
		var buf := PackedFloat32Array()
		buf.resize(delay)
		var idx := 0
		var damp := 0.0
		for i in n:
			var y := buf[idx]
			damp = y * 0.7 + damp * 0.3
			buf[idx] = dry[i] + damp * room
			out[i] += y
			idx = (idx + 1) % delay
	for d in [556, 441]:
		var delay := int(d * RATE / 44100.0)
		var buf := PackedFloat32Array()
		buf.resize(delay)
		var idx := 0
		for i in n:
			var b := buf[idx]
			var x := out[i]
			buf[idx] = x + b * 0.5
			out[i] = b - x * 0.5
			idx = (idx + 1) % delay
	for i in n:
		out[i] = dry[i] + out[i] * wet * 0.25
	return out


## М'яке обмеження піків (без різкого «кліпу»).
static func soft_limit(s: PackedFloat32Array, ceiling: float = 0.9) -> PackedFloat32Array:
	var peak := 0.0
	for v in s:
		peak = maxf(peak, absf(v))
	var out := s.duplicate()
	if peak > ceiling:
		var g := ceiling / peak
		for i in out.size():
			out[i] *= g
	return out


static func to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
