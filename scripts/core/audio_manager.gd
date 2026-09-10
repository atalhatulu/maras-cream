extends Node

# Ses Havuzları ve Önceden Üretilmiş WAV Kaynakları
var _samples: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _ambience_player: AudioStreamPlayer = null
const SFX_PLAYER_COUNT: int = 10

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_players()
	_generate_all_procedural_sounds()
	_connect_gameplay_events()
	_start_ambience()

func _init_players() -> void:
	for i in range(SFX_PLAYER_COUNT):
		var p = AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_sfx_players.append(p)
		
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = &"Master"
	_ambience_player.volume_db = -24.0
	add_child(_ambience_player)

func _connect_gameplay_events() -> void:
	EventBus.scoop_dive_started.connect(func(_t, _f, _h): play_sfx("scoop_dive", 0.95))
	EventBus.scoop_filled.connect(func(_f): play_sfx("scoop_snap", 1.05))
	EventBus.ice_cream_placed_on_cone.connect(func(_f, _idx): play_sfx("scoop_land", 1.0 + float(_idx) * 0.04))
	EventBus.cone_taken.connect(func(): play_sfx("cone_pickup", 1.0))
	EventBus.cone_dropped.connect(func(): play_sfx("cone_dropped", 0.9))
	EventBus.cone_discarded.connect(func(): play_sfx("cone_pickup", 0.8))
	EventBus.topping_added_to_cone.connect(func(_t): play_sfx("topping_squeeze", 1.1))
	EventBus.bell_rung.connect(func(_c): play_sfx("bell_hit", 1.0 + randf_range(-0.04, 0.06)))
	EventBus.order_completed.connect(func(_ord, score):
		if score >= 3.0:
			play_sfx("order_success", 1.0)
		else:
			play_sfx("order_fail", 0.9)
	)
	EventBus.money_changed.connect(func(_m, diff):
		if diff > 0.0:
			play_sfx("money_gain", randf_range(0.95, 1.1))
	)
	EventBus.upgrade_purchased.connect(func(_id, _lvl): play_sfx("upgrade_purchase", 1.0))
	EventBus.customer_arrived.connect(func(_c, _o): play_sfx("customer_arrive", 1.0))
	EventBus.maras_trick_performed.connect(func(_cnt, _mult): play_sfx("trick_swoosh", 1.0 + float(_cnt) * 0.1))
	EventBus.cone_critical_tilt.connect(func(_ratio): play_sfx("cone_wobble", 1.0, -6.0))

# --- SES ÇALMA MERKEZİ ---

func play_sfx(sfx_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _samples.has(sfx_name):
		return
		
	var stream: AudioStreamWAV = _samples[sfx_name]
	
	# Müsait olan bir player bul
	var target_player: AudioStreamPlayer = null
	for p in _sfx_players:
		if not p.playing:
			target_player = p
			break
			
	if target_player == null:
		target_player = _sfx_players[0] # En eskisini kullan
		
	target_player.stream = stream
	target_player.pitch_scale = clampf(pitch, 0.5, 2.0)
	target_player.volume_db = volume_db
	target_player.play()

func _start_ambience() -> void:
	if _samples.has("ambience") and _ambience_player:
		_ambience_player.stream = _samples["ambience"]
		_ambience_player.play()

# --- PROCEDURAL SES SENTEZLEYİCİ ---

func _generate_all_procedural_sounds() -> void:
	_samples["scoop_dive"] = _gen_tone_burst(160.0, 80.0, 0.14, 0.5, true)
	_samples["scoop_snap"] = _gen_snap_click(880.0, 1320.0, 0.12)
	_samples["scoop_land"] = _gen_tone_burst(220.0, 110.0, 0.15, 0.6, false)
	_samples["cone_pickup"] = _gen_noise_click(0.08, 600.0)
	_samples["cone_dropped"] = _gen_tone_burst(90.0, 35.0, 0.45, 0.8, true)
	_samples["cone_wobble"] = _gen_tone_burst(110.0, 70.0, 0.16, 0.45, true)
	_samples["trick_swoosh"] = _gen_tone_burst(650.0, 260.0, 0.14, 0.4, true)
	_samples["topping_squeeze"] = _gen_squeeze_squirt(520.0, 780.0, 0.16)
	_samples["bell_hit"] = _gen_bell_chime(1318.5, 0.65) # Parlak E6 Çan tınlaması
	_samples["order_success"] = _gen_chord_fanfare([523.25, 659.25, 783.99, 1046.5], 0.45) # C5-E5-G5-C6 Akor
	_samples["order_fail"] = _gen_chord_fanfare([220.0, 207.65, 196.0], 0.35)
	_samples["money_gain"] = _gen_coin_jingle(1760.0, 2349.0, 0.22)
	_samples["upgrade_purchase"] = _gen_arpeggio([440.0, 554.37, 659.25, 880.0], 0.28)
	_samples["customer_arrive"] = _gen_bell_chime(987.77, 0.35)
	_samples["customer_happy"] = _gen_arpeggio([587.33, 880.0, 1174.66], 0.22)
	_samples["customer_impatient"] = _gen_tone_burst(330.0, 290.0, 0.12, 0.4, false)
	_samples["customer_disappointed"] = _gen_tone_burst(260.0, 180.0, 0.25, 0.5, false)
	_samples["customer_wow"] = _gen_tone_burst(440.0, 880.0, 0.35, 0.6, false)
	_samples["button_click"] = _gen_tone_burst(650.0, 500.0, 0.05, 0.3, false)
	_samples["button_hover"] = _gen_tone_burst(440.0, 480.0, 0.03, 0.15, false)
	_samples["ambience"] = _gen_ambience_hum(4.0)

func _create_wav(byte_data: PackedByteArray, sample_rate: int = 22050, loop: bool = false) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = byte_data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = byte_data.size() / 2
	return wav

func _gen_bell_chime(freq: float, duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var env = exp(-t * 6.5) # Çan tınlama sönümü
		var s1 = sin(TAU * freq * t)
		var s2 = sin(TAU * (freq * 2.76) * t) * 0.4 # Harmonik çan çınlaması
		var s3 = sin(TAU * (freq * 5.4) * t) * 0.15
		var sample = (s1 + s2 + s3) * env * 0.75
		var val16 = int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val16)
		
	return _create_wav(bytes, sample_rate)

func _gen_tone_burst(start_f: float, end_f: float, duration: float, volume: float, add_noise: bool) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var progress = float(i) / float(total_samples)
		var cur_f = lerpf(start_f, end_f, progress)
		var env = sin(progress * PI)
		var s = sin(TAU * cur_f * t)
		if add_noise:
			s = lerpf(s, randf_range(-1.0, 1.0), 0.35)
		var sample = s * env * volume
		var val16 = int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val16)
		
	return _create_wav(bytes, sample_rate)

func _gen_snap_click(f1: float, f2: float, duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var env = exp(-t * 32.0)
		var s = sin(TAU * f1 * t) + sin(TAU * f2 * t) * 0.6
		var sample = s * env * 0.7
		var val16 = int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val16)
		
	return _create_wav(bytes, sample_rate)

func _gen_squeeze_squirt(start_f: float, end_f: float, duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var progress = float(i) / float(total_samples)
		var cur_f = lerpf(start_f, end_f, sin(progress * PI))
		var env = exp(-progress * 4.0) * sin(progress * PI)
		var s = sin(TAU * cur_f * t) + randf_range(-0.3, 0.3)
		var sample = s * env * 0.6
		var val16 = int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val16)
		
	return _create_wav(bytes, sample_rate)

func _gen_coin_jingle(f1: float, f2: float, duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var env1 = exp(-t * 18.0)
		var env2 = exp(-max(0.0, t - 0.05) * 16.0) if t >= 0.05 else 0.0
		var s = (sin(TAU * f1 * t) * env1) + (sin(TAU * f2 * t) * env2 * 0.8)
		var sample = s * 0.6
		var val16 = int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val16)
		
	return _create_wav(bytes, sample_rate)

func _gen_chord_fanfare(freqs: Array, duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var env = exp(-t * 5.0)
		var sum = 0.0
		for f in freqs:
			sum += sin(TAU * float(f) * t)
		sum /= float(freqs.size())
		var sample = sum * env * 0.8
		var val16 = int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val16)
		
	return _create_wav(bytes, sample_rate)

func _gen_arpeggio(freqs: Array, duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)
	var note_dur = duration / float(freqs.size())
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var note_idx = mini(int(t / note_dur), freqs.size() - 1)
		var note_t = fmod(t, note_dur)
		var env = exp(-note_t * 12.0)
		var cur_freq = float(freqs[note_idx])
		var sample = sin(TAU * cur_freq * t) * env * 0.7
		var val16 = int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val16)
		
	return _create_wav(bytes, sample_rate)

func _gen_noise_click(duration: float, freq: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var env = exp(-t * 40.0)
		var s = (sin(TAU * freq * t) * 0.4) + randf_range(-0.6, 0.6)
		var sample = s * env * 0.6
		var val16 = int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val16)
		
	return _create_wav(bytes, sample_rate)

func _gen_ambience_hum(duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var hum = sin(TAU * 50.0 * t) * 0.15 + sin(TAU * 100.0 * t) * 0.08
		var air = randf_range(-0.04, 0.04)
		var sample = hum + air
		var val16 = int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, val16)
		
	return _create_wav(bytes, sample_rate, true)
