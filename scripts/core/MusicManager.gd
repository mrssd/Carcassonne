extends Node

const MAIN_MENU_MUSIC_PATH := "res://assets/sounds/MainMenuMusic.mp3"
const GAMEPLAY_MUSIC_PATH := "res://assets/sounds/GameplayMusic.mp3"

@onready var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()

var _menu_music: AudioStream
var _gameplay_music: AudioStream
var _current_track: String = ""

func _ready() -> void:
    add_child(audio_player)
    audio_player.volume_db = -16
    _menu_music = _load_looping_mp3(MAIN_MENU_MUSIC_PATH)
    _gameplay_music = _load_looping_mp3(GAMEPLAY_MUSIC_PATH)
    play_menu_music()

func play_menu_music() -> void:
    _play_track(_menu_music, "menu")

func play_gameplay_music() -> void:
    _play_track(_gameplay_music, "gameplay")

func stop_music() -> void:
    if audio_player.playing:
        audio_player.stop()
    _current_track = ""

func _play_track(track: AudioStream, track_name: String) -> void:
    if track == null:
        return
    if _current_track == track_name and audio_player.playing:
        return
    audio_player.stream = track
    audio_player.play()
    _current_track = track_name

func _load_looping_mp3(path: String) -> AudioStream:
    var stream := load(path) as AudioStreamMP3
    if stream:
        stream.loop = true
    return stream