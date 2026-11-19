extends Node
## Звуки та вібрація (автозавантаження `Sfx`).
## Звуки синтезуються під час запуску — окремі аудіофайли не потрібні.

const MIX_RATE := 22050
const PLAYERS := 6

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_player: AudioStreamPlayer
## Готова доріжка музики "default" (генерується у фоновому потоці).
var _tracks := {}
var _track_tasks := {}
var _current_track := ""
var _sfx_task := -1


func _ready() -> void:
	for i in PLAYERS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	# Звуки генеруються у фоновому потоці (синтез з реверберацією).
	_sfx_task = WorkerThreadPool.add_task(_build_sfx)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -9.0
	add_child(_music_player)
	update_music()


func _build_sfx() -> void:
	_sfx_ready.call_deferred(SoundBank.build())


func _sfx_ready(streams: Dictionary) -> void:
	_streams = streams


func _exit_tree() -> void:
	if _sfx_task != -1:
		WorkerThreadPool.wait_for_task_completion(_sfx_task)
	for task in _track_tasks.values():
		WorkerThreadPool.wait_for_task_completion(task)


## Вмикає/вимикає музику.
func update_music() -> void:
	if _music_player == null:
		return
	if not GameState.music_on:
		_music_player.stop()
		return
	var want := "default"
	if not _tracks.has(want):
		# Синтез у фоновому потоці, щоб не гальмувати гру.
		if not _track_tasks.has(want):
			_track_tasks[want] = WorkerThreadPool.add_task(_build_music)
		return
	if _current_track != want or not _music_player.playing:
		_current_track = want
		_music_player.stream = _tracks[want]
		_music_player.play()


func _music_ready(track: String, stream: AudioStreamWAV) -> void:
	_tracks[track] = stream
	update_music()


## Спокійний цикл акордів C–G–Am–F з арпеджіо та басом (16 секунд).
func _build_music() -> void:
	var rate := MIX_RATE
	var chord_len := 2.0
	var chords := [
		[261.63, 329.63, 392.0], [196.0, 246.94, 293.66],
		[220.0, 261.63, 329.63], [174.61, 220.0, 261.63],
		[261.63, 329.63, 392.0], [196.0, 246.94, 293.66],
		[220.0, 261.63, 329.63], [174.61, 220.0, 261.63],
	]
	var arp_pattern := [0, 1, 2, 1, 2, 1, 0, 1]
	var n := int(chord_len * chords.size() * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var step := 0.25
	for i in n:
		var t := float(i) / rate
		var ci := int(t / chord_len)
		var ct := t - ci * chord_len
		var chord: Array = chords[ci]
		# Пед: м'яка атака та згасання в межах акорду.
		var pad_env := minf(1.0, ct / 0.4) * minf(1.0, (chord_len - ct) / 0.5)
		var s := 0.0
		for f in chord:
			s += sin(TAU * f * 0.5 * t) * 0.07 * pad_env
		# Арпеджіо восьмими.
		var si := int(ct / step)
		var st := ct - si * step
		var af: float = chord[arp_pattern[si % arp_pattern.size()]] * 2.0
		s += sin(TAU * af * t) * 0.11 * exp(-st * 9.0) * minf(1.0, st / 0.005)
		# Бас на сильні долі.
		var bt := fmod(ct, 1.0)
		s += sin(TAU * chord[0] * 0.5 * t) * 0.16 * exp(-bt * 3.0) * minf(1.0, bt / 0.01)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	_music_ready.call_deferred("default", wav)


func play(sound_name: String, pitch: float = 1.0) -> void:
	if not GameState.sound_on or not _streams.has(sound_name):
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _streams[sound_name]
	p.pitch_scale = pitch
	p.play()


## Гвинт ліг у коробку: ноти пентатоніки по гнізду — виходить маленька мелодія.
func play_land(order: int) -> void:
	play("land%d" % (order % SoundBank.LAND_NOTES.size()), randf_range(0.99, 1.01))


func vibrate(duration_ms: int) -> void:
	if not GameState.vibration_on:
		return
	if OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(duration_ms)
