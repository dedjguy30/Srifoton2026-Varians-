extends Control


@onready var progress_label: Label = (
	$CenterContainer/VBoxContainer/ProgressLabel
)

@onready var level_buttons: VBoxContainer = (
	$CenterContainer/VBoxContainer/LevelButtons
)

@onready var reset_button: Button = (
	$CenterContainer/VBoxContainer/ResetProgress
)


func _ready() -> void:
	reset_button.pressed.connect(
		_on_reset_progress_pressed
	)

	LevelFlow.progress_changed.connect(
		_rebuild_level_buttons
	)

	_rebuild_level_buttons()


func _rebuild_level_buttons() -> void:
	for child in level_buttons.get_children():
		child.free()

	var level_count := (
		LevelFlow.get_level_count()
	)

	var unlocked_count := (
		LevelFlow.get_unlocked_level_count()
	)

	progress_label.text = (
		"Unlocked: %d / %d"
		% [
			unlocked_count,
			level_count
		]
	)

	for index in range(
		level_count
	):
		var button := Button.new()

		button.custom_minimum_size = Vector2(
			220,
			48
		)

		var unlocked := (
			LevelFlow.is_level_unlocked(
				index
			)
		)

		if unlocked:
			button.text = (
				"LEVEL %02d"
				% [index + 1]
			)

			button.disabled = false

		else:
			button.text = (
				"LEVEL %02d - LOCKED"
				% [index + 1]
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


func _on_level_pressed(
	index: int
) -> void:
	LevelFlow.load_level(
		index
	)


func _on_reset_progress_pressed() -> void:
	LevelFlow.reset_progress()
