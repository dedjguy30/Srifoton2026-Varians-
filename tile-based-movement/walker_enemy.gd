class_name WalkerEnemy
extends GridEnemy


# ==================================================
# WALKER MOVEMENT OPTIONS
# ==================================================

# Semua arah yang bisa dimasukkan
# ke Movement Pattern lewat Inspector.
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

# Pattern gerakan Walker.
#
# Bisa diedit lewat Inspector.
#
# Default:
# KIRI
# KIRI
# KANAN
# ATAS
# ATAS
# BAWAH
#
# Setelah langkah terakhir,
# kembali ke langkah pertama.
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

# Index gerakan yang akan dipakai
# pada turn berikutnya.
var pattern_index: int = 0


# ==================================================
# WALKER TURN
# ==================================================

func take_turn() -> void:
	if board == null:
		return

	# Tidak ada pattern = Walker diam.
	if movement_pattern.is_empty():
		return

	# Safety.
	if pattern_index >= movement_pattern.size():
		pattern_index = 0

	# Simpan index sebelum berubah.
	# Ini diperlukan untuk Undo.
	var previous_index: int = pattern_index

	var movement: MoveDirection = (
		movement_pattern[
			pattern_index
		]
	)

	# Pattern maju SATU langkah setiap turn.
	#
	# Bahkan kalau Walker terhalang,
	# pattern tetap maju.
	pattern_index += 1

	if pattern_index >= movement_pattern.size():
		pattern_index = 0

	# Simpan perubahan index ke turn yang sama.
	#
	# Jadi Undo juga mengembalikan
	# posisi dalam pattern.
	board.append_action_to_current_turn({
		"type": "custom",
		"undo_callable": Callable(
			self,
			"_undo_pattern_step"
		),
		"data": {
			"previous_index": previous_index
		}
	})

	var direction: Vector2i = (
		get_direction_vector(
			movement
		)
	)

	# DIAM tetap menghabiskan
	# satu langkah dalam pattern.
	if direction == Vector2i.ZERO:
		print(
			"WALKER DIAM | ",
			name
		)
		return

	# Coba bergerak.
	var moved: bool = move_enemy(
		direction
	)

	if moved:
		print(
			"WALKER MOVE | ",
			name,
			" | ",
			get_direction_name(
				movement
			)
		)

	else:
		# Kalau blocked:
		# tidak bergerak,
		# tetapi pattern sudah maju.
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

# Mengubah pilihan enum menjadi
# arah grid Vector2i.
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


# Nama arah untuk debug Output.
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

# Mengembalikan index pattern
# sebelum turn tadi terjadi.
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
