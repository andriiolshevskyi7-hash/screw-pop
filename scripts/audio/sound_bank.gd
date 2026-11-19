class_name SoundBank
extends RefCounted
## Набір звуків гри (з «Кульок у колбах» + звуки гвинтів). М'які, «скляні» й дерев'яні,
## з легкою реверберацією замість різких 8-бітних писків. Генерується у фоновому потоці.

## Пентатоніка до мажор (C6 D6 E6 G6 A6): кульки, що падають підряд,
## звучать як маленька мелодія.
const LAND_NOTES := [1046.5, 1174.66, 1318.51, 1567.98, 1760.0]


static func build() -> Dictionary:
	var out := {}
	# Підйом кульки: тихий щипок струни.
	out["select"] = _finish(Synth.lowpass(Synth.pluck(880.0, 0.45, 0.42, 0.994, 11), 4200.0), 0.18, 0.4)
	# Підйом кульки з колби: короткий «буль» угору (тон ковзає вгору) + щипок.
	var lift := Synth.silence(0.4)
	Synth.mix(lift, _sweep(520.0, 1040.0, 0.16, 0.34), 0.0)
	Synth.mix(lift, Synth.pluck(1046.5, 0.3, 0.16, 0.993, 13), 0.03)
	out["lift"] = _finish(Synth.lowpass(lift, 4200.0), 0.16, 0.35)
	# Кришечка на зібраній колбі: «чпок» корка (тон ковзає вниз) + дерев'яний стук.
	var cap := Synth.silence(0.3)
	Synth.mix(cap, _sweep(900.0, 260.0, 0.09, 0.42), 0.0)
	Synth.mix(cap, Synth.marimba(330.0, 0.2, 0.26), 0.035)
	out["cap"] = _finish(Synth.lowpass(cap, 3600.0), 0.12, 0.25)
	# Зірка на екрані перемоги: яскравий дзвіночок з іскринкою.
	var star := Synth.glass(1567.98, 0.9, 0.3, 0.9)
	Synth.mix(star, Synth.glass(3135.96, 0.4, 0.08, 0.5), 0.04)
	out["star"] = _finish(star, 0.3, 0.7)
	# Відкриття прихованої кульки: «вжух» угору і два скляні дзвіночки.
	var reveal := Synth.silence(0.75)
	Synth.mix(reveal, _sweep(700.0, 1600.0, 0.14, 0.2), 0.0)
	Synth.mix(reveal, Synth.glass(1318.51, 0.6, 0.18, 0.7), 0.1)
	Synth.mix(reveal, Synth.glass(1975.53, 0.5, 0.12, 0.6), 0.17)
	out["reveal"] = _finish(reveal, 0.25, 0.5)
	# Кнопки інтерфейсу: м'який дерев'яний «ток».
	out["tap"] = _finish(Synth.lowpass(Synth.marimba(587.33, 0.22, 0.4), 3200.0), 0.12, 0.25)
	# Переливання: шелест + низький м'який «бульк».
	var pour := Synth.whoosh(0.24, 0.22, 2600.0, 500.0)
	Synth.mix(pour, Synth.marimba(392.0, 0.2, 0.18), 0.02)
	out["pour"] = _finish(pour, 0.15, 0.3)
	# Приземлення: скляний дзвін на нотах пентатоніки.
	for i in LAND_NOTES.size():
		var f: float = LAND_NOTES[i]
		var s := Synth.glass(f, 0.65, 0.3, 0.75)
		Synth.mix(s, Synth.marimba(f * 0.5, 0.3, 0.16), 0.0)
		out["land%d" % i] = _finish(s, 0.22, 0.45)
	# Зібрана колба: скляне арпеджіо з довгим хвостом.
	var chime := Synth.silence(1.3)
	var notes := [1046.5, 1318.51, 1567.98, 2093.0]
	for i in notes.size():
		Synth.mix(chime, Synth.glass(notes[i], 1.1, 0.26, 0.8), i * 0.07)
	out["complete"] = _finish(chime, 0.32, 0.9)
	# Перемога: челеста — висхідне арпеджіо й акорд.
	var win := Synth.silence(2.4)
	var arp := [523.25, 659.25, 783.99, 1046.5, 1318.51, 1567.98]
	for i in arp.size():
		Synth.mix(win, Synth.glass(arp[i], 1.6, 0.24, 0.6), i * 0.085)
	for f in [523.25, 659.25, 783.99]:
		Synth.mix(win, Synth.marimba(f * 0.5, 0.9, 0.12), 0.55)
	out["win"] = _finish(win, 0.4, 1.0)
	# Помилка: глухий м'який удар замість дзижчання.
	var err := Synth.marimba(196.0, 0.28, 0.38)
	Synth.mix(err, Synth.marimba(185.0, 0.24, 0.2), 0.06)
	out["error"] = _finish(Synth.lowpass(err, 1400.0), 0.08, 0.2)
	# Відкручування: швидке металеве «тр-р-р» (серія клацань із зростанням тону).
	var unscrew := Synth.silence(0.24)
	for k in 7:
		Synth.mix(unscrew, Synth.lowpass(Synth.pluck(1400.0 + k * 140.0, 0.05, 0.16, 0.9, 20 + k), 6000.0), k * 0.024)
	out["unscrew"] = _finish(unscrew, 0.06, 0.15)
	# «Чпок»: гвинт вискакує з дірки — тон різко вгору + м'який удар.
	var pop := Synth.silence(0.22)
	Synth.mix(pop, _sweep(380.0, 1500.0, 0.07, 0.5), 0.0)
	Synth.mix(pop, Synth.marimba(880.0, 0.14, 0.18), 0.02)
	out["pop"] = _finish(Synth.lowpass(pop, 5200.0), 0.12, 0.25)
	# Гвинт ліг у лоток буфера: глухий дерев'яний стук.
	var tray := Synth.marimba(392.0, 0.2, 0.36)
	Synth.mix(tray, Synth.marimba(784.0, 0.12, 0.1), 0.0)
	out["tray"] = _finish(Synth.lowpass(tray, 2600.0), 0.1, 0.2)
	# Повна коробка: кришка «клац» + дзвінке арпеджіо.
	var box := Synth.silence(1.1)
	Synth.mix(box, Synth.marimba(523.25, 0.18, 0.3), 0.0)
	var box_notes := [1046.5, 1318.51, 1567.98, 2093.0]
	for i in box_notes.size():
		Synth.mix(box, Synth.glass(box_notes[i], 0.9, 0.22, 0.8), 0.05 + i * 0.06)
	out["box"] = _finish(box, 0.3, 0.8)
	# Нова коробка приїхала: короткий «вжух».
	var arrive := Synth.whoosh(0.22, 0.16, 3200.0, 900.0, 9)
	Synth.mix(arrive, Synth.marimba(659.25, 0.15, 0.12), 0.12)
	out["arrive"] = _finish(arrive, 0.12, 0.25)
	# Пластина зірвалась: шелест униз.
	out["drop"] = _finish(Synth.whoosh(0.3, 0.2, 2400.0, 400.0, 11), 0.1, 0.2)
	# Пластина вдарилась і відскочила: м'який глухий удар.
	var thud := Synth.marimba(130.81, 0.3, 0.5)
	Synth.mix(thud, Synth.marimba(196.0, 0.2, 0.2), 0.01)
	out["thud"] = _finish(Synth.lowpass(thud, 900.0), 0.1, 0.25)
	# Гвинт накритий: тихий «тук-тук».
	var blocked := Synth.marimba(293.66, 0.12, 0.3)
	Synth.mix(blocked, Synth.marimba(277.18, 0.12, 0.26), 0.08)
	out["blocked"] = _finish(Synth.lowpass(blocked, 1800.0), 0.06, 0.15)
	# Хитка пластина повертається: скрип (тон гойдається) + дерев'яний стук.
	var swing := Synth.silence(0.6)
	Synth.mix(swing, _sweep(320.0, 210.0, 0.35, 0.18), 0.0)
	Synth.mix(swing, _sweep(240.0, 300.0, 0.2, 0.12), 0.3)
	Synth.mix(swing, Synth.marimba(196.0, 0.25, 0.22), 0.05)
	out["swing"] = _finish(Synth.lowpass(swing, 2400.0), 0.15, 0.3)
	# Хамелеон перемкнув колір: короткий «блиск» угору-вниз.
	var flip := Synth.silence(0.3)
	Synth.mix(flip, Synth.glass(1760.0, 0.25, 0.1, 0.6), 0.0)
	Synth.mix(flip, Synth.glass(1318.51, 0.25, 0.08, 0.6), 0.05)
	out["flip"] = _finish(flip, 0.15, 0.3)
	# Бомба: тихий «тік» на останніх ходах.
	out["tick"] = _finish(Synth.lowpass(Synth.pluck(1975.5, 0.06, 0.24, 0.9, 61), 6000.0), 0.0, 0.0)
	# Вибух: низький гуркіт із шумом.
	var boom := Synth.whoosh(0.7, 0.4, 1800.0, 120.0, 62)
	Synth.mix(boom, Synth.marimba(65.41, 0.6, 0.6), 0.0)
	Synth.mix(boom, Synth.marimba(98.0, 0.4, 0.3), 0.02)
	out["boom"] = _finish(Synth.lowpass(boom, 1600.0), 0.2, 0.5)
	# Сейф відкрито: клацання механізму + дзвіночки.
	var safe_snd := Synth.silence(0.9)
	for k in 3:
		Synth.mix(safe_snd, Synth.lowpass(Synth.pluck(880.0 - k * 60.0, 0.06, 0.26, 0.9, 63 + k), 4000.0), k * 0.07)
	Synth.mix(safe_snd, Synth.glass(1567.98, 0.6, 0.18, 0.7), 0.25)
	Synth.mix(safe_snd, Synth.glass(2093.0, 0.5, 0.14, 0.6), 0.33)
	out["safe"] = _finish(safe_snd, 0.25, 0.5)
	var wavs := {}
	for key in out:
		wavs[key] = Synth.to_wav(out[key])
	return wavs


## Синусоїда, тон якої експоненційно ковзає від f0 до f1 (з м'якою атакою й згасанням).
static func _sweep(f0: float, f1: float, seconds: float, volume: float) -> PackedFloat32Array:
	var s := Synth.silence(seconds)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / Synth.RATE
		var k := t / seconds
		var f := f0 * pow(f1 / f0, k)
		phase += TAU * f / Synth.RATE
		var env := minf(1.0, t / 0.004) * pow(1.0 - k, 1.6)
		s[i] = (sin(phase) + 0.18 * sin(phase * 2.0)) * env * volume
	return s


static func _finish(s: PackedFloat32Array, wet: float, tail: float) -> PackedFloat32Array:
	var r := Synth.reverb(s, wet, tail) if wet > 0.0 else s
	return Synth.soft_limit(r, 0.85)
