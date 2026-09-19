extends SceneTree
## Synthesizes the five interface sounds of Drone Rally Cam and saves them as WAV files with
## the names UI.SOUNDS expects: short, clean blips that sit under the engine noise.
## Usage: godot --headless --path godot -s res://debug/tools/build_ui_sounds.gd


const OUTPUT_DIR := "res://Assets/Audio/UI"
const RATE := 44100


func _init() -> void:
	var sounds := {
		"hover": hover(),
		"click": click(),
		"back": back(),
		"tick": tick(),
		"error": error(),
	}
	for sound_name: String in sounds:
		var path := "%s/%s.wav" % [OUTPUT_DIR, sound_name]
		var err := to_stream(sounds[sound_name]).save_to_wav(path)
		if err != OK:
			push_error("Could not save %s (%s)" % [path, error_string(err)])
			quit(1)
			return
		print("%s: %d ms" % [path, roundi((sounds[sound_name] as PackedFloat32Array).size() * 1000.0 / RATE)])
	quit(0)


## Blip: sine at 1.8 kHz, 30 ms, 2 ms attack and an exponential decay, very soft.
static func hover() -> PackedFloat32Array:
	var samples := silence(0.030)
	for i in samples.size():
		var t := float(i) / RATE
		samples[i] = sin(TAU * 1800.0 * t) * envelope(t, 0.002, 0.009) * 0.22
	return samples


## Two tones going up (1.2 then 1.6 kHz, 25 ms each) over a 3 ms noise transient.
static func click() -> PackedFloat32Array:
	var samples := silence(0.050)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in samples.size():
		var t := float(i) / RATE
		var local := fmod(t, 0.025)
		var frequency := 1200.0 if t < 0.025 else 1600.0
		var value := sin(TAU * frequency * t) * envelope(local, 0.002, 0.008) * 0.4
		if t < 0.003:
			value += rng.randf_range(-1.0, 1.0) * (1.0 - t / 0.003) * 0.25
		samples[i] = value
	return samples


## Sweep down from 1.4 to 0.9 kHz in 70 ms.
static func back() -> PackedFloat32Array:
	var samples := silence(0.070)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var frequency := lerpf(1400.0, 900.0, t / 0.070)
		phase += TAU * frequency / RATE
		samples[i] = sin(phase) * envelope(t, 0.003, 0.022) * 0.36
	return samples


## 8 ms of filtered noise, then a 2 kHz tone of 15 ms: the notch of a slider.
static func tick() -> PackedFloat32Array:
	var samples := silence(0.024)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var filtered := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var value := 0.0
		if t >= 0.006:
			value = sin(TAU * 2000.0 * t) * envelope(t - 0.006, 0.001, 0.005) * 0.26
		if t < 0.008:
			filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.35)
			value += filtered * (1.0 - t / 0.008) * 0.3
		samples[i] = value
	return samples


## Two low pulses at 220 Hz with a little distortion, 180 ms in all.
static func error() -> PackedFloat32Array:
	var samples := silence(0.180)
	for i in samples.size():
		var t := float(i) / RATE
		var pulse_start := 0.0 if t < 0.09 else 0.1
		var local := t - pulse_start
		if local < 0.0 or local > 0.07:
			continue
		var gate := minf(local / 0.004, 1.0) * minf((0.07 - local) / 0.012, 1.0)
		var tone := sin(TAU * 220.0 * t) + 0.3 * sin(TAU * 440.0 * t)
		samples[i] = tanh(tone * 1.8) * gate * 0.34
	return samples


static func silence(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var _err := samples.resize(int(seconds * RATE))
	samples.fill(0.0)
	return samples


## Linear attack then exponential decay with time constant `decay`.
static func envelope(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return exp(-(t - attack) / decay)


static func to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	var _err := data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, clampi(roundi(samples[i] * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
