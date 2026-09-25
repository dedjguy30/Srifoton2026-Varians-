class_name PushableBox
extends Node2D


const MOVE_DURATION: float = 0.185


# Board yang digunakan oleh Box.
@export var board: Board


# Kekuatan minimum yang diperlukan untuk mendorong Box.
@export var required_push_strength: int = 1


@onready var sprite: Sprite2D = $Sprite2D


# Posisi logika Box di dalam grid.
var grid_position: Vector2i


# Tween movement visual Box.
var move_tween: Tween


func _ready() -> void:
	if board == null:
		push_error("Box belum terhubung ke Board!")
		return

	grid_position = board.world_to_grid(global_position)

	global_position = board.grid_to_world(grid_position)

	board.register_object(
		grid_position,
		self
	
	)
		# Box boleh mengaktifkan Pressure Plate.
	add_to_group("pressure_plate_activator")

# Mengecek apakah karakter cukup kuat untuk mendorong Box.
func can_be_pushed_by(pusher_strength: int) -> bool:
	return pusher_strength >= required_push_strength


# Mengecek apakah animasi Box masih berlangsung.
func is_moving() -> bool:
	return move_tween != null and move_tween.is_running()


# Mencoba mendorong Box satu cell.
func try_push(
	pusher_strength: int,
	direction: Vector2i
) -> bool:
	# Jangan menerima push baru ketika visual masih bergerak.
	if is_moving():
		return false

	# Karakter harus cukup kuat.
	if not can_be_pushed_by(pusher_strength):
		return false

	var target_cell := grid_position + direction

	# Box tidak bisa masuk ke cell yang sudah terisi.
	if board.is_occupied(target_cell):
		return false

	# Simpan posisi visual lama sebelum logic dipindahkan.
	var old_world_position := global_position

	# Update occupancy Box di Board.
	var success: bool = board.move_object(
		grid_position,
		target_cell,
		self
	)

	if not success:
		return false

	# Update posisi logika.
	grid_position = target_cell

	# Root Box langsung pindah ke posisi logic baru.
	global_position = board.grid_to_world(grid_position)

	# Sprite tetap terlihat di posisi sebelumnya.
	sprite.global_position = old_world_position

	# Lalu sprite bergerak halus menuju posisi baru.
	if move_tween:
		move_tween.kill()

	move_tween = create_tween()

	move_tween.set_process_mode(
		Tween.TWEEN_PROCESS_PHYSICS
	)

	move_tween.tween_property(
		sprite,
		"global_position",
		global_position,
		MOVE_DURATION
	).set_trans(Tween.TRANS_SINE)

	return true
	
	# Memindahkan Box langsung ke sebuah cell.
# Dipakai oleh sistem Undo / Reset.
func snap_to_cell(cell: Vector2i) -> void:
	if move_tween:
		move_tween.kill()

	grid_position = cell
	global_position = board.grid_to_world(grid_position)

	sprite.global_position = global_position
