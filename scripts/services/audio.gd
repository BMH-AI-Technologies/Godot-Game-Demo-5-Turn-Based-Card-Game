class_name GameAudio
extends Node

@export_group("Combat Sounds")
@export var player_attack_sound: AudioStream = preload("res://assets/Sounds/Minifantasy_Dungeon_SFX/07_human_atk_sword_2.wav")
@export var hit_sound: AudioStream = preload("res://assets/Sounds/10_Battle_SFX/15_Impact_flesh_02.wav")
@export var block_sound: AudioStream = preload("res://assets/Sounds/10_Battle_SFX/39_Block_03.wav")
@export var heal_sound: AudioStream = preload("res://assets/Sounds/8_Buffs_Heals_SFX/02_Heal_02.wav")
@export var buff_sound: AudioStream = preload("res://assets/Sounds/8_Buffs_Heals_SFX/16_Atk_buff_04.wav")
@export var debuff_sound: AudioStream = preload("res://assets/Sounds/8_Buffs_Heals_SFX/21_Debuff_01.wav")
@export var mana_sound: AudioStream = preload("res://assets/Sounds/10_UI_Menu_SFX/051_use_item_01.wav")
@export var interrupt_sound: AudioStream = preload("res://assets/Sounds/10_UI_Menu_SFX/029_Decline_09.wav")

var profile: GameProfile
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var voice_index: int = 0
var clips: Dictionary = {}

func setup(settings: GameProfile) -> void:
	profile = settings
	for bus_name in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.stream = load("res://assets/brackeys_platformer_assets/music/time_for_adventure.mp3")
	add_child(music)
	music.finished.connect(music.play)
	# Let combat sounds overlap without cutting off longer heal/buff tails.
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Effects"
		add_child(voice)
		voices.append(voice)
	clips = {
		"slash": player_attack_sound, "hit": hit_sound, "block": block_sound,
		"heal": heal_sound, "buff": buff_sound, "debuff": debuff_sound,
		"mana": mana_sound, "interrupt": interrupt_sound,
	}
	for cue in ["click", "error", "draw", "win", "loss"]:
		clips[cue] = make_tone(cue)
	apply_settings()
	if DisplayServer.get_name() != "headless":
		music.play()

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, profile.music_volume)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Effects"), linear_to_db(maxf(0.0001, profile.effects_volume)))

func play(cue: String) -> void:
	if clips.get(cue) == null or DisplayServer.get_name() == "headless":
		return
	var voice := voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	voice.stream = clips[cue]
	voice.play()

func make_tone(cue: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration: float = 0.18 if cue not in ["win", "loss"] else 0.6
	var samples: int = int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var frequency: float = {"click": 540.0, "error": 160.0, "draw": 480.0, "win": 520.0, "loss": 220.0}[cue]
	for i in range(samples):
		var t: float = float(i) / stream.mix_rate
		var progress: float = float(i) / samples
		var sweep: float = (1.0 + progress * 0.6) if cue == "win" else (1.0 - progress * 0.35)
		var wave: float = sin(TAU * frequency * sweep * t) + 0.22 * sin(TAU * frequency * 2.01 * t)
		var envelope: float = minf(1.0, t * 150) * pow(1.0 - progress, 2)
		bytes.encode_s16(i * 2, int(wave * envelope * 6500))
	stream.data = bytes
	return stream
