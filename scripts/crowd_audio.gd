extends RefCounted
## Layered stadium bed, cheers, and contact hits. Synthetic, not a recorded crowd or a voice.

const RATE := 16000


static func ambience() -> AudioStreamWAV:
	var seconds := 7.0
	var n := int(RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var noise := _Noise.new(19)
	var low := 0.0
	var mid := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var white := noise.next()
		low += (white - low) * 0.035
		mid += (white - mid) * 0.11
		var swell := 0.72 + 0.28 * sin(TAU * t / 7.0)
		var chant := 0.0
		var beat := fmod(t, 0.52)
		if beat < 0.045:
			chant = noise.next() * (1.0 - beat / 0.045) * 0.55
		var drone := sin(TAU * 92.0 * t) * 0.045 + sin(TAU * 138.0 * t) * 0.02
		samples[i] = (low * 0.55 + mid * 0.22 + chant + drone) * swell
	return _wav(samples, true)


static func cheer(big: bool) -> AudioStreamWAV:
	var seconds := 2.3 if big else 1.7
	var n := int(RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var noise := _Noise.new(91 if big else 53)
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var env := 1.0 - clampf(t / seconds, 0.0, 1.0)
		env = pow(env, 0.65)
		var attack := clampf(t / 0.04, 0.0, 1.0)
		var white := noise.next()
		low += (white - low) * 0.08
		var cutoff := clampf(0.08 + t * 0.25, 0.08, 0.45)
		band += (white - band) * cutoff
		var clap := 0.0
		if t < 0.03 or (big and t > 0.22 and t < 0.26):
			clap = noise.next() * 0.8
		var tone := 0.0
		var freqs := [220.0, 277.0, 349.0]
		if big:
			freqs = [196.0, 247.0, 311.0, 392.0]
		for f in freqs:
			var vib := 1.0 + 0.012 * sin(TAU * 5.0 * t)
			tone += sin(TAU * f * vib * t)
		tone /= float(freqs.size())
		var body := low * 0.7 + band * 0.45 + tone * 0.28 + clap
		samples[i] = body * env * attack * (1.15 if big else 0.95)
	return _wav(samples, false)


static func kick() -> AudioStreamWAV:
	return _hit(0.14, 70.0, 180.0, 41, 0.85)


static func post() -> AudioStreamWAV:
	return _hit(0.09, 420.0, 980.0, 77, 0.55)


static func net() -> AudioStreamWAV:
	return _hit(0.32, 140.0, 260.0, 23, 0.35)


static func land() -> AudioStreamWAV:
	return _hit(0.16, 90.0, 160.0, 13, 0.7)


static func _hit(seconds: float, low_hz: float, ring_hz: float, seed: int, noise_mix: float) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var noise := _Noise.new(seed)
	var band := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var attack := clampf(t / 0.004, 0.0, 1.0)
		var env := pow(1.0 - clampf(t / seconds, 0.0, 1.0), 1.4)
		var white := noise.next()
		band += (white - band) * 0.35
		var body := sin(TAU * low_hz * t) * exp(-t * 28.0)
		var ring := sin(TAU * ring_hz * t) * exp(-t * 46.0)
		samples[i] = (body * 0.7 + ring * 0.35 + band * noise_mix) * env * attack
	return _wav(samples, false)


static func _wav(samples: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = pcm
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


class _Noise:
	var _s: int

	func _init(seed: int) -> void:
		_s = seed

	func next() -> float:
		_s = (_s * 1103515245 + 12345) & 2147483647
		return float(_s) / 2147483647.0 * 2.0 - 1.0
