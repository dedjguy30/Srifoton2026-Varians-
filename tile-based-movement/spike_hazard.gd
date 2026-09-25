class_name SpikeHazard
extends BaseHazard


func _ready() -> void:
	super()

	if board == null:
		return

	if not board.object_moved.is_connected(
		_on_board_object_moved
	):
		board.object_moved.connect(
			_on_board_object_moved
		)


# ==================================================
# OBJECT MOVEMENT
# ==================================================

func _on_board_object_moved(
	object: Node2D,
	_from_cell: Vector2i,
	to_cell: Vector2i
) -> void:
	if not is_active:
		return

	if to_cell != grid_position:
		return

	# Character dan Enemy masuk group ini.
	# Box tidak.
	if not object.is_in_group(
		"hazard_vulnerable"
	):
		return


	# ==================================================
	# SYNC GRID POSITION
	# ==================================================

	# Board emit object_moved sebelum script actor
	# selesai mengubah grid_position.
	#
	# Jadi kita sinkronkan dulu supaya defeat()
	# mencatat cell kematian yang benar.

	if object is GridCharacter:
		var character := (
			object as GridCharacter
		)

		character.grid_position = (
			to_cell
		)

	elif object is GridEnemy:
		var enemy := (
			object as GridEnemy
		)

		enemy.grid_position = (
			to_cell
		)


	print(
		"SPIKE HIT | ",
		object.name
	)

	trigger_object(
		object
	)


# ==================================================
# SPIKE ACTIVATED UNDER ACTOR
# ==================================================

func _on_hazard_state_changed(
	active: bool
) -> void:
	if not active:
		return

	if board == null:
		return

	var occupant = board.get_object_at(
		grid_position
	)

	if occupant == null:
		return

	if not occupant.is_in_group(
		"hazard_vulnerable"
	):
		return

	print(
		"SPIKE ACTIVATED UNDER | ",
		occupant.name
	)

	trigger_object(
		occupant
	)
