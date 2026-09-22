class_name Board
extends Node2D


# Ukuran satu cell grid dalam pixel.
const TILE_SIZE: int = 16


# Menyimpan object yang sedang menempati setiap cell grid.
var occupants: Dictionary = {}

# Menyimpan turn-turn yang sudah selesai.
# Nantinya dipakai untuk Undo.
var turn_history: Array = []


# Menyimpan semua perpindahan yang terjadi
# dalam satu turn yang sedang berlangsung.
var current_turn: Array = []


# Apakah Board sedang merekam sebuah turn?
var is_recording_turn: bool = false

# Mulai merekam satu turn baru.
func begin_turn() -> void:
	current_turn.clear()
	is_recording_turn = true


# Menyimpan turn yang sudah berhasil dilakukan.
func commit_turn() -> void:
	if not is_recording_turn:
		return

	if not current_turn.is_empty():
		turn_history.append(
			current_turn.duplicate(true)
		)

		print(
			"TURN SAVED | Moves: ",
			current_turn.size(),
			" | History: ",
			turn_history.size()
		)

	current_turn.clear()
	is_recording_turn = false


# Membatalkan rekaman turn jika aksi gagal.
func cancel_turn() -> void:
	current_turn.clear()
	is_recording_turn = false


# Mengubah posisi pixel/world menjadi posisi cell grid.
func world_to_grid(world_position: Vector2) -> Vector2i:
	var local_position := to_local(world_position)

	return Vector2i(
		roundi(local_position.x / TILE_SIZE),
		roundi(local_position.y / TILE_SIZE)
	)


# Mengubah posisi cell grid menjadi posisi pixel/world.
func grid_to_world(cell: Vector2i) -> Vector2:
	var local_position := Vector2(
		cell.x * TILE_SIZE,
		cell.y * TILE_SIZE
	)

	return to_global(local_position)


# Mendaftarkan sebuah object sebagai penghuni suatu cell.
func register_object(cell: Vector2i, object: Node2D) -> void:
	occupants[cell] = object
	
# Mengecek apakah sebuah cell sedang ditempati object.
func is_occupied(cell: Vector2i) -> bool:
	return occupants.has(cell)
	
# Mengambil object yang berada pada sebuah cell.
# Jika cell kosong, hasilnya null.
func get_object_at(cell: Vector2i) -> Node2D:
	return occupants.get(cell)

# Memindahkan catatan object dari satu cell ke cell lain.
# Mengembalikan true jika berhasil, false jika tujuan sudah terisi.
func move_object(
	from_cell: Vector2i,
	to_cell: Vector2i,
	object: Node2D
) -> bool:
	if is_occupied(to_cell):
		return false

	# Kalau sedang ada turn,
	# catat perpindahan ini sebelum dilakukan.
	if is_recording_turn:
		current_turn.append({
			"object": object,
			"from_cell": from_cell,
			"to_cell": to_cell
		})

	occupants.erase(from_cell)
	occupants[to_cell] = object

	return true
	
	# Mengembalikan satu turn terakhir.
# true  = ada turn yang berhasil di-Undo
# false = history sudah kosong
func undo_last_turn() -> bool:
	if turn_history.is_empty():
		return false

	# Ambil turn terakhir sekaligus hapus dari history.
	var turn: Array = turn_history.pop_back()

	# Undo dilakukan dari movement terakhir ke movement pertama.
	for i in range(turn.size() - 1, -1, -1):
		var move: Dictionary = turn[i]

		var object: Node2D = move["object"]
		var from_cell: Vector2i = move["from_cell"]
		var to_cell: Vector2i = move["to_cell"]

		# Hapus object dari posisi sesudah movement.
		occupants.erase(to_cell)

		# Kembalikan object ke posisi sebelum movement.
		occupants[from_cell] = object

		# Biarkan object menyinkronkan posisi logic + visualnya sendiri.
		if object.has_method("snap_to_cell"):
			object.snap_to_cell(from_cell)
		else:
			object.global_position = grid_to_world(from_cell)

	print(
		"UNDO | Moves: ",
		turn.size(),
		" | History left: ",
		turn_history.size()
	)

	return true
