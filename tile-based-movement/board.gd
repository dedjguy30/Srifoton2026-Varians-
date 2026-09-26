class_name Board
extends Node2D


# Dikirim SETELAH object selesai berpindah cell.
signal object_moved(
	object: Node2D,
	from_cell: Vector2i,
	to_cell: Vector2i
)


# Dikirim sebelum satu turn disimpan.
signal turn_about_to_commit


# ==================================================
# GRID SETTINGS
# ==================================================

# Ukuran satu cell gameplay.
const TILE_SIZE: int = 48

# Karena object harus berada di TENGAH tile 48x48,
# center-nya adalah 24 pixel dari pojok cell.
const HALF_TILE: float = TILE_SIZE / 2.0


# ==================================================
# BOARD DATA
# ==================================================

var occupants: Dictionary = {}

var turn_history: Array = []

var current_turn: Array = []

var is_recording_turn: bool = false


# ==================================================
# TURN SYSTEM
# ==================================================

func begin_turn() -> void:
	current_turn.clear()
	is_recording_turn = true


func commit_turn() -> void:
	if not is_recording_turn:
		return

	# Kalau turn berisi action Player,
	# beri Enemy kesempatan bergerak.
	if not current_turn.is_empty():
		turn_about_to_commit.emit()

	# Simpan Player + Enemy sebagai satu turn.
	if not current_turn.is_empty():
		turn_history.append(
			current_turn.duplicate(true)
		)

		print(
			"TURN SAVED | Actions: ",
			current_turn.size(),
			" | History: ",
			turn_history.size()
		)

	current_turn.clear()
	is_recording_turn = false


func cancel_turn() -> void:
	current_turn.clear()
	is_recording_turn = false


# ==================================================
# GRID CONVERSION
# ==================================================

# World position -> logical grid cell.
#
# Contoh:
#
# World (24, 24)  -> Cell (0, 0)
# World (72, 24)  -> Cell (1, 0)
# World (120, 24) -> Cell (2, 0)
#
# floor dipakai karena posisi Board dianggap
# sebagai POJOK KIRI ATAS cell (0,0).
func world_to_grid(
	world_position: Vector2
) -> Vector2i:
	var local_position: Vector2 = (
		to_local(world_position)
	)

	return Vector2i(
		floori(
			local_position.x
			/ TILE_SIZE
		),
		floori(
			local_position.y
			/ TILE_SIZE
		)
	)


# Logical grid cell -> CENTER dunia dari tile tersebut.
#
# Cell (0,0) -> World (24,24)
# Cell (1,0) -> World (72,24)
# Cell (2,0) -> World (120,24)
func grid_to_world(
	cell: Vector2i
) -> Vector2:
	var local_position := Vector2(
		cell.x * TILE_SIZE + HALF_TILE,
		cell.y * TILE_SIZE + HALF_TILE
	)

	return to_global(
		local_position
	)


# ==================================================
# OCCUPANCY
# ==================================================

func register_object(
	cell: Vector2i,
	object: Node2D
) -> bool:
	if is_occupied(cell):
		push_error(
			"Gagal register object di cell %s. Cell sudah ditempati oleh %s."
			% [
				cell,
				occupants[cell].name
			]
		)

		return false

	occupants[cell] = object

	return true


func unregister_object(
	cell: Vector2i,
	object: Node2D
) -> bool:
	if occupants.get(cell) != object:
		return false

	occupants.erase(cell)

	return true


func is_occupied(
	cell: Vector2i
) -> bool:
	return occupants.has(cell)


func get_object_at(
	cell: Vector2i
) -> Node2D:
	return occupants.get(cell) as Node2D


# ==================================================
# MOVEMENT
# ==================================================

func move_object(
	from_cell: Vector2i,
	to_cell: Vector2i,
	object: Node2D
) -> bool:

	# Target harus kosong.
	if is_occupied(to_cell):
		return false

	# Simpan movement kalau sedang dalam turn.
	if is_recording_turn:
		current_turn.append({
			"type": "move",
			"object": object,
			"from_cell": from_cell,
			"to_cell": to_cell
		})

	# Update occupancy.
	occupants.erase(
		from_cell
	)

	occupants[to_cell] = object

	# Beri tahu puzzle system.
	object_moved.emit(
		object,
		from_cell,
		to_cell
	)

	return true


# ==================================================
# UNDO
# ==================================================

func undo_last_turn() -> bool:
	if turn_history.is_empty():
		print("UNDO | HISTORY EMPTY")
		return false

	var turn: Array = (
		turn_history.pop_back()
	)

	print(
		"=============================="
	)

	print(
		"UNDO TURN START | Actions: ",
		turn.size()
	)


	# Undo action terakhir -> pertama.
	for i in range(
		turn.size() - 1,
		-1,
		-1
	):
		var action: Dictionary = (
			turn[i]
		)

		var action_type: String = (
			action.get(
				"type",
				"move"
			)
		)

		print(
			"UNDO ACTION | Index: ",
			i,
			" | Type: ",
			action_type,
			" | Keys: ",
			action.keys()
		)


		# ==================================================
		# MOVE
		# ==================================================

		if action_type == "move":
			var object = (
				action.get(
					"object",
					null
				)
			)

			if not is_instance_valid(
				object
			):
				push_warning(
					"UNDO MOVE | object invalid"
				)

				continue


			var from_cell: Vector2i = (
				action["from_cell"]
			)

			var to_cell: Vector2i = (
				action["to_cell"]
			)


			occupants.erase(
				to_cell
			)

			occupants[from_cell] = (
				object
			)


			if object.has_method(
				"snap_to_cell"
			):
				object.snap_to_cell(
					from_cell
				)

			else:
				object.global_position = (
					grid_to_world(
						from_cell
					)
				)


			object_moved.emit(
				object,
				to_cell,
				from_cell
			)


		# ==================================================
		# CUSTOM
		# ==================================================

		elif action_type == "custom":
			if not action.has(
				"undo_callable"
			):
				push_error(
					"UNDO CUSTOM ERROR | "
					+ "undo_callable tidak ada | "
					+ str(action)
				)

				continue


			var undo_callable: Callable = (
				action.get(
					"undo_callable"
				)
			)


			if not undo_callable.is_valid():
				push_error(
					"UNDO CUSTOM ERROR | "
					+ "Callable invalid | "
					+ str(action)
				)

				continue


			var data: Dictionary = (
				action.get(
					"data",
					{}
				)
			)


			print(
				"UNDO CUSTOM CALL | ",
				undo_callable
			)


			undo_callable.call(
				data
			)


		else:
			push_warning(
				"UNDO | Unknown action type: "
				+ action_type
			)


	print(
		"UNDO TURN FINISHED"
	)

	print(
		"=============================="
	)

	return true
# ==================================================
# CUSTOM TURN ACTION
# ==================================================

func append_action_to_last_turn(
	action: Dictionary
) -> void:

	if turn_history.is_empty():
		turn_history.append(
			[action]
		)

		return

	turn_history[
		turn_history.size() - 1
	].append(
		action
	)


# Menambahkan custom action ke turn
# yang SEDANG berlangsung.
func append_action_to_current_turn(
	action: Dictionary
) -> bool:

	if not is_recording_turn:
		push_warning(
			"Tidak ada turn aktif untuk menyimpan custom action."
		)

		return false

	current_turn.append(
		action
	)

	return true
