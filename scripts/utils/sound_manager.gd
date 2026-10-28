class_name SoundManager
extends RefCounted

static var _wav_cache: Dictionary = {}
static var _synth_cache: Dictionary = {}

static func _load_wav(file_name: String) -> AudioStream:
	var path: String = "res://assets/audio/" + file_name
	if _wav_cache.has(path):
		return _wav_cache[path]
	if ResourceLoader.exists(path):
		var s: AudioStream = load(path) as AudioStream
		if s != null:
			_wav_cache[path] = s
			return s
	return null

static func _play_stream(parent: Node, stream: AudioStream, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent) or stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = vol_db
	player.pitch_scale = pitch
	parent.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

## เสียงร้องปลุกพลัง/คำรามก่อนออกสกิล (Battle Cry / Voice Shout)
static func play_battle_cry(parent: Node, hero_id: String, archetype: String, is_enemy: bool, is_covenant: bool = false) -> void:
	if is_enemy:
		# เสียงคำรามปีศาจ/บอสอเวจี + เสียง ugh ทุ้มต่ำ
		var ugh: AudioStream = _load_wav("ugh.wav")
		var pitch_val: float = 0.58 if archetype == "boss" else 0.72
		_play_stream(parent, ugh, 2.0, pitch_val)
		_play_stream(parent, _get_synth_roar("monster", 0.55 if is_covenant else 0.38), 1.5, randf_range(0.88, 1.05))
		return

	# แยกเสียงร้องชาย / หญิง ตามตัวละคร
	var is_female: bool = hero_id in ["hero_mage", "gacha_archer_r", "gacha_cleric_sr", "gacha_reaper_ssr", "gacha_valkyrie_leg"]
	if is_female:
		var f_voice: AudioStream = _load_wav("girl_yeaaaaah.wav")
		_play_stream(parent, f_voice, -2.5, randf_range(1.05, 1.18))
		_play_stream(parent, _get_synth_roar("female_shout", 0.42), -1.0, randf_range(0.96, 1.06))
	else:
		var m_voice: AudioStream = _load_wav("ugh.wav")
		var m_pitch: float = 0.82 if archetype in ["knight", "boss"] else 0.98
		_play_stream(parent, m_voice, 3.0, m_pitch * randf_range(0.95, 1.05))
		_play_stream(parent, _get_synth_roar("male_warcry", 0.48), 1.5, randf_range(0.94, 1.04))

## เสียงชาร์จเพิ่มพลังตอนคัทซีน (Power-Up Aura Charge)
static func play_power_up_charge(parent: Node, is_covenant: bool = false) -> void:
	var spell_wav: AudioStream = _load_wav("cast_a_spell_sound.wav")
	var rumble_wav: AudioStream = _load_wav("wildrumble_healing.wav")
	_play_stream(parent, spell_wav, -1.0, 0.92 if is_covenant else 1.08)
	if is_covenant:
		_play_stream(parent, rumble_wav, 0.0, 0.95)
	_play_stream(parent, _get_synth_power_charge(is_covenant), 0.5, 1.0)

## เสียงเหวี่ยงอาวุธพุ่งโจมตี
static func play_weapon_whoosh(parent: Node) -> void:
	var w_wav: AudioStream = _load_wav("whoosh.wav")
	_play_stream(parent, w_wav, 3.0, randf_range(0.88, 1.12))
	_play_stream(parent, _get_synth_slash(), 1.0, randf_range(0.92, 1.08))

## เสียงปะทะคมดาบ / โจมตีกระแทกเป้าหมายอย่างรุนแรง
static func play_heavy_impact(parent: Node, is_magic: bool = false, is_crit_or_elem: bool = false) -> void:
	var smack: AudioStream = _load_wav("smack.wav")
	var hammer: AudioStream = _load_wav("hammer.wav")
	_play_stream(parent, smack, 1.5, randf_range(0.85, 1.05))
	_play_stream(parent, hammer, 2.5, randf_range(0.75, 0.95))

	if is_magic:
		var m_shot: AudioStream = _load_wav("short_magic_shot.wav")
		_play_stream(parent, m_shot, -1.5, randf_range(0.90, 1.10))
	if is_crit_or_elem:
		var volt: AudioStream = _load_wav("voltage.wav")
		_play_stream(parent, volt, 1.0, randf_range(0.85, 1.05))

	_play_stream(parent, _get_synth_impact(is_crit_or_elem), 3.0, randf_range(0.90, 1.08))

## สังเคราะห์เสียงคำราม/ปลุกพลังด้วย Formant Synthesis (16-bit PCM WAV)
static func _get_synth_roar(style: String, duration: float) -> AudioStreamWAV:
	var key: String = "%s_%.2f" % [style, duration]
	if _synth_cache.has(key):
		return _synth_cache[key]

	var mix_rate: int = 22050
	var total_samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	var base_freq: float = 135.0
	var f1: float = 650.0
	var f2: float = 1150.0
	if style == "monster":
		base_freq = 78.0
		f1 = 420.0
		f2 = 880.0
	elif style == "female_shout":
		base_freq = 255.0
		f1 = 820.0
		f2 = 1650.0

	var phase0: float = 0.0
	var phase1: float = 0.0
	var phase2: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(mix_rate)
		var norm_t: float = float(i) / float(total_samples)
		var env: float = sin(norm_t * PI)
		if norm_t < 0.12:
			env = norm_t / 0.12
		else:
			env = pow(1.0 - (norm_t - 0.12) / 0.88, 0.7)

		# Pitch curve พุ่งขึ้นตอนตะโกนปลุกพลัง
		var pitch_curve: float = 1.0 + 0.18 * sin(norm_t * PI * 0.85) + 0.025 * sin(t * 32.0)
		phase0 += (base_freq * pitch_curve) / float(mix_rate)
		phase1 += (f1 * pitch_curve) / float(mix_rate)
		phase2 += (f2 * pitch_curve) / float(mix_rate)

		# Sawtooth glottal source + Formants + Breath growl
		var glottal: float = (fmod(phase0, 1.0) * 2.0 - 1.0) * 0.45
		var form1: float = sin(phase1 * TAU) * 0.35
		var form2: float = sin(phase2 * TAU) * 0.20
		var growl: float = (randf() * 2.0 - 1.0) * (0.28 if style == "monster" else 0.14)

		var sample: float = clampf((glottal + form1 + form2 + growl) * env * 0.85, -1.0, 1.0)
		var pcm: int = int(sample * 32760.0)
		data.encode_s16(i * 2, pcm)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	_synth_cache[key] = wav
	return wav

## สังเคราะห์เสียงชาร์จออร่าเพิ่มพลัง (Power-Up Rising Arcane Chord)
static func _get_synth_power_charge(is_covenant: bool) -> AudioStreamWAV:
	var key: String = "charge_" + str(is_covenant)
	if _synth_cache.has(key):
		return _synth_cache[key]

	var mix_rate: int = 22050
	var duration: float = 0.68 if is_covenant else 0.45
	var total_samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	for i in range(total_samples):
		var t: float = float(i) / float(mix_rate)
		var p: float = float(i) / float(total_samples)
		var env: float = sin(p * PI)
		var sweep_freq: float = lerpf(160.0, 720.0 if is_covenant else 520.0, p * p)
		var w1: float = sin(t * sweep_freq * TAU) * 0.40
		var w2: float = sin(t * sweep_freq * 1.5 * TAU) * 0.30
		var pulse: float = 0.7 + 0.3 * sin(t * 45.0)
		var sample: float = clampf((w1 + w2) * pulse * env * 0.75, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32760.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	_synth_cache[key] = wav
	return wav

## สังเคราะห์เสียงคมดาบแหวกอากาศ (Metallic Blade Slash)
static func _get_synth_slash() -> AudioStreamWAV:
	var key: String = "slash_sfx"
	if _synth_cache.has(key):
		return _synth_cache[key]

	var mix_rate: int = 22050
	var duration: float = 0.22
	var total_samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	for i in range(total_samples):
		var t: float = float(i) / float(mix_rate)
		var p: float = float(i) / float(total_samples)
		var env: float = pow(1.0 - p, 1.6)
		var ring: float = sin(t * lerpf(1800.0, 620.0, p) * TAU) * 0.45
		var air: float = (randf() * 2.0 - 1.0) * 0.45
		var sample: float = clampf((ring + air) * env * 0.8, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32760.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	_synth_cache[key] = wav
	return wav

## สังเคราะห์เสียงปะทะหนักหน่วง (Sub-bass Thump + Armor Clash)
static func _get_synth_impact(is_heavy: bool) -> AudioStreamWAV:
	var key: String = "impact_" + str(is_heavy)
	if _synth_cache.has(key):
		return _synth_cache[key]

	var mix_rate: int = 22050
	var duration: float = 0.34 if is_heavy else 0.25
	var total_samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	for i in range(total_samples):
		var t: float = float(i) / float(mix_rate)
		var p: float = float(i) / float(total_samples)
		var env: float = pow(1.0 - p, 2.2)
		var sub_freq: float = lerpf(145.0, 38.0, sqrt(p))
		var sub: float = sin(t * sub_freq * TAU) * 0.65
		var clang: float = sin(t * 1120.0 * TAU) * exp(-p * 8.0) * 0.35
		var crunch: float = (randf() * 2.0 - 1.0) * exp(-p * 5.0) * 0.45
		var sample: float = clampf((sub + clang + crunch) * env * 0.95, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32760.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	_synth_cache[key] = wav
	return wav
