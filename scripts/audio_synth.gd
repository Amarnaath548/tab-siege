class_name AudioSynthSingleton
extends Node

# AudioSynth - Procedural sound generator for Tab Siege
# Generates lightweight PCM WAV sounds in memory for zero-dependency sound effects.

var _players: Array[AudioStreamPlayer] = []
var _player_index: int = 0
const MAX_PLAYERS: int = 8

var _sounds: Dictionary = {}

func _ready() -> void:
	# Instantiate a pool of AudioStreamPlayers
	for i in range(MAX_PLAYERS):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	
	_generate_all_sounds()

func _play_sound(sound_name: String, pitch_scale: float = 1.0, volume_db: float = -4.0) -> void:
	if not _sounds.has(sound_name):
		return
	var stream: AudioStreamWAV = _sounds[sound_name]
	var player: AudioStreamPlayer = _players[_player_index]
	_player_index = (_player_index + 1) % MAX_PLAYERS
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.play()

func play_click() -> void:
	_play_sound("click", randf_range(0.95, 1.05), -6.0)

func play_focus_switch() -> void:
	_play_sound("focus_start", 1.0, -5.0)

func play_focus_active() -> void:
	_play_sound("focus_active", 1.0, -3.0)

func play_drag_pickup() -> void:
	_play_sound("pickup", 1.1, -5.0)

func play_drag_drop() -> void:
	_play_sound("drop", 1.0, -4.0)

func play_refresh_rush() -> void:
	_play_sound("refresh", 1.0, -3.0)

func play_strike() -> void:
	_play_sound("strike", randf_range(0.9, 1.1), -3.0)

func play_sacrifice() -> void:
	_play_sound("sacrifice", 1.0, -3.0)

func play_shield_hit() -> void:
	_play_sound("shield_hit", 1.2, -4.0)

func play_triangulation_start() -> void:
	_play_sound("triangulation_on", 1.0, -2.0)

func play_triangulation_lost() -> void:
	_play_sound("triangulation_off", 1.0, -3.0)

func play_victory() -> void:
	_play_sound("victory", 1.0, -2.0)

func play_defeat() -> void:
	_play_sound("defeat", 1.0, -2.0)

func play_merge() -> void:
	_play_sound("merge", 1.2, -4.0)

func _generate_all_sounds() -> void:
	_sounds["click"] = _generate_tone(0.04, 880.0, 440.0, "square", 0.3)
	_sounds["pickup"] = _generate_tone(0.06, 300.0, 600.0, "sine", 0.4)
	_sounds["drop"] = _generate_tone(0.08, 500.0, 200.0, "sine", 0.5)
	_sounds["focus_start"] = _generate_tone(0.12, 440.0, 660.0, "triangle", 0.4)
	_sounds["focus_active"] = _generate_tone(0.20, 660.0, 880.0, "sine", 0.5)
	_sounds["refresh"] = _generate_arpeggio([440.0, 554.0, 659.0, 880.0, 1108.0], 0.05, "sine", 0.4)
	_sounds["strike"] = _generate_noise_hit(0.12, 0.6)
	_sounds["sacrifice"] = _generate_tone(0.25, 600.0, 150.0, "sawtooth", 0.5)
	_sounds["shield_hit"] = _generate_tone(0.15, 1200.0, 800.0, "triangle", 0.5)
	_sounds["triangulation_on"] = _generate_arpeggio([523.0, 659.0, 783.0, 1046.0], 0.08, "triangle", 0.5)
	_sounds["triangulation_off"] = _generate_tone(0.20, 400.0, 200.0, "sawtooth", 0.4)
	_sounds["victory"] = _generate_arpeggio([523.0, 659.0, 783.0, 1046.0, 1318.0], 0.12, "triangle", 0.6)
	_sounds["defeat"] = _generate_arpeggio([400.0, 350.0, 300.0, 220.0], 0.14, "sawtooth", 0.5)
	_sounds["merge"] = _generate_arpeggio([600.0, 800.0, 1200.0], 0.06, "sine", 0.5)

func _generate_tone(duration: float, start_freq: float, end_freq: float, wave_type: String, amplitude: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(duration * sample_rate)
	var byte_array := PackedByteArray()
	byte_array.resize(num_samples * 2) # 16-bit mono

	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(num_samples)
		var freq: float = lerpf(start_freq, end_freq, progress)
		var phase: float = TAU * freq * t
		var envelope: float = 1.0 - progress
		
		var sample_val: float = 0.0
		match wave_type:
			"sine":
				sample_val = sin(phase)
			"square":
				sample_val = 1.0 if sin(phase) >= 0.0 else -1.0
			"triangle":
				sample_val = 2.0 * absf(2.0 * (t * freq - floorf(t * freq + 0.5))) - 1.0
			"sawtooth":
				sample_val = 2.0 * (t * freq - floorf(t * freq + 0.5))
		
		sample_val = clampf(sample_val * amplitude * envelope, -1.0, 1.0)
		var int_val: int = int(sample_val * 32767.0)
		byte_array.encode_s16(i * 2, int_val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = byte_array
	return stream

func _generate_arpeggio(freqs: Array, step_time: float, wave_type: String, amplitude: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var total_duration: float = step_time * freqs.size()
	var num_samples: int = int(total_duration * sample_rate)
	var byte_array := PackedByteArray()
	byte_array.resize(num_samples * 2)

	var samples_per_step: int = int(step_time * sample_rate)
	for step in range(freqs.size()):
		var freq: float = freqs[step]
		for s in range(samples_per_step):
			var idx: int = step * samples_per_step + s
			if idx >= num_samples:
				break
			var t: float = float(s) / float(sample_rate)
			var env: float = 1.0 - (float(s) / float(samples_per_step))
			var phase: float = TAU * freq * t
			var val: float = sin(phase) if wave_type == "sine" else (2.0 * absf(2.0 * (t * freq - floorf(t * freq + 0.5))) - 1.0)
			val = clampf(val * amplitude * env, -1.0, 1.0)
			byte_array.encode_s16(idx * 2, int(val * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = byte_array
	return stream

func _generate_noise_hit(duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(duration * sample_rate)
	var byte_array := PackedByteArray()
	byte_array.resize(num_samples * 2)

	for i in range(num_samples):
		var progress: float = float(i) / float(num_samples)
		var envelope: float = (1.0 - progress) * (1.0 - progress)
		var noise: float = randf_range(-1.0, 1.0)
		var sample_val: float = clampf(noise * amplitude * envelope, -1.0, 1.0)
		byte_array.encode_s16(i * 2, int(sample_val * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = byte_array
	return stream
