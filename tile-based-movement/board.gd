class_name Board
extends Node2D


# Dikirim SETELAH object selesai berpindah cell.
# Puzzle object seperti Pressure Plate bisa mendengarkan signal ini.
signal object_moved(
	object: Node2D,
	from_cell: Vector2i,
	to_cell: Vector2i
)

# Dikirim sebelum satu turn disimpan.
# Enemy akan bergerak saat signal ini keluar,
# sehingga gerakan Player + Enemy masuk satu Undo.
signal turn_about_to_commit

# Ukuran satu cell grid dalam pixel.
const TILE_SIZE: int = 48


# Object blocking yang menempati setiap cell.
var occupants: Dictionary = {}


# Turn-turn yang sudah selesai.
var turn_history: Array = []


# Semua action dalam turn yang sedang berjalan.
var current_turn: Array = []


# Apakah Board sedang merekam turn?
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

	# Kalau turn memang berisi action Player,
	# beri Enemy kesempatan bergerak.
	#
	# Board masih merekam current_turn,
	# jadi gerakan Enemy ikut tersimpan.
	if not current_turn.is_empty():
		turn_about_to_commit.emit()

	# Setelah Player + Enemy selesai,
	# simpan semuanya sebagai satu turn.
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

func world_to_grid(
	world_position: Vector2
) -> Vector2i:
	var local_position := to_local(
		world_position
	)

	return Vector2i(
		roundi(local_position.x / TILE_SIZE),
		roundi(local_position.y / TILE_SIZE)
	)


func grid_to_world(
	cell: Vector2i
) -> Vector2:
	var local_position := Vector2(
		cell.x * TILE_SIZE,
		cell.y * TILE_SIZE
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
	# Target cell harus kosong.
	if is_occupied(to_cell):
		return false

	# Catat movement jika sedang berada dalam turn.
	if is_recording_turn:
		current_turn.append({
			"type": "move",
			"object": object,
			"from_cell": from_cell,
			"to_cell": to_cell
		})

	# Update occupancy terlebih dahulu.
	occupants.erase(from_cell)
	occupants[to_cell] = object

	# BARU beri tahu puzzle system.
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
		return false

	var turn: Array = turn_history.pop_back()

	# Undo dari action terakhir ke action pertama.
	for i in range(
		turn.size() - 1,
		-1,
		-1
	):
		var action: Dictionary = turn[i]

		var action_type: String = action.get(
			"type",
			"move"
		)

		# ------------------------------------------
		# Movement Undo
		# ------------------------------------------
		if action_type == "move":
			var object: Node2D = action["object"]
			var from_cell: Vector2i = action[
				"from_cell"
			]
			var to_cell: Vector2i = action[
				"to_cell"
			]

			if not is_instance_valid(object):
				continue

			# Balikkan occupancy.
			occupants.erase(to_cell)
			occupants[from_cell] = object

			# Balikkan posisi visual/logical object.
			if object.has_method(
				"snap_to_cell"
			):
				object.snap_to_cell(
					from_cell
				)
			else:
				object.global_position = (
					grid_to_world(from_cell)
				)

			# Undo juga dihitung sebagai movement
			# untuk Pressure Plate / puzzle objects.
			object_moved.emit(
				object,
				to_cell,
				from_cell
			)

		# ------------------------------------------
		# Custom Gameplay Undo
		# ------------------------------------------
		elif action_type == "custom":
			var undo_callable: Callable = action[
				"undo_callable"
			]

			var data: Dictionary = action[
				"data"
			]

			if undo_callable.is_valid():
				undo_callable.call(data)

	print(
		"UNDO | Actions: ",
		turn.size(),
		" | History left: ",
		turn_history.size()
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
	].append(action)

# Menambahkan custom action ke turn
# yang SEDANG berlangsung.
#
# Contoh:
# Box didorong ke Pit
# -> movement Box tercatat
# -> Box jatuh tercatat
#
# Jadi satu kali Undo akan mengembalikan
# seluruh kejadian tersebut.
func append_action_to_current_turn(
	action: Dictionary
) -> bool:
	if not is_recording_turn:
		push_warning(
			"Tidak ada turn aktif untuk menyimpan custom action."
		)
		return false

	current_turn.append(action)
	return true
