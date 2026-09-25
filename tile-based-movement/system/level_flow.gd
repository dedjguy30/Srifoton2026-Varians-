extends Node


signal progress_changed


const LEVEL_FOLDER: String = "res://levels/"
const LEVEL_PREFIX: String = "level_"

const LEVEL_SELECT_SCENE: String = (
	"res://menus/level_select.tscn"
)

const SAVE_PATH: String = (
	"user://level_progress.cfg"
)


var levels: Array[String] = []

var highest_unlocked_level: int = 0

var current_level_index: int = 0


# ==================================================
# FREE PLAY
# ==================================================

# Tidak disimpan ke save.
# Jadi saat game ditutup, kembali ke Normal Mode.
var free_play_enabled: bool = false


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	refresh_level_list()

	load_progress()


# ==================================================
# LEVEL DISCOVERY
# ==================================================

func refresh_level_list() -> void:
	levels.clear()

	var files := DirAccess.get_files_at(
		LEVEL_FOLDER
	)

	for raw_file_name in files:
		var file_name: String = (
			raw_file_name
		)

		# Untuk exported game.
		if file_name.ends_with(
			".remap"
		):
			file_name = (
				file_name.trim_suffix(
					".remap"
				)
			)

		if not file_name.begins_with(
			LEVEL_PREFIX
		):
			continue

		if not file_name.ends_with(
			".tscn"
		):
			continue

		if file_name == (
			"level_template.tscn"
		):
			continue

		var full_path: String = (
			LEVEL_FOLDER
			+ file_name
		)

		if full_path in levels:
			continue

		levels.append(
			full_path
		)

	levels.sort()

	print(
		"LEVELS FOUND: ",
		levels.size()
	)

	for i in range(
		levels.size()
	):
		print(
			"LEVEL ",
			i + 1,
			" = ",
			levels[i]
		)


# ==================================================
# CURRENT LEVEL
# ==================================================

func get_current_level_index() -> int:
	if levels.is_empty():
		refresh_level_list()

	var current_scene := (
		get_tree().current_scene
	)

	if current_scene == null:
		return current_level_index

	var current_path: String = (
		current_scene.scene_file_path
	)

	var found_index: int = (
		levels.find(
			current_path
		)
	)

	if found_index != -1:
		current_level_index = (
			found_index
		)

	return current_level_index


# ==================================================
# LOAD LEVEL
# ==================================================

func load_level(
	index: int,
	ignore_lock: bool = false
) -> void:

	if levels.is_empty():
		refresh_level_list()

	if index < 0:
		return

	if index >= levels.size():
		return

	# Free Play otomatis boleh membuka semuanya.
	var can_open: bool = (
		ignore_lock
		or free_play_enabled
		or index <= highest_unlocked_level
	)

	if not can_open:
		print(
			"LEVEL LOCKED: ",
			index + 1
		)

		return

	current_level_index = index

	print(
		"LOAD LEVEL ",
		index + 1
	)

	get_tree().change_scene_to_file(
		levels[index]
	)


# ==================================================
# LEVEL COMPLETE
# ==================================================

func complete_current_level() -> void:
	if levels.is_empty():
		refresh_level_list()

	if levels.is_empty():
		return

	# ==================================================
	# FREE PLAY
	# ==================================================
	#
	# Menyelesaikan level dalam Free Play
	# TIDAK mengubah save progress normal.
	#
	if free_play_enabled:
		print(
			"FREE PLAY | Progress tidak diubah."
		)

		return


	var index: int = (
		get_current_level_index()
	)

	var next_index: int = (
		index + 1
	)

	if next_index < levels.size():
		if (
			next_index
			> highest_unlocked_level
		):
			highest_unlocked_level = (
				next_index
			)

			save_progress()

			print(
				"LEVEL UNLOCKED: ",
				next_index + 1
			)

			progress_changed.emit()


# ==================================================
# NEXT LEVEL
# ==================================================

func go_to_next_level() -> void:
	if levels.is_empty():
		refresh_level_list()

	if levels.is_empty():
		return

	var index: int = (
		get_current_level_index()
	)

	complete_current_level()

	var next_index: int = (
		index + 1
	)

	if next_index >= levels.size():
		print(
			"SEMUA LEVEL SELESAI!"
		)

		go_to_level_select()

		return

	# Setelah menyelesaikan level,
	# next level selalu boleh dimuat.
	load_level(
		next_index,
		true
	)


# ==================================================
# RESTART
# ==================================================

func restart_current_level() -> void:
	var index: int = (
		get_current_level_index()
	)

	load_level(
		index,
		true
	)


# ==================================================
# LEVEL SELECT
# ==================================================

func go_to_level_select() -> void:
	get_tree().paused = false

	get_tree().change_scene_to_file(
		LEVEL_SELECT_SCENE
	)


# ==================================================
# SAVE
# ==================================================

func save_progress() -> void:
	var config := ConfigFile.new()

	config.set_value(
		"progress",
		"highest_unlocked_level",
		highest_unlocked_level
	)

	var error := config.save(
		SAVE_PATH
	)

	if error != OK:
		push_warning(
			"Gagal save progress: "
			+ str(error)
		)


# ==================================================
# LOAD SAVE
# ==================================================

func load_progress() -> void:
	var config := ConfigFile.new()

	var error := config.load(
		SAVE_PATH
	)

	if error != OK:
		highest_unlocked_level = 0
		return

	highest_unlocked_level = int(
		config.get_value(
			"progress",
			"highest_unlocked_level",
			0
		)
	)

	if not levels.is_empty():
		highest_unlocked_level = clamp(
			highest_unlocked_level,
			0,
			levels.size() - 1
		)


# ==================================================
# RESET SAVE
# ==================================================

func reset_progress() -> void:
	highest_unlocked_level = 0

	save_progress()

	progress_changed.emit()

	print(
		"PROGRESS RESET"
	)


# ==================================================
# FREE PLAY CONTROL
# ==================================================

func set_free_play(
	enabled: bool
) -> void:
	free_play_enabled = enabled

	print(
		"FREE PLAY: ",
		free_play_enabled
	)

	progress_changed.emit()


func toggle_free_play() -> void:
	set_free_play(
		not free_play_enabled
	)


# ==================================================
# LEVEL STATUS
# ==================================================

func is_level_unlocked(
	index: int
) -> bool:

	if index < 0:
		return false

	if index >= levels.size():
		return false

	# Semua terbuka ketika Free Play.
	if free_play_enabled:
		return true

	return (
		index
		<= highest_unlocked_level
	)


func get_level_count() -> int:
	if levels.is_empty():
		refresh_level_list()

	return levels.size()


func get_unlocked_level_count() -> int:
	if levels.is_empty():
		return 0

	if free_play_enabled:
		return levels.size()

	return min(
		highest_unlocked_level + 1,
		levels.size()
	)
