extends Node


const LEVEL_FOLDER_PREFIX: String = "res://levels/"
const LEVEL_FILE_PREFIX: String = "level_"
const LEVEL_TEMPLATE_FILE: String = "level_template.tscn"

const TUTORIAL_ROOT_FOLDER: String = "res://tutorials/"


var _last_scene_id: int = 0

var _canvas_layer: CanvasLayer
var _tutorial_root: Control
var _slide_texture: TextureRect
var _slide_counter: Label
var _next_button: Button

var _slide_paths: Array[String] = []
var _slide_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	var scene_id: int = current_scene.get_instance_id()

	if scene_id == _last_scene_id:
		return

	_last_scene_id = scene_id

	call_deferred("_setup_current_scene")


# ==================================================
# SCENE DETECTION
# ==================================================

func _setup_current_scene() -> void:
	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	_reset_runtime_references()

	var scene_path: String = current_scene.scene_file_path

	if not _is_gameplay_level(scene_path):
		get_tree().paused = false
		return

	var level_name: String = (
		scene_path.get_file().get_basename()
	)

	_slide_paths = _find_tutorial_slides(
		level_name
	)

	_create_canvas_layer(
		current_scene
	)

	if not _slide_paths.is_empty():
		_create_tutorial()

	_create_quit_button()


func _is_gameplay_level(
	scene_path: String
) -> bool:
	if not scene_path.begins_with(
		LEVEL_FOLDER_PREFIX
	):
		return false

	var file_name: String = (
		scene_path.get_file()
	)

	if file_name == LEVEL_TEMPLATE_FILE:
		return false

	return (
		file_name.begins_with(
			LEVEL_FILE_PREFIX
		)
		and file_name.ends_with(".tscn")
	)


func _reset_runtime_references() -> void:
	_canvas_layer = null
	_tutorial_root = null
	_slide_texture = null
	_slide_counter = null
	_next_button = null

	_slide_paths.clear()
	_slide_index = 0


# ==================================================
# CANVAS
# ==================================================

func _create_canvas_layer(
	current_scene: Node
) -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "RuntimeLevelOverlay"
	_canvas_layer.layer = 100
	_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	current_scene.add_child(
		_canvas_layer
	)


# ==================================================
# QUIT LEVEL
# ==================================================

func _create_quit_button() -> void:
	if _canvas_layer == null:
		return

	var quit_button := Button.new()

	quit_button.name = "QuitLevelButton"
	quit_button.text = "QUIT LEVEL"

	quit_button.custom_minimum_size = Vector2(
		148.0,
		44.0
	)

	quit_button.process_mode = Node.PROCESS_MODE_ALWAYS

	quit_button.set_anchors_preset(
		Control.PRESET_TOP_RIGHT
	)

	quit_button.offset_left = -164.0
	quit_button.offset_top = 16.0
	quit_button.offset_right = -16.0
	quit_button.offset_bottom = 60.0

	quit_button.pressed.connect(
		_on_quit_level_pressed
	)

	_canvas_layer.add_child(
		quit_button
	)


func _on_quit_level_pressed() -> void:
	get_tree().paused = false

	LevelFlow.go_to_level_select()


# ==================================================
# TUTORIAL FILE DISCOVERY
# ==================================================

func _find_tutorial_slides(
	level_name: String
) -> Array[String]:
	var result: Array[String] = []

	var folder_path: String = (
		TUTORIAL_ROOT_FOLDER
		+ level_name
		+ "/"
	)

	var directory := DirAccess.open(
		folder_path
	)

	if directory == null:
		return result

	directory.list_dir_begin()

	var raw_file_name: String = (
		directory.get_next()
	)

	while raw_file_name != "":
		if not directory.current_is_dir():
			var file_name: String = raw_file_name

			if file_name.ends_with(
				".remap"
			):
				file_name = (
					file_name.trim_suffix(
						".remap"
					)
				)

			var lower_name: String = (
				file_name.to_lower()
			)

			var is_image: bool = (
				lower_name.ends_with(".png")
				or lower_name.ends_with(".jpg")
				or lower_name.ends_with(".jpeg")
				or lower_name.ends_with(".webp")
			)

			if is_image:
				var full_path: String = (
					folder_path
					+ file_name
				)

				if not full_path in result:
					result.append(
						full_path
					)

		raw_file_name = (
			directory.get_next()
		)

	directory.list_dir_end()

	result.sort()

	return result


# ==================================================
# TUTORIAL UI
# ==================================================

func _create_tutorial() -> void:
	if _canvas_layer == null:
		return

	if _slide_paths.is_empty():
		return

	_slide_index = 0

	_tutorial_root = Control.new()
	_tutorial_root.name = "TutorialOverlay"
	_tutorial_root.process_mode = Node.PROCESS_MODE_ALWAYS

	_tutorial_root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	_tutorial_root.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	_canvas_layer.add_child(
		_tutorial_root
	)


	# ------------------------------
	# DARK BACKGROUND
	# ------------------------------

	var background := ColorRect.new()

	background.color = Color(
		0.0,
		0.0,
		0.0,
		0.82
	)

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	_tutorial_root.add_child(
		background
	)


	# ------------------------------
	# PANEL
	# ------------------------------

	var panel := PanelContainer.new()

	panel.anchor_left = 0.08
	panel.anchor_top = 0.06
	panel.anchor_right = 0.92
	panel.anchor_bottom = 0.94

	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0

	_tutorial_root.add_child(
		panel
	)

	var vbox := VBoxContainer.new()

	vbox.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	vbox.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	vbox.add_theme_constant_override(
		"separation",
		12
	)

	panel.add_child(
		vbox
	)


	# ------------------------------
	# IMAGE
	# ------------------------------

	_slide_texture = TextureRect.new()

	_slide_texture.name = "SlideImage"

	_slide_texture.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)

	_slide_texture.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)

	_slide_texture.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	_slide_texture.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	_slide_texture.custom_minimum_size = Vector2(
		640.0,
		360.0
	)

	vbox.add_child(
		_slide_texture
	)


	# ------------------------------
	# COUNTER
	# ------------------------------

	_slide_counter = Label.new()

	_slide_counter.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	vbox.add_child(
		_slide_counter
	)


	# ------------------------------
	# BUTTONS
	# ------------------------------

	var buttons := HBoxContainer.new()

	buttons.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	buttons.add_theme_constant_override(
		"separation",
		16
	)

	vbox.add_child(
		buttons
	)

	var skip_button := Button.new()

	skip_button.text = "SKIP"

	skip_button.custom_minimum_size = Vector2(
		150.0,
		48.0
	)

	skip_button.pressed.connect(
		_close_tutorial
	)

	buttons.add_child(
		skip_button
	)

	_next_button = Button.new()

	_next_button.text = "NEXT"

	_next_button.custom_minimum_size = Vector2(
		150.0,
		48.0
	)

	_next_button.pressed.connect(
		_on_next_slide_pressed
	)

	buttons.add_child(
		_next_button
	)

	_show_current_slide()

	get_tree().paused = true


func _show_current_slide() -> void:
	if _slide_texture == null:
		return

	if _slide_paths.is_empty():
		_close_tutorial()
		return

	_slide_index = clamp(
		_slide_index,
		0,
		_slide_paths.size() - 1
	)

	var slide_path: String = (
		_slide_paths[_slide_index]
	)

	var resource := load(
		slide_path
	)

	if resource is Texture2D:
		_slide_texture.texture = (
			resource as Texture2D
		)
	else:
		push_warning(
			"Tutorial image gagal dimuat: "
			+ slide_path
		)

	if _slide_counter != null:
		_slide_counter.text = (
			"%d / %d"
			% [
				_slide_index + 1,
				_slide_paths.size()
			]
		)

	if _next_button != null:
		if (
			_slide_index
			>= _slide_paths.size() - 1
		):
			_next_button.text = "START"
		else:
			_next_button.text = "NEXT"


func _on_next_slide_pressed() -> void:
	if (
		_slide_index
		>= _slide_paths.size() - 1
	):
		_close_tutorial()
		return

	_slide_index += 1

	_show_current_slide()


func _close_tutorial() -> void:
	get_tree().paused = false

	if (
		_tutorial_root != null
		and is_instance_valid(
			_tutorial_root
		)
	):
		_tutorial_root.queue_free()

	_tutorial_root = null
	_slide_texture = null
	_slide_counter = null
	_next_button = null
