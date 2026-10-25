extends AudioStreamPlayer
var enabled: bool = true

func hit(healing: bool = false, critical: bool = false) -> void:
	if not enabled: return
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var count := 6600
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := i / 22050.0
		var wave: float
		if healing: wave = sin(TAU * 523.25 * t) * 0.4 + sin(TAU * 784 * t) * 0.2
		else: wave = sin(TAU * (95 if critical else 140) * t * exp(-t * 5)) * 0.6 + sin(i * 724.73) * exp(-t * 60) * 0.4
		var sample: int = int(clampf(wave * exp(-t * 16), -1, 1) * 14000)
		bytes.encode_s16(i * 2, sample)
	sound.data = bytes
	stream = sound
	volume_db = -10
	play()
