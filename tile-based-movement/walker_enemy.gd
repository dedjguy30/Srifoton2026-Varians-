class_name WalkerEnemy
extends GridEnemy


# ==================================================
# WALKER MOVEMENT OPTIONS
# ==================================================

enum MoveDirection {
	ATAS,
	BAWAH,
	KIRI,
	KANAN,
	DIAM
}


# ==================================================
# WALKER SETTINGS
# ==================================================

@export var movement_pattern: Array[MoveDirection] = [
	MoveDirection.KIRI,
	MoveDirection.KIRI,
	MoveDirection.KANAN,
	MoveDirection.ATAS,
	MoveDirection.ATAS,
	MoveDirection.BAWAH
]


# ==================================================
# RUNTIME DATA
# ==================================================

var pattern_index: int = 0


# ==================================================
# WALKER TURN
# ==================================================

func take_turn() -> void:
	if board == null:
		return

	if movement_pattern.is_empty():
		return

	if pattern_index >= movement_pattern.size():
		pattern_index = 0

	var previous_index: int = (
		pattern_index
	)

	var movement: MoveDirection = (
		movement_pattern[
			pattern_index
		]
	)

	pattern_index += 1

	if pattern_index >= movement_pattern.size():
		pattern_index = 0


	board.append_action_to_current_turn({
		"type": "custom",

		"undo_callable": Callable(
			self,
			"_undo_pattern_step"
		),

		"data": {
			"previous_index":
				previous_index
		}
	})


	var direction: Vector2i = (
		get_direction_vector(
			movement
		)
	)


	# ==================================================
	# DIAM
	# ==================================================

	if direction == Vector2i.ZERO:
		print(
			"WALKER DIAM | ",
			name
		)

		return


	# ==================================================
	# SAVE OLD VISUAL POSITION
	# ==================================================

	var old_visual_position: Vector2 = (
		sprite.global_position
	)


	# ==================================================
	# LOGICAL MOVE
	# ==================================================

	var moved: bool = (
		move_enemy(
			direction
		)
	)


	# ==================================================
	# VISUAL BOUNCE
	# ==================================================

	if moved:
		play_bounce_from(
			old_visual_position
		)

		print(
			"WALKER MOVE | ",
			name,
			" | ",
			get_direction_name(
				movement
			)
		)

	else:
		print(
			"WALKER BLOCKED | ",
			name,
			" | ",
			get_direction_name(
				movement
			)
		)


# ==================================================
# DIRECTION CONVERSION
# ==================================================

func get_direction_vector(
	movement: MoveDirection
) -> Vector2i:
	match movement:
		MoveDirection.ATAS:
			return Vector2i.UP

		MoveDirection.BAWAH:
			return Vector2i.DOWN

		MoveDirection.KIRI:
			return Vector2i.LEFT

		MoveDirection.KANAN:
			return Vector2i.RIGHT

		MoveDirection.DIAM:
			return Vector2i.ZERO

	return Vector2i.ZERO


func get_direction_name(
	movement: MoveDirection
) -> String:
	match movement:
		MoveDirection.ATAS:
			return "ATAS"

		MoveDirection.BAWAH:
			return "BAWAH"

		MoveDirection.KIRI:
			return "KIRI"

		MoveDirection.KANAN:
			return "KANAN"

		MoveDirection.DIAM:
			return "DIAM"

	return "UNKNOWN"


# ==================================================
# UNDO PATTERN
# ==================================================

func _undo_pattern_step(
	data: Dictionary
) -> void:
	pattern_index = data[
		"previous_index"
	]

	print(
		"UNDO WALKER PATTERN | ",
		name,
		" | Index: ",
		pattern_index
	)
