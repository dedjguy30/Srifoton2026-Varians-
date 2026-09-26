class_name ChaserEnemy
extends GridEnemy


# ==================================================
# CHASER SETTINGS
# ==================================================

@export_group("Chaser Settings")

@export_range(1, 20, 1)
var detection_radius: int = 5

@export_range(1, 5, 1)
var move_every_turns: int = 2


# ==================================================
# RUNTIME DATA
# ==================================================

var chase_turn_counter: int = 0


# ==================================================
# ENEMY TURN
# ==================================================

func take_turn() -> void:
	if board == null:
		return

	var target: GridCharacter = (
		find_nearest_character()
	)


	# ==================================================
	# NO TARGET
	# ==================================================

	if target == null:
		if chase_turn_counter != 0:
			save_counter_undo()

		chase_turn_counter = 0

		print(
			"CHASER IDLE | ",
			name
		)

		return


	# ==================================================
	# CHASE TIMER
	# ==================================================

	save_counter_undo()

	chase_turn_counter += 1

	if chase_turn_counter < move_every_turns:
		print(
			"CHASER WAIT | ",
			name,
			" | ",
			chase_turn_counter,
			"/",
			move_every_turns
		)

		return

	chase_turn_counter = 0


	# ==================================================
	# MOVEMENT
	# ==================================================

	var direction: Vector2i = (
		choose_move_direction(
			target
		)
	)

	if direction == Vector2i.ZERO:
		print(
			"CHASER BLOCKED | ",
			name
		)

		return


	# Posisi visual sebelum logical movement.
	var old_visual_position: Vector2 = (
		sprite.global_position
	)


	var moved: bool = (
		move_or_attack_character(
			direction
		)
	)


	if moved:
		# Logic sudah selesai.
		# Sekarang baru mainkan visual bounce.
		play_bounce_from(
			old_visual_position
		)

		print(
			"CHASER MOVE | ",
			name,
			" mengejar ",
			target.name
		)

	else:
		print(
			"CHASER BLOCKED | ",
			name
		)


# ==================================================
# TARGET SEARCH
# ==================================================

func find_nearest_character() -> GridCharacter:
	var nearest: GridCharacter = null
	var nearest_distance: int = 999999

	for node in get_tree().get_nodes_in_group(
		"characters"
	):
		if not node is GridCharacter:
			continue

		var character := (
			node as GridCharacter
		)

		if character.board != board:
			continue

		if board.get_object_at(
			character.grid_position
		) != character:
			continue

		var distance: int = (
			get_grid_distance(
				grid_position,
				character.grid_position
			)
		)

		if distance > detection_radius:
			continue

		if distance < nearest_distance:
			nearest = character
			nearest_distance = distance

	return nearest


# ==================================================
# GRID DISTANCE
# ==================================================

func get_grid_distance(
	from_cell: Vector2i,
	to_cell: Vector2i
) -> int:
	return (
		abs(
			to_cell.x - from_cell.x
		)
		+
		abs(
			to_cell.y - from_cell.y
		)
	)


# ==================================================
# MOVEMENT DECISION
# ==================================================

func choose_move_direction(
	target: GridCharacter
) -> Vector2i:
	var difference: Vector2i = (
		target.grid_position
		- grid_position
	)

	var horizontal: Vector2i = (
		Vector2i.ZERO
	)

	var vertical: Vector2i = (
		Vector2i.ZERO
	)


	if difference.x > 0:
		horizontal = Vector2i.RIGHT

	elif difference.x < 0:
		horizontal = Vector2i.LEFT


	if difference.y > 0:
		vertical = Vector2i.DOWN

	elif difference.y < 0:
		vertical = Vector2i.UP


	if abs(difference.x) >= abs(difference.y):
		if can_move_to_direction(
			horizontal
		):
			return horizontal

		if can_move_to_direction(
			vertical
		):
			return vertical

	else:
		if can_move_to_direction(
			vertical
		):
			return vertical

		if can_move_to_direction(
			horizontal
		):
			return horizontal

	return Vector2i.ZERO


# ==================================================
# MOVEMENT CHECK
# ==================================================

func can_move_to_direction(
	direction: Vector2i
) -> bool:
	if direction == Vector2i.ZERO:
		return false

	var target_cell: Vector2i = (
		grid_position + direction
	)

	var target_object = board.get_object_at(
		target_cell
	)

	if target_object == null:
		return true

	if target_object is GridCharacter:
		var character := (
			target_object
			as GridCharacter
		)

		return character.is_alive

	return false


# ==================================================
# CHASE COUNTER UNDO
# ==================================================

func save_counter_undo() -> void:
	board.append_action_to_current_turn({
		"type": "custom",

		"undo_callable": Callable(
			self,
			"_undo_chase_counter"
		),

		"data": {
			"previous_counter":
				chase_turn_counter
		}
	})


func _undo_chase_counter(
	data: Dictionary
) -> void:
	chase_turn_counter = data[
		"previous_counter"
	]
