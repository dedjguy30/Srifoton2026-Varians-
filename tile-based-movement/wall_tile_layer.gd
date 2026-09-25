class_name WallTileLayer
extends TileMapLayer


# ==================================================
# BOARD
# ==================================================

@export var board: Board


# Semua cell Wall yang sudah didaftarkan ke Board.
var registered_wall_cells: Array[Vector2i] = []


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	if board == null:
		push_error(
			"Walls belum terhubung ke Board!"
		)
		return

	# Tunggu semua Character / Enemy / Object
	# selesai register terlebih dahulu.
	call_deferred(
		"register_wall_cells"
	)


# ==================================================
# REGISTER WALL TILE -> BOARD
# ==================================================

func register_wall_cells() -> void:
	if board == null:
		return

	registered_wall_cells.clear()

	var wall_tiles: Array[Vector2i] = get_used_cells()

	print(
		"WALL TILES FOUND: ",
		wall_tiles.size()
	)


	for tile_cell in wall_tiles:

		# Posisi tengah tile dalam local TileMap.
		var local_position: Vector2 = map_to_local(
			tile_cell
		)

		# Ubah menjadi world position.
		var world_position: Vector2 = to_global(
			local_position
		)

		# Ubah world position menjadi cell Board.
		var board_cell: Vector2i = board.world_to_grid(
			world_position
		)


		# ==================================================
		# CEK KONFLIK
		# ==================================================

		if board.is_occupied(
			board_cell
		):
			var existing_object := board.get_object_at(
				board_cell
			)

			push_warning(
				"WALL CONFLICT | Cell %s sudah ditempati %s"
				% [
					board_cell,
					str(existing_object)
				]
			)

			continue


		# ==================================================
		# REGISTER WALL
		# ==================================================

		board.register_object(
			board_cell,
			self
		)

		registered_wall_cells.append(
			board_cell
		)


	print(
		"WALLS REGISTERED: ",
		registered_wall_cells.size()
	)


# ==================================================
# CLEANUP
# ==================================================

func unregister_wall_cells() -> void:
	if board == null:
		return

	for cell in registered_wall_cells:

		if board.get_object_at(
			cell
		) == self:

			board.unregister_object(
				cell,
				self
			)

	registered_wall_cells.clear()


func _exit_tree() -> void:
	unregister_wall_cells()
