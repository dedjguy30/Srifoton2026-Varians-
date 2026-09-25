extends Control


const GUIDE_FOLDER: String = "res://guide/"


@onready var vbox: VBoxContainer = (
	$CenterContainer/VBoxContainer
)

@onready var progress_label: Label = (
	$CenterContainer/VBoxContainer/ProgressLabel
)

@onready var level_buttons: VBoxContainer = (
	$CenterContainer/VBoxContainer/LevelButtons
)

@onready var reset_button: Button = (
	$CenterContainer/VBoxContainer/ResetProgress
)


var free_play_button: Button
var guide_button: Button


# ==================================================
# GUIDE DATA
# ==================================================

var guide_overlay: Control
var guide_texture: TextureRect
var guide_counter: Label
var guide_next_button: Button

var guide_slides: Array[String] = []
var guide_index: int = 0


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	_create_free_play_button()
	_create_guide_button()

	reset_button.pressed.connect(
		_on_reset_progress_pressed
	)

	LevelFlow.progress_changed.connect(
		_rebuild_level_buttons
	)

	_rebuild_level_buttons()


# ==================================================
# UNLOCK ALL LEVELS BUTTON
# ==================================================

func _create_free_play_button() -> void:
	free_play_button = Button.new()

	free_play_button.name = "FreePlayButton"

	free_play_button.custom_minimum_size = Vector2(
		220,
		48
	)

	free_play_button.pressed.connect(
		_on_free_play_pressed
	)

	vbox.add_child(
		free_play_button
	)

	vbox.move_child(
		free_play_button,
		reset_button.get_index()
	)


# ==================================================
# GUIDE BUTTON
# ==================================================

func _create_guide_button() -> void:
	guide_button = Button.new()

	guide_button.name = "GuideButton"
	guide_button.text = "GUIDE"

	guide_button.custom_minimum_size = Vector2(
		140,
		44
	)

	guide_button.set_anchors_preset(
		Control.PRESET_TOP_RIGHT
	)

	guide_button.offset_left = -156
	guide_button.offset_top = 16
	guide_button.offset_right = -16
	guide_button.offset_bottom = 60

	guide_button.pressed.connect(
		_on_guide_pressed
	)

	add_child(
		guide_button
	)


# ==================================================
# LEVEL BUTTONS
# ==================================================

func _rebuild_level_buttons() -> void:
	for child in level_buttons.get_children():
		child.free()

	var level_count: int = (
		LevelFlow.get_level_count()
	)

	var unlocked_count: int = (
		LevelFlow.get_unlocked_level_count()
	)


	if LevelFlow.free_play_enabled:
		progress_label.text = (
			"ALL LEVELS UNLOCKED"
		)

		free_play_button.text = (
			"UNLOCK ALL LEVELS: ON"
		)

	else:
		progress_label.text = (
			"Unlocked: %d / %d"
			% [
				unlocked_count,
				level_count
			]
		)

		free_play_button.text = (
			"UNLOCK ALL LEVELS: OFF"
		)


	for index in range(level_count):
		var button := Button.new()

		button.custom_minimum_size = Vector2(
			220,
			48
		)

		var unlocked: bool = (
			LevelFlow.is_level_unlocked(
				index
			)
		)

		if unlocked:
			button.text = (
				"LEVEL %02d"
				% [
					index + 1
				]
			)

			button.disabled = false

		else:
			button.text = (
				"LEVEL %02d - LOCKED"
				% [
					index + 1
				]
			)

			button.disabled = true


		button.pressed.connect(
			_on_level_pressed.bind(
				index
			)
		)

		level_buttons.add_child(
			button
		)


# ==================================================
# LEVEL
# ==================================================

func _on_level_pressed(
	index: int
) -> void:
	LevelFlow.load_level(
		index
	)


# ==================================================
# UNLOCK ALL LEVELS
# ==================================================

func _on_free_play_pressed() -> void:
	LevelFlow.toggle_free_play()


# ==================================================
# RESET
# ==================================================

func _on_reset_progress_pressed() -> void:
	LevelFlow.reset_progress()


# ==================================================
# GUIDE
# ==================================================

func _on_guide_pressed() -> void:
	guide_slides = _find_guide_slides()

	if guide_slides.is_empty():
		print(
			"GUIDE | Belum ada slide."
		)

		return

	guide_index = 0

	_create_guide_overlay()

	_show_guide_slide()


# ==================================================
# FIND GUIDE IMAGES
# ==================================================

func _find_guide_slides() -> Array[String]:
	var result: Array[String] = []

	var directory := DirAccess.open(
		GUIDE_FOLDER
	)

	if directory == null:
		push_warning(
			"Folder guide belum ada: "
			+ GUIDE_FOLDER
		)

		return result


	directory.list_dir_begin()

	var file_name: String = (
		directory.get_next()
	)

	while file_name != "":
		if not directory.current_is_dir():

			var clean_name: String = (
				file_name
			)

			# Support exported game.
			if clean_name.ends_with(
				".remap"
			):
				clean_name = (
					clean_name.trim_suffix(
						".remap"
					)
				)

			var lower_name := (
				clean_name.to_lower()
			)

			var is_image: bool = (
				lower_name.ends_with(".png")
				or lower_name.ends_with(".jpg")
				or lower_name.ends_with(".jpeg")
				or lower_name.ends_with(".webp")
			)

			if is_image:
				var full_path := (
					GUIDE_FOLDER
					+ clean_name
				)

				if not full_path in result:
					result.append(
						full_path
					)

		file_name = (
			directory.get_next()
		)

	directory.list_dir_end()

	result.sort()

	return result


# ==================================================
# GUIDE UI
# ==================================================

func _create_guide_overlay() -> void:
	if guide_overlay != null:
		return


	guide_overlay = Control.new()

	guide_overlay.name = "GuideOverlay"

	guide_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	guide_overlay.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	add_child(
		guide_overlay
	)


	# ==================================================
	# DARK BACKGROUND
	# ==================================================

	var background := ColorRect.new()

	background.color = Color(
		0.0,
		0.0,
		0.0,
		0.85
	)

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	guide_overlay.add_child(
		background
	)


	# ==================================================
	# PANEL
	# ==================================================

	var panel := PanelContainer.new()

	panel.anchor_left = 0.08
	panel.anchor_top = 0.06
	panel.anchor_right = 0.92
	panel.anchor_bottom = 0.94

	guide_overlay.add_child(
		panel
	)


	var guide_vbox := VBoxContainer.new()

	guide_vbox.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	guide_vbox.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	guide_vbox.add_theme_constant_override(
		"separation",
		12
	)

	panel.add_child(
		guide_vbox
	)


	# ==================================================
	# TITLE
	# ==================================================

	var title := Label.new()

	title.text = "GUIDE"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	guide_vbox.add_child(
		title
	)


	# ==================================================
	# IMAGE
	# ==================================================

	guide_texture = TextureRect.new()

	guide_texture.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)

	guide_texture.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)

	guide_texture.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	guide_texture.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	guide_texture.custom_minimum_size = Vector2(
		640,
		360
	)

	guide_vbox.add_child(
		guide_texture
	)


	# ==================================================
	# COUNTER
	# ==================================================

	guide_counter = Label.new()

	guide_counter.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	guide_vbox.add_child(
		guide_counter
	)


	# ==================================================
	# BUTTONS
	# ==================================================

	var buttons := HBoxContainer.new()

	buttons.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	buttons.add_theme_constant_override(
		"separation",
		16
	)

	guide_vbox.add_child(
		buttons
	)


	var previous_button := Button.new()

	previous_button.text = "PREVIOUS"

	previous_button.custom_minimum_size = Vector2(
		150,
		48
	)

	previous_button.pressed.connect(
		_on_guide_previous
	)

	buttons.add_child(
		previous_button
	)


	guide_next_button = Button.new()

	guide_next_button.text = "NEXT"

	guide_next_button.custom_minimum_size = Vector2(
		150,
		48
	)

	guide_next_button.pressed.connect(
		_on_guide_next
	)

	buttons.add_child(
		guide_next_button
	)


	var close_button := Button.new()

	close_button.text = "CLOSE"

	close_button.custom_minimum_size = Vector2(
		150,
		48
	)

	close_button.pressed.connect(
		_close_guide
	)

	buttons.add_child(
		close_button
	)


# ==================================================
# SHOW GUIDE
# ==================================================

func _show_guide_slide() -> void:
	if guide_slides.is_empty():
		return

	guide_index = clamp(
		guide_index,
		0,
		guide_slides.size() - 1
	)

	var texture := load(
		guide_slides[
			guide_index
		]
	)

	if texture is Texture2D:
		guide_texture.texture = (
			texture as Texture2D
		)


	guide_counter.text = (
		"%d / %d"
		% [
			guide_index + 1,
			guide_slides.size()
		]
	)


	if (
		guide_index
		>= guide_slides.size() - 1
	):
		guide_next_button.disabled = true

	else:
		guide_next_button.disabled = false


# ==================================================
# GUIDE NEXT
# ==================================================

func _on_guide_next() -> void:
	if (
		guide_index
		>= guide_slides.size() - 1
	):
		return

	guide_index += 1

	_show_guide_slide()


# ==================================================
# GUIDE PREVIOUS
# ==================================================

func _on_guide_previous() -> void:
	if guide_index <= 0:
		return

	guide_index -= 1

	_show_guide_slide()


# ==================================================
# CLOSE GUIDE
# ==================================================

func _close_guide() -> void:
	if guide_overlay != null:
		guide_overlay.queue_free()

	guide_overlay = null
	guide_texture = null
	guide_counter = null
	guide_next_button = null
