class_name ChaserEnemy
extends GridEnemy


# ==================================================
# CHASER SETTINGS
# ==================================================

# Setting khusus Chaser akan muncul
# dalam satu group di Inspector.
@export_group("Chaser Settings")


# Jarak maksimum Chaser mendeteksi Character.
#
# Kita memakai Manhattan Distance:
#
# abs(dx) + abs(dy)
#
# Default 5 tile.
@export_range(1, 20, 1)
var detection_radius: int = 5


# Chaser bergerak setiap berapa Player turn.
#
# 1 = setiap turn
# 2 = setiap 2 turn
# 3 = setiap 3 turn
#
# Default 2 supaya Player masih bisa
# mencoba kabur dari radius.
@export_range(1, 5, 1)
var move_every_turns: int = 2


# ==================================================
# RUNTIME DATA
# ==================================================

# Menghitung berapa turn Chaser sudah menunggu
# sebelum boleh bergerak lagi.
var chase_turn_counter: int = 0


# ==================================================
# ENEMY TURN
# ==================================================

func take_turn() -> void:
	if board == null:
		return

	# Cari Character terdekat yang masih
	# berada dalam detection radius.
	var target: GridCharacter = (
		find_nearest_character()
	)


	# ==================================================
	# TIDAK ADA TARGET
	# ==================================================

	if target == null:
		# Jika sebelumnya Chaser sedang menghitung turn,
		# simpan perubahan counter untuk Undo.
		if chase_turn_counter != 0:
			save_counter_undo()

		# Player berhasil keluar radius.
		# Chaser kembali idle.
		chase_turn_counter = 0

		print(
			"CHASER IDLE | ",
			name
		)
		return


	# ==================================================
	# CHASE TIMER
	# ==================================================

	# Simpan nilai counter sebelum berubah
	# supaya Undo timing Chaser tetap benar.
	save_counter_undo()

	chase_turn_counter += 1

	# Belum waktunya bergerak.
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

	# Sudah waktunya bergerak.
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

	var moved: bool = (
	move_or_attack_character(
		direction
	)
)

	if moved:
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

# Cari Character terdekat yang:
#
# 1. GridCharacter
# 2. memakai Board yang sama
# 3. masih benar-benar terdaftar di Board
# 4. berada dalam Detection Radius
func find_nearest_character() -> GridCharacter:
	var nearest: GridCharacter = null
	var nearest_distance: int = 999999

	for node in get_tree().get_nodes_in_group(
		"characters"
	):
		if not node is GridCharacter:
			continue

		var character := node as GridCharacter

		# Harus memakai Board yang sama.
		if character.board != board:
			continue

		# Kalau Character sudah transform / nanti mati,
		# dia mungkin sudah tidak ada dalam occupancy.
		#
		# Character seperti itu tidak boleh dikejar.
		if board.get_object_at(
			character.grid_position
		) != character:
			continue

		var distance: int = get_grid_distance(
			grid_position,
			character.grid_position
		)

		# Di luar radius.
		if distance > detection_radius:
			continue

		# Ambil Character dengan jarak terkecil.
		if distance < nearest_distance:
			nearest = character
			nearest_distance = distance

	return nearest


# ==================================================
# GRID DISTANCE
# ==================================================

# Manhattan Distance.
#
# Contoh:
#
# Enemy  = (2, 2)
# Player = (5, 4)
#
# X distance = 3
# Y distance = 2
#
# total = 5
func get_grid_distance(
	from_cell: Vector2i,
	to_cell: Vector2i
) -> int:
	return (
		abs(to_cell.x - from_cell.x)
		+ abs(to_cell.y - from_cell.y)
	)


# ==================================================
# MOVEMENT DECISION
# ==================================================

# Memilih satu arah untuk mendekati target.
#
# Axis dengan jarak terbesar dicoba dulu.
# Kalau blocked, coba axis satunya.
#
# Chaser sengaja belum memakai pathfinding rumit
# supaya gerakannya deterministic untuk puzzle.
func choose_move_direction(
	target: GridCharacter
) -> Vector2i:
	var difference: Vector2i = (
		target.grid_position
		- grid_position
	)

	var horizontal: Vector2i = Vector2i.ZERO
	var vertical: Vector2i = Vector2i.ZERO


	# ------------------------------------------
	# HORIZONTAL
	# ------------------------------------------

	if difference.x > 0:
		horizontal = Vector2i.RIGHT

	elif difference.x < 0:
		horizontal = Vector2i.LEFT


	# ------------------------------------------
	# VERTICAL
	# ------------------------------------------

	if difference.y > 0:
		vertical = Vector2i.DOWN

	elif difference.y < 0:
		vertical = Vector2i.UP


	# ------------------------------------------
	# PRIORITY
	# ------------------------------------------

	# Horizontal lebih jauh atau sama.
	if abs(difference.x) >= abs(difference.y):
		if can_move_to_direction(
			horizontal
		):
			return horizontal

		if can_move_to_direction(
			vertical
		):
			return vertical

	# Vertical lebih jauh.
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

# Mengecek apakah satu arah tersedia.
#
# Untuk sekarang Character masih dianggap blocker.
#
# Nanti di Character Death / Enemy Combat:
# Enemy yang mencoba masuk Character
# akan bisa membunuh Character.
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

	# Kosong = boleh jalan.
	if target_object == null:
		return true

	# Character hidup = boleh diserang.
	if target_object is GridCharacter:
		var character := (
			target_object as GridCharacter
		)

		return character.is_alive

	# Wall / Box / Door / Enemy = blocker.
	return false


# ==================================================
# CHASE COUNTER UNDO
# ==================================================

# Simpan counter Chaser sebagai custom action
# di turn Player yang sedang berjalan.
#
# Jadi Undo mengembalikan:
# - posisi Player
# - posisi Chaser
# - timing Chaser
func save_counter_undo() -> void:
	board.append_action_to_current_turn({
		"type": "custom",

		"undo_callable": Callable(
			self,
			"_undo_chase_counter"
		),

		"data": {
			"previous_counter": chase_turn_counter
		}
	})


# Mengembalikan counter ke nilai sebelum turn.
func _undo_chase_counter(
	data: Dictionary
) -> void:
	chase_turn_counter = data[
		"previous_counter"
	]
