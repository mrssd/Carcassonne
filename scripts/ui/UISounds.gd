extends Node

const HOVER_SFX_PATH := "res://assets/sounds/ButtonHover.mp3"
const PRESS_SFX_PATH := "res://assets/sounds/ButtonPress.mp3"
const TILE_ROTATE_SFX_PATH := "res://assets/sounds/TileRotate.mp3"
const SUCCESSFUL_PLACEMENT_SFX_PATH := "res://assets/sounds/SuccessfulPlacement.mp3"
const INVALID_PLACEMENT_SFX_PATH := "res://assets/sounds/InvalidPlacement.mp3"
const GAME_OVER_SFX_PATH := "res://assets/sounds/GameOver.mp3"
const HOVER_DELAY_SEC := 0.2
const SFX_VOLUME_DB := -16.0

@onready var _hover_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _press_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _rotate_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _successful_placement_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _invalid_placement_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _game_over_player: AudioStreamPlayer = AudioStreamPlayer.new()

var _hover_stream: AudioStream
var _press_stream: AudioStream
var _rotate_stream: AudioStream
var _successful_placement_stream: AudioStream
var _invalid_placement_stream: AudioStream
var _game_over_stream: AudioStream
var _hover_request_id: int = 0

func _ready() -> void:
	_hover_stream = load(HOVER_SFX_PATH)
	_press_stream = load(PRESS_SFX_PATH)
	_rotate_stream = load(TILE_ROTATE_SFX_PATH)
	_successful_placement_stream = load(SUCCESSFUL_PLACEMENT_SFX_PATH)
	_invalid_placement_stream = load(INVALID_PLACEMENT_SFX_PATH)
	_game_over_stream = load(GAME_OVER_SFX_PATH)

	add_child(_hover_player)
	add_child(_press_player)
	add_child(_rotate_player)
	add_child(_successful_placement_player)
	add_child(_invalid_placement_player)
	add_child(_game_over_player)
	_hover_player.volume_db = SFX_VOLUME_DB
	_press_player.volume_db = SFX_VOLUME_DB
	_rotate_player.volume_db = SFX_VOLUME_DB
	_successful_placement_player.volume_db = SFX_VOLUME_DB
	_invalid_placement_player.volume_db = SFX_VOLUME_DB
	_game_over_player.volume_db = SFX_VOLUME_DB
	_hover_player.stream = _hover_stream
	_press_player.stream = _press_stream
	_rotate_player.stream = _rotate_stream
	_successful_placement_player.stream = _successful_placement_stream
	_invalid_placement_player.stream = _invalid_placement_stream
	_game_over_player.stream = _game_over_stream

	get_tree().node_added.connect(_on_node_added)
	_connect_buttons_in_subtree(get_tree().root)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_setup_button(node)
		return
	_connect_buttons_in_subtree(node)

func _connect_buttons_in_subtree(root: Node) -> void:
	if root is BaseButton:
		_setup_button(root)
	for child in root.get_children():
		if child is Node:
			_connect_buttons_in_subtree(child)

func _setup_button(button: BaseButton) -> void:
	if button.has_meta("ui_sfx_bound"):
		return
	button.set_meta("ui_sfx_bound", true)

	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)

	if not button.mouse_entered.is_connected(_on_button_hovered):
		button.mouse_entered.connect(_on_button_hovered)

func _on_button_hovered() -> void:
	_hover_request_id += 1
	var request_id := _hover_request_id
	await get_tree().create_timer(HOVER_DELAY_SEC).timeout
	if request_id != _hover_request_id:
		return
	if _hover_stream:
		_hover_player.play()

func _on_button_pressed() -> void:
	_hover_request_id += 1
	if _press_stream:
		_press_player.play()

func play_rotate_sound() -> void:
	if _rotate_stream:
		_rotate_player.play()

func play_successful_placement_sound() -> void:
	if _successful_placement_stream:
		_successful_placement_player.play()

func play_invalid_placement_sound() -> void:
	if _invalid_placement_stream:
		_invalid_placement_player.play()

func play_game_over_sound() -> void:
	if _game_over_stream:
		_game_over_player.play()
