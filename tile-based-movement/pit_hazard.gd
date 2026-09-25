class_name PitHazard
extends BaseHazard


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	# Pit selalu aktif.
	# Pit tidak memakai Pressure Plate atau Nectar.
	activation_mode = ActivationMode.ALWAYS
	invert_activation = false

	# Visual Pit nantinya kemungkinan berasal
	# dari Ground / Decoration TileMap.
	hide_when_inactive = false

	# Jalankan setup BaseHazard:
	# - register group "hazards"
	# - Board
	# - posisi grid
	# - activation state
	super()

	if board == null:
		return

	# Pastikan Pit aktif sejak awal.
	set_hazard_active(true)

	# Pit mendengarkan semua perpindahan
	# object melalui Board.
	if not board.object_moved.is_connected(
		_on_board_object_moved
	):
		board.object_moved.connect(
			_on_board_object_moved
		)


# ==================================================
# OBJECT ENTERS PIT
# ==================================================

func _on_board_object_moved(
	object: Node2D,
	_from_cell: Vector2i,
	to_cell: Vector2i
) -> void:
	# Tidak masuk cell Pit ini.
	if to_cell != grid_position:
		return

	# ------------------------------------------
	# BOX
	# ------------------------------------------
	if object is PushableBox:
		drop_box(
			object as PushableBox,
			to_cell
		)
		return

	# ------------------------------------------
	# CHARACTER
	# ------------------------------------------
	if object is GridCharacter:
		var character := object as GridCharacter

		# Nanti Butterfly Flying akan lolos
		# karena can_cross_pit() menjadi true.
		if character.can_cross_pit():
			print(
				"PIT SAFE | ",
				character.name,
				" bisa melewati Pit."
			)
			return

		print(
			"PIT FALL | Character: ",
			character.name
		)

		# BaseHazard mengirim signal ke Level.
		# Level kemudian melakukan reset.
		trigger_character(
			character
		)


# ==================================================
# BOX FALL
# ==================================================

func drop_box(
	box: PushableBox,
	pit_cell: Vector2i
) -> void:
	# Pastikan Box benar-benar tercatat
	# berada di cell Pit.
	if board.get_object_at(
		pit_cell
	) != box:
		return

	# Hapus Box dari occupancy Board.
	if not board.unregister_object(
		pit_cell,
		box
	):
		return

	# Jangan queue_free().
	# Box masih dibutuhkan untuk Undo.
	box.visible = false

	print(
		"BOX FALL INTO PIT | ",
		box.name,
		" | Cell: ",
		pit_cell
	)

	# Simpan kejadian Box jatuh ke turn
	# yang sama dengan movement Box.
	board.append_action_to_current_turn({
		"type": "custom",

		"undo_callable": Callable(
			self,
			"_undo_box_fall"
		),

		"data": {
			"box": box,
			"pit_cell": pit_cell
		}
	})


# ==================================================
# UNDO BOX FALL
# ==================================================

func _undo_box_fall(
	data: Dictionary
) -> void:
	var box := data["box"] as PushableBox

	var pit_cell: Vector2i = data[
		"pit_cell"
	]

	if not is_instance_valid(box):
		return

	# Undo berjalan terbalik:
	#
	# 1. Undo Box Fall
	#    Box sementara muncul kembali di Pit.
	#
	# 2. Undo movement
	#    Box kembali ke cell sebelum Pit.

	if not board.is_occupied(
		pit_cell
	):
		board.register_object(
			pit_cell,
			box
		)

	box.visible = true

	if box.has_method(
		"snap_to_cell"
	):
		box.snap_to_cell(
			pit_cell
		)

	print(
		"UNDO BOX PIT | ",
		box.name
	)
