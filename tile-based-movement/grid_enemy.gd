class_name GridEnemy
extends Node2D


# ==================================================
# SETTINGS
# ==================================================

@export var board: Board


# ==================================================
# RUNTIME DATA
# ==================================================

var grid_position: Vector2i = Vector2i.ZERO
var is_alive: bool = true


# Kalau Player sengaja berjalan ke Enemy,
# Enemy tersebut dianggap sudah melakukan action.
#
# Jadi ketika enemy turn dimulai pada commit,
# Enemy ini tidak bergerak untuk kedua kalinya.
var skip_next_turn: bool = false


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("pressure_plate_activator")
	add_to_group("hazard_vulnerable")

	if board == null:
		push_error(
			name + " belum terhubung ke Board!"
		)
		return

	grid_position = board.world_to_grid(
		global_position
	)

	global_position = board.grid_to_world(
		grid_position
	)

	if not board.register_object(
		grid_position,
		self
	):
		return

	if not board.turn_about_to_commit.is_connected(
		_on_turn_about_to_commit
	):
		board.turn_about_to_commit.connect(
			_on_turn_about_to_commit
		)


# ==================================================
# TURN
# ==================================================

func _on_turn_about_to_commit() -> void:
	if not is_alive:
		return


	# ==================================================
	# ALREADY ATE PLAYER THIS TURN
	# ==================================================

	# Contoh:
	#
	# P E
	#
	# Player maju ke E.
	# Enemy langsung makan Player.
	#
	# Enemy tersebut tidak boleh bergerak
	# sekali lagi di enemy phase yang sama.
	if skip_next_turn:
		skip_next_turn = false

		print(
			"ENEMY TURN SKIPPED | ",
			name,
			" sudah makan Character turn ini."
		)

		return


	take_turn()


# Child Enemy override fungsi ini.
func take_turn() -> void:
	pass


# ==================================================
# NORMAL MOVEMENT
# ==================================================

func move_enemy(
	direction: Vector2i
) -> bool:
	if board == null:
		return false

	if not is_alive:
		return false

	var target_cell: Vector2i = (
		grid_position + direction
	)

	if board.is_occupied(
		target_cell
	):
		return false

	var success: bool = board.move_object(
		grid_position,
		target_cell,
		self
	)

	if not success:
		return false

	grid_position = target_cell

	global_position = board.grid_to_world(
		grid_position
	)

	return true


# ==================================================
# PLAYER WALKS INTO ENEMY
# ==================================================

# Dipanggil kalau Player SENDIRI memilih
# bergerak ke cell Enemy.
#
# Enemy tetap diam.
# Character langsung mati.
#
# Action tersebut tetap dianggap valid turn.
func eat_character_from_player_move(
	character: GridCharacter
) -> bool:
	if board == null:
		return false

	if not is_alive:
		return false

	if character == null:
		return false

	if not character.is_alive:
		return false

	if character.board != board:
		return false


	# ==================================================
	# KILL CHARACTER
	# ==================================================

	var defeated: bool = (
		character.defeat()
	)

	if not defeated:
		return false


	# ==================================================
	# ENEMY COUNTS AS ALREADY ACTED
	# ==================================================

	# Ketika Board.commit_turn() nanti
	# memanggil semua Enemy,
	# Enemy ini tidak bertindak lagi.
	skip_next_turn = true

	print(
		"ENEMY ATE CHARACTER | ",
		name,
		" memakan ",
		character.name
	)

	return true


# ==================================================
# ENEMY MOVES INTO CHARACTER
# ==================================================

# Ini kebalikan dari fungsi di atas.
#
# Dipakai saat ENEMY yang mendekati Character.
#
# Contoh Chaser:
#
# E → P
#
# Character mati,
# lalu Enemy masuk ke cell bekas Character.
func move_or_attack_character(
	direction: Vector2i
) -> bool:
	if board == null:
		return false

	if not is_alive:
		return false

	if direction == Vector2i.ZERO:
		return false

	var target_cell: Vector2i = (
		grid_position + direction
	)

	var target_object = board.get_object_at(
		target_cell
	)


	# ==================================================
	# EMPTY CELL
	# ==================================================

	if target_object == null:
		return move_enemy(
			direction
		)


	# ==================================================
	# CHARACTER
	# ==================================================

	if target_object is GridCharacter:
		var character := (
			target_object as GridCharacter
		)

		if not character.is_alive:
			return false

		var defeated: bool = (
			character.defeat()
		)

		if not defeated:
			return false

		# Character sudah unregister dari Board.
		# Enemy sekarang masuk ke cell bekas Character.
		return move_enemy(
			direction
		)


	# ==================================================
	# OTHER BLOCKER
	# ==================================================

	# Wall
	# Box
	# Door
	# Enemy lain
	# dll.
	return false


# ==================================================
# ENEMY DEATH
# ==================================================

func defeat() -> bool:
	if not is_alive:
		return false

	if board == null:
		return false

	var death_cell: Vector2i = (
		grid_position
	)

	var previous_visible: bool = (
		visible
	)


	# ==================================================
	# SAVE UNDO
	# ==================================================

	var recorded: bool = (
		board.append_action_to_current_turn({
			"type": "custom",

			"undo_callable": Callable(
				self,
				"_undo_defeat"
			),

			"data": {
				"death_cell":
					death_cell,

				"previous_visible":
					previous_visible
			}
		})
	)

	if not recorded:
		push_warning(
			"Enemy defeat terjadi di luar turn aktif."
		)
		return false


	# ==================================================
	# REMOVE FROM BOARD
	# ==================================================

	if board.get_object_at(
		death_cell
	) == self:
		board.unregister_object(
			death_cell,
			self
		)


	# ==================================================
	# DEAD STATE
	# ==================================================

	is_alive = false
	visible = false

	print(
		"ENEMY DEFEATED | ",
		name,
		" | Cell: ",
		death_cell
	)

	return true


# ==================================================
# UNDO ENEMY DEATH
# ==================================================

func _undo_defeat(
	data: Dictionary
) -> void:
	var death_cell: Vector2i = (
		data["death_cell"]
	)

	if board.is_occupied(
		death_cell
	):
		push_warning(
			"Undo Enemy gagal: "
			+ "cell kematian masih occupied."
		)

		return

	if not board.register_object(
		death_cell,
		self
	):
		return

	is_alive = true

	visible = data[
		"previous_visible"
	]

	grid_position = death_cell

	global_position = board.grid_to_world(
		grid_position
	)

	print(
		"UNDO ENEMY DEATH | ",
		name
	)


# ==================================================
# SNAP / UNDO MOVEMENT
# ==================================================

func snap_to_cell(
	cell: Vector2i
) -> void:
	grid_position = cell

	global_position = board.grid_to_world(
		grid_position
	)
