class_name ButterflyCharacter
extends GridCharacter


# Maksimal Nectar yang bisa dibawa Butterfly.
const MAX_NECTAR: int = 3


# Memberi tahu sistem lain saat jumlah Nectar berubah.
# Nanti dipakai UI pada Batch C.
signal nectar_changed(
	current: int,
	maximum: int
)

# ==================================================
# FLYING
# ==================================================

# Apakah Butterfly sedang terbang.
# Right Click akan toggle ON / OFF.
var is_flying: bool = false
# Nectar yang sedang dibawa Butterfly.
var nectar_count: int = 0


func get_nectar_count() -> int:
	return nectar_count


# Apakah Butterfly masih bisa mengambil Nectar.
func can_collect_nectar() -> bool:
	return nectar_count < MAX_NECTAR


# Menambah satu Nectar.
func add_nectar() -> bool:
	if not can_collect_nectar():
		return false

	nectar_count += 1

	nectar_changed.emit(
		nectar_count,
		MAX_NECTAR
	)

	print(
		"BUTTERFLY NECTAR: ",
		nectar_count,
		"/",
		MAX_NECTAR
	)

	return true


# Mengurangi satu Nectar.
# Dipakai oleh sistem Undo.
func remove_nectar() -> bool:
	if nectar_count <= 0:
		return false

	nectar_count -= 1

	nectar_changed.emit(
		nectar_count,
		MAX_NECTAR
	)

	print(
		"BUTTERFLY NECTAR UNDO: ",
		nectar_count,
		"/",
		MAX_NECTAR
	)

	return true

# ==================================================
# ACTIVE SKILL — FLYING
# ==================================================

# Right Click:
# Flying OFF -> ON
# Flying ON  -> OFF
#
# Tidak boleh berhenti terbang ketika sedang
# berdiri di atas Pit.
func use_skill() -> bool:
	# Kalau sedang Flying dan berdiri di atas Pit,
	# jangan izinkan Flying dimatikan.
	if is_flying and is_over_pit():
		print(
			"BUTTERFLY | Tidak bisa berhenti terbang di atas Pit."
		)
		return false

	var previous_state := is_flying

	is_flying = not is_flying

	print(
		"BUTTERFLY FLYING: ",
		is_flying
	)

	# Simpan perubahan Flying ke turn yang sedang aktif.
	# Jadi Z bisa membatalkan toggle Flying.
	board.append_action_to_current_turn({
		"type": "custom",
		"undo_callable": Callable(
			self,
			"_undo_flying_toggle"
		),
		"data": {
			"previous_state": previous_state
		}
	})

	return true


# ==================================================
# PIT CAPABILITY
# ==================================================

# Override fungsi milik GridCharacter.
#
# Butterfly hanya aman melewati Pit
# ketika Flying sedang aktif.
func can_cross_pit() -> bool:
	return is_flying


# ==================================================
# PIT CHECK
# ==================================================

# Cek apakah Butterfly sekarang sedang
# berdiri tepat di atas sebuah PitHazard.
func is_over_pit() -> bool:
	for node in get_tree().get_nodes_in_group(
		"hazards"
	):
		if not node is PitHazard:
			continue

		var pit := node as PitHazard

		if pit.grid_position == grid_position:
			return true

	return false


# ==================================================
# UNDO FLYING
# ==================================================

# Mengembalikan state Flying sebelum
# Right Click terakhir.
func _undo_flying_toggle(
	data: Dictionary
) -> void:
	is_flying = data[
		"previous_state"
	]

	print(
		"UNDO BUTTERFLY FLYING: ",
		is_flying
	)
