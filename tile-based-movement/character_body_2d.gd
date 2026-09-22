class_name GridCharacter
extends CharacterBody2D

const MOVE_DURATION: float = 0.185
@export var board: Board
# Kekuatan karakter untuk mendorong object.
# 0 = tidak bisa push.
@export var push_strength: int = 1

@onready var sprite: Sprite2D = $Sprite2D

@onready var ray_up: RayCast2D = $up
@onready var ray_down: RayCast2D = $down
@onready var ray_left: RayCast2D = $left
@onready var ray_right: RayCast2D = $right




var grid_position: Vector2i = Vector2i.ZERO
var move_tween: Tween


func _ready() -> void:
	if board == null:
		push_error("Player belum terhubung ke Board!")
		return

	# Cari posisi cell Player berdasarkan posisi dunianya.
	grid_position = board.world_to_grid(global_position)

	# Pastikan posisi Player tepat pada grid milik Board.
	global_position = board.grid_to_world(grid_position)

	# Daftarkan Player sebagai penghuni cell tersebut.
	board.register_object(
		grid_position,
		self
	)

	print("Player mulai")
	print("Grid position: ", grid_position)
	print("World position: ", global_position)


func _physics_process(_delta: float) -> void:
	if is_moving():
		return

	# Undo hanya sekali setiap tombol ditekan.
	if Input.is_action_just_pressed("undo"):
		board.undo_last_turn()
		return

	var direction := get_input_direction()

	if direction == Vector2i.ZERO:
		return

	if is_direction_blocked(direction):
		return

	move_one_tile(direction)


func get_input_direction() -> Vector2i:
	if Input.is_action_pressed("ui_up"):
		return Vector2i.UP

	if Input.is_action_pressed("ui_down"):
		return Vector2i.DOWN

	if Input.is_action_pressed("ui_left"):
		return Vector2i.LEFT

	if Input.is_action_pressed("ui_right"):
		return Vector2i.RIGHT

	return Vector2i.ZERO


func is_direction_blocked(direction: Vector2i) -> bool:
	if direction == Vector2i.UP:
		print("UP blocked: ", ray_up.is_colliding())
		return ray_up.is_colliding()

	if direction == Vector2i.DOWN:
		print("DOWN blocked: ", ray_down.is_colliding())
		return ray_down.is_colliding()

	if direction == Vector2i.LEFT:
		print("LEFT blocked: ", ray_left.is_colliding())
		return ray_left.is_colliding()

	if direction == Vector2i.RIGHT:
		print("RIGHT blocked: ", ray_right.is_colliding())
		return ray_right.is_colliding()

	return true


func move_one_tile(direction: Vector2i) -> void:
	var target_cell := grid_position + direction

	# Mulai merekam satu aksi Player.
	board.begin_turn()

	# Ada object di cell tujuan.
	if board.is_occupied(target_cell):
		var target_object := board.get_object_at(target_cell)

		# Kalau object adalah Box, coba dorong.
		if target_object is PushableBox:
			var box := target_object as PushableBox

			var push_success: bool = box.try_push(
				push_strength,
				direction
			)

			# Push gagal.
			# Jangan simpan turn.
			if not push_success:
				board.cancel_turn()
				return

		# Object lain menghalangi Player.
		else:
			board.cancel_turn()
			return

	var old_world_position := global_position

	var success: bool = board.move_object(
		grid_position,
		target_cell,
		self
	)

	if not success:
		board.cancel_turn()
		return

	grid_position = target_cell

	global_position = board.grid_to_world(
		grid_position
	)

	# Logic turn sudah selesai.
	board.commit_turn()

	# Mulai animasi visual Player.
	sprite.global_position = old_world_position

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


func is_moving() -> bool:
	return move_tween != null and move_tween.is_running()

# Memindahkan Player langsung ke sebuah cell.
# Dipakai oleh sistem Undo / Reset.
func snap_to_cell(cell: Vector2i) -> void:
	if move_tween:
		move_tween.kill()

	grid_position = cell
	global_position = board.grid_to_world(grid_position)

	# Pastikan Sprite kembali menyatu dengan root Player.
	sprite.global_position = global_position
