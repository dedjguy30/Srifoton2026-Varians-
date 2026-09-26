extends Node


# BGM

const MENU_BGM_PATH: String = (
	"res://audio/bgm/puzzleSelect.ogg"
)

const STAGE_BGM_PATH: String = (
	"res://audio/bgm/leveBG.ogg"
)


# SFX

const CLICK_SFX_PATH: String = (
	"res://audio/sfx/click.wav"
)

const DEATH_SFX_PATH: String = (
	"res://audio/sfx/death.wav"
)

const DOOR_SFX_PATH: String = (
	"res://audio/sfx/door.wav"
)

const MOVE_SFX_PATH: String = (
	"res://audio/sfx/move.wav"
)

const NECTAR_SFX_PATH: String = (
	"res://audio/sfx/nectar.wav"
)

const PUSH_SFX_PATH: String = (
	"res://audio/sfx/push.wav"
)

const WIN_SFX_PATH: String = (
	"res://audio/sfx/win.wav"
)


# Runtime

var bgm_player: AudioStreamPlayer
var current_bgm_path: String = ""


# Setup

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	bgm_player = AudioStreamPlayer.new()

	bgm_player.name = "BGMPlayer"
	bgm_player.bus = "BGM"

	add_child(
		bgm_player
	)
	get_tree().node_added.connect(
		_on_node_added
	)

	call_deferred(
		"_connect_existing_buttons"
	)

func _on_node_added(
	node: Node
) -> void:
	if node is BaseButton:
		_connect_button(
			node as BaseButton
		)


func _connect_existing_buttons() -> void:
	var buttons := get_tree().root.find_children(
		"*",
		"BaseButton",
		true,
		false
	)

	for node in buttons:
		if node is BaseButton:
			_connect_button(
				node as BaseButton
			)


func _connect_button(
	button: BaseButton
) -> void:
	var click_callable := Callable(
		self,
		"play_click"
	)

	if button.pressed.is_connected(
		click_callable
	):
		return

	button.pressed.connect(
		click_callable
	)

# Load audio

func load_audio(
	path: String
) -> AudioStream:
	if not ResourceLoader.exists(
		path
	):
		push_warning(
			"Audio tidak ditemukan: "
			+ path
		)

		return null

	var stream := (
		load(path)
		as AudioStream
	)

	if stream == null:
		push_warning(
			"Audio gagal dibaca: "
			+ path
		)

	return stream


# Loop BGM

func enable_loop(
	stream: AudioStream
) -> void:
	if stream is AudioStreamOggVorbis:
		var ogg_stream := (
			stream
			as AudioStreamOggVorbis
		)

		ogg_stream.loop = true

	elif stream is AudioStreamWAV:
		var wav_stream := (
			stream
			as AudioStreamWAV
		)

		wav_stream.loop_mode = (
			AudioStreamWAV.LOOP_FORWARD
		)


# Play BGM

func play_bgm(
	path: String,
	volume_db: float = -8.0
) -> void:
	if (
		current_bgm_path == path
		and bgm_player.playing
	):
		return

	var stream := (
		load_audio(
			path
		)
	)

	if stream == null:
		return

	enable_loop(
		stream
	)

	bgm_player.stop()

	bgm_player.stream = stream
	bgm_player.volume_db = volume_db

	current_bgm_path = path

	bgm_player.play()


func stop_bgm() -> void:
	bgm_player.stop()

	current_bgm_path = ""


# BGM menu / puzzle select

func play_menu_bgm() -> void:
	play_bgm(
		MENU_BGM_PATH,
		-8.0
	)


# BGM semua level

func play_stage_bgm() -> void:
	play_bgm(
		STAGE_BGM_PATH,
		-8.0
	)


# Play SFX

func play_sfx(
	path: String,
	volume_db: float = 0.0
) -> void:
	var stream := (
		load_audio(
			path
		)
	)

	if stream == null:
		return

	var player := (
		AudioStreamPlayer.new()
	)

	player.stream = stream
	player.volume_db = volume_db
	player.bus = "SFX"

	add_child(
		player
	)

	player.finished.connect(
		player.queue_free
	)

	player.play()


# UI click

func play_click() -> void:
	play_sfx(
		CLICK_SFX_PATH,
		-4.0
	)


# Character death

func play_death() -> void:
	play_sfx(
		DEATH_SFX_PATH,
		-2.0
	)


# Door

func play_door() -> void:
	play_sfx(
		DOOR_SFX_PATH,
		-2.0
	)


# Character movement

func play_move() -> void:
	play_sfx(
		MOVE_SFX_PATH,
		-6.0
	)


# Nectar collect

func play_nectar() -> void:
	play_sfx(
		NECTAR_SFX_PATH,
		-2.0
	)


# Push box

func play_push() -> void:
	play_sfx(
		PUSH_SFX_PATH,
		-3.0
	)
func play_push_then_move() -> void:
	var stream := load_audio(
		PUSH_SFX_PATH
	)

	if stream == null:
		play_move()
		return

	var player := AudioStreamPlayer.new()

	player.stream = stream
	player.volume_db = -3.0
	player.bus = "SFX"

	add_child(
		player
	)

	player.finished.connect(
		func() -> void:
			player.queue_free()
			play_move()
	)

	player.play()


# Level complete

func play_win() -> void:
	play_sfx(
		WIN_SFX_PATH,
		0.0
	)
