class_name GrasshopperCharacter
extends GridCharacter


# ==================================================
# GRASSHOPPER SETTINGS
# ==================================================

# Seberapa jauh Character akan dilempar
# dari posisi awalnya.
#
# Bisa diubah Level Designer lewat Inspector.
@export_range(1, 10, 1)
var throw_range: int = 3


# Empat arah yang diperiksa Grasshopper.
#
# Tidak memakai diagonal.
# Empat arah di sekitar Grasshopper yang akan diperiksa.
# Array diberi tipe Vector2i supaya Godot tahu
# bahwa setiap direction adalah koordinat grid.
const THROW_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT
]


# ==================================================
# ACTIVE SKILL
# ==================================================

# Dipanggil oleh GridCharacter ketika pemain
# menekan Right Click / "use_skill".
func use_skill() -> bool:
	if board == null:
		return false

	# Kita hitung SEMUA lemparan terlebih dahulu
	# sebelum ada Character yang benar-benar bergerak.
	#
	# Tujuannya agar skill terasa simultan.
	var throw_plans: Array = []

	for direction in THROW_DIRECTIONS:
		var target_cell := grid_position + direction

		var occupant := board.get_object_at(
			target_cell
		)

		# Grasshopper hanya bisa menerbangkan Character.
		#
		# Box, Door, Wall, dll otomatis diabaikan.
		if not occupant is GridCharacter:
			continue

		var target := occupant as GridCharacter

		var landing_cell := find_throw_landing(
			target_cell,
			direction
		)

		# Kalau langsung terhalang,
		# Character tidak bisa dilempar.
		if landing_cell == target_cell:
			continue

		throw_plans.append({
			"character": target,
			"from_cell": target_cell,
			"landing_cell": landing_cell
		})


	# Tidak ada Character yang bisa dilempar.
	#
	# Return false membuat turn dibatalkan,
	# jadi Undo history tidak mendapat turn kosong.
	if throw_plans.is_empty():
		print("GRASSHOPPER | Tidak ada target yang bisa dilempar.")
		return false


	# ==================================================
	# EXECUTE THROW
	# ==================================================

	var moved_any_character: bool = false

	for plan in throw_plans:
		var target: GridCharacter = plan[
			"character"
		]

		var landing_cell: Vector2i = plan[
			"landing_cell"
		]

		var success := target.move_to_cell_in_current_turn(
			landing_cell
		)

		if success:
			moved_any_character = true

			print(
				"GRASSHOPPER THROW | ",
				target.name,
				" → ",
				landing_cell
			)

	return moved_any_character


# ==================================================
# THROW PATH
# ==================================================

# Mencari cell terakhir yang aman untuk landing.
#
# Character dianggap sedang berada di udara,
# sehingga Pit / Spike di TENGAH jalur tidak bereaksi.
#
# Yang menghentikan lemparan adalah object blocking
# yang tercatat di Board:
# - Wall
# - Door tertutup
# - Box
# - Character
func find_throw_landing(
	start_cell: Vector2i,
	direction: Vector2i
) -> Vector2i:
	var landing_cell := start_cell

	for step in range(throw_range):
		var next_cell := landing_cell + direction

		# Ada blocker.
		# Berhenti di cell terakhir sebelum blocker.
		if board.is_occupied(next_cell):
			break

		landing_cell = next_cell

	return landing_cell
