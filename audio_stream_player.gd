extends Node
@export var fade_time: float = 4.0
@export var low_hp_fade_out_time: float = 2.0
@export var low_hp_fade_in_time: float = 4.0
@onready var song_2: AudioStreamPlayer = $ArgentReversedYesIdkAName
@onready var song_3: AudioStreamPlayer = $ErrorsThemePhaseExt
@onready var song_4: AudioStreamPlayer = $ButcherThemeAmd
@onready var low_hp_song_1: AudioStreamPlayer = $Argent5
@onready var low_hp_song_2: AudioStreamPlayer = $Argent4
@onready var low_hp_song_3: AudioStreamPlayer = $Argent3Or4NoName
var current_song: AudioStreamPlayer = null
var current_low_hp_song: AudioStreamPlayer = null
var fading := false
var low_hp_active := false
var music_tween: Tween = null
func _ready():
	randomize()
	add_to_group("music_controller")
	song_2.volume_db = -30.0
	song_3.volume_db = 0.0
	song_4.volume_db = 0.0
	song_2.stop()
	song_3.stop()
	song_4.stop()
	low_hp_song_1.stop()
	low_hp_song_2.stop()
	low_hp_song_3.stop()
	low_hp_song_1.volume_db = -80.0
	low_hp_song_2.volume_db = -80.0
	low_hp_song_3.volume_db = -80.0
	var songs: Array[AudioStreamPlayer] = [
		song_2,
		song_3,
		song_4
	]
	current_song = songs.pick_random()
	current_song.volume_db = get_song_volume(current_song)
	current_song.play()
	current_song.finished.connect(_on_main_song_finished)
	low_hp_song_1.finished.connect(_on_low_hp_song_finished)
	low_hp_song_2.finished.connect(_on_low_hp_song_finished)
	low_hp_song_3.finished.connect(_on_low_hp_song_finished)
	call_deferred("connect_to_player")
func connect_to_player():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.has_signal("low_hp_changed"):
		if not player.low_hp_changed.is_connected(set_low_hp):
			player.low_hp_changed.connect(set_low_hp)
		if player.low_hp_active:
			set_low_hp(true)
func get_song_volume(song: AudioStreamPlayer) -> float:
	if song == song_2:
		return -30.0
	return 0.0
func set_low_hp(active: bool):
	if active:
		start_low_hp()
	else:
		stop_low_hp()
func start_low_hp():
	if low_hp_active:
		return
	low_hp_active = true
	if music_tween != null:
		music_tween.kill()
	var fade_out := create_tween()
	fade_out.set_parallel(true)
	fade_out.tween_property(
		song_2,
		"volume_db",
		-80.0,
		low_hp_fade_out_time
	)
	fade_out.tween_property(
		song_3,
		"volume_db",
		-80.0,
		low_hp_fade_out_time
	)
	fade_out.tween_property(
		song_4,
		"volume_db",
		-80.0,
		low_hp_fade_out_time
	)
	await fade_out.finished
	if not low_hp_active:
		return
	song_2.stop()
	song_3.stop()
	song_4.stop()
	play_random_low_hp_song()
func play_random_low_hp_song():
	if not low_hp_active:
		return
	var songs: Array[AudioStreamPlayer] = [
		low_hp_song_1,
		low_hp_song_2,
		low_hp_song_3
	]
	var available_songs: Array[AudioStreamPlayer] = []
	for song in songs:
		if song != current_low_hp_song:
			available_songs.append(song)
	if available_songs.is_empty():
		available_songs = songs.duplicate()
	current_low_hp_song = available_songs.pick_random()
	for song in songs:
		if song != current_low_hp_song:
			song.stop()
			song.volume_db = -80.0
	current_low_hp_song.volume_db = -80.0
	current_low_hp_song.play()
	var fade_in := create_tween()
	fade_in.tween_property(
		current_low_hp_song,
		"volume_db",
		0.0,
		low_hp_fade_in_time
	)
func _on_low_hp_song_finished():
	if not low_hp_active:
		return
	play_random_low_hp_song()
func stop_low_hp():
	if not low_hp_active:
		return
	low_hp_active = false
	if music_tween != null:
		music_tween.kill()
	var low_hp_songs: Array[AudioStreamPlayer] = [
		low_hp_song_1,
		low_hp_song_2,
		low_hp_song_3
	]
	for song in low_hp_songs:
		song.stop()
		song.volume_db = -80.0
	current_low_hp_song = null
	var main_songs: Array[AudioStreamPlayer] = [
		song_2,
		song_3,
		song_4
	]
	for song in main_songs:
		song.stop()
		song.volume_db = -80.0
	var available_main: Array[AudioStreamPlayer] = []
	for song in main_songs:
		if song != current_song:
			available_main.append(song)
	if available_main.is_empty():
		available_main = main_songs.duplicate()
	current_song = available_main.pick_random()
	current_song.volume_db = -80.0
	current_song.play()
	var fade_in := create_tween()
	fade_in.tween_property(
		current_song,
		"volume_db",
		get_song_volume(current_song),
		low_hp_fade_in_time
	)
func play_song(song_number: int):
	if low_hp_active:
		return
	var next_song: AudioStreamPlayer = null
	match song_number:
		2:
			next_song = song_2
		3:
			next_song = song_3
		4:
			next_song = song_4
		_:
			return
	if next_song == current_song:
		return
	crossfade_to(next_song)
func crossfade_to(next_song: AudioStreamPlayer):
	if low_hp_active:
		return
	if fading:
		return
	fading = true
	if music_tween != null:
		music_tween.kill()
	next_song.volume_db = -80.0
	next_song.play()
	var next_volume := get_song_volume(next_song)
	music_tween = create_tween()
	music_tween.set_parallel(true)
	if current_song != null:
		music_tween.tween_property(
			current_song,
			"volume_db",
			-80.0,
			fade_time
		)
	music_tween.tween_property(
		next_song,
		"volume_db",
		next_volume,
		fade_time
	)
	await music_tween.finished
	if current_song != null:
		current_song.stop()
		current_song.volume_db = -80.0
	current_song = next_song
	fading = false
func _on_main_song_finished():
	if low_hp_active:
		return
	if current_song == null:
		return
	current_song.volume_db = get_song_volume(current_song)
	current_song.play()
