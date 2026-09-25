class_name PuzzleDoor
extends StaticBody2D


@export var board: Board


# Semua Pressure Plate yang mengontrol Door ini.
# Isi lewat Inspector.
@export var trigger_plates: Array[PressurePlate] = []


# Berapa Plate yang harus ON agar Door terbuka.
@export var required_plates: int = 1


var grid_position: Vector2i


# Keadaan Door sekarang.
var is_open: bool = false


# Apakah kondisi Pressure Plate meminta Door terbuka?
var wants_to_be_open: bool = false


# Door ingin menutup, tetapi cell masih ditempati.
var waiting_to_close: bool = false


@onready var collision_shape: CollisionShape2D = (
	$CollisionShape2D
)


func _ready() -> void:
	if board == null:
		push_error(
			"Door belum terhubung ke Board!"
		)
		return

	grid_position = board.world_to_grid(
		global_position
	)

	global_position = board.grid_to_world(
		grid_position
	)

	# Door mulai tertutup dan menjadi blocking object.
	if not board.register_object(
		grid_position,
		self
	):
		push_error(
			"Door gagal register ke Board!"
		)
		return

	# Tidak perlu _process selama kondisi normal.
	set_process(false)

	connect_trigger_plates()

	# Tunggu semua Pressure Plate selesai _ready(),
	# baru hitung kondisi awal.
	call_deferred(
		"evaluate_plate_state"
	)


# ==================================================
# PRESSURE PLATE SETUP
# ==================================================

func connect_trigger_plates() -> void:
	if trigger_plates.is_empty():
		push_warning(
			"%s belum memiliki Trigger Plates!"
			% name
		)
		return

	for plate in trigger_plates:
		if plate == null:
			continue

		if not plate.activated.is_connected(
			_on_plate_state_changed
		):
			plate.activated.connect(
				_on_plate_state_changed
			)

		if not plate.deactivated.is_connected(
			_on_plate_state_changed
		):
			plate.deactivated.connect(
				_on_plate_state_changed
			)


# Dipanggil setiap salah satu Plate berubah.
func _on_plate_state_changed() -> void:
	evaluate_plate_state()


# ==================================================
# PLATE COUNTING
# ==================================================

func evaluate_plate_state() -> void:
	var active_count: int = 0

	for plate in trigger_plates:
		if plate == null:
			continue

		if plate.is_pressed:
			active_count += 1

	print(
		name,
		" | Plates: ",
		active_count,
		"/",
		required_plates
	)

	# Required Plates harus minimal 1.
	var needed: int = maxi(
		required_plates,
		1
	)

	wants_to_be_open = (
		active_count >= needed
	)

	if wants_to_be_open:
		open_door()
	else:
		close_door()


# ==================================================
# OPEN
# ==================================================

func open_door() -> void:
	wants_to_be_open = true

	waiting_to_close = false
	set_process(false)

	# Sudah terbuka.
	if is_open:
		return

	# Hilangkan Door dari Board occupancy.
	if not board.unregister_object(
		grid_position,
		self
	):
		push_error(
			"Door gagal unregister dari Board!"
		)
		return

	is_open = true
	visible = false

	if collision_shape:
		collision_shape.set_deferred(
			"disabled",
			true
		)

	print("DOOR OPEN: ", name)


# ==================================================
# CLOSE REQUEST
# ==================================================

func close_door() -> void:
	wants_to_be_open = false

	try_close_door()


# ==================================================
# SAFE CLOSING
# ==================================================

func try_close_door() -> void:
	if not is_open:
		set_process(false)
		return

	# Plate kembali memenuhi syarat.
	if wants_to_be_open:
		waiting_to_close = false
		set_process(false)
		return

	# Jangan menutup di atas Character / Box.
	if board.is_occupied(
		grid_position
	):
		waiting_to_close = true
		set_process(true)

		var occupant := board.get_object_at(
			grid_position
		)

		if occupant != null:
			print(
				"DOOR WAITING: ",
				name,
				" | ditempati ",
				occupant.name
			)

		return

	# Cell kosong, aman untuk menutup.
	if not board.register_object(
		grid_position,
		self
	):
		return

	waiting_to_close = false
	is_open = false

	set_process(false)

	visible = true

	if collision_shape:
		collision_shape.set_deferred(
			"disabled",
			false
		)

	print("DOOR CLOSED: ", name)


# ==================================================
# WAITING CHECK
# ==================================================

func _process(_delta: float) -> void:
	# Hanya berjalan ketika Door sedang menunggu
	# Character / Box keluar dari cell Door.
	if not waiting_to_close:
		set_process(false)
		return

	try_close_door()
