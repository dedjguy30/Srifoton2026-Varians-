class_name ElytraCharacter
extends GridCharacter


# ==================================================
# SETTINGS
# ==================================================

# Waktu untuk meluncur satu tile.
const SLIDE_STEP_DURATION: float = 0.07


# ==================================================
# RUNTIME
# ==================================================

var is_sliding: bool = false

var slide_direction: Vector2i = Vector2i.ZERO

# Apakah selama slide ini Elytra sudah
# benar-benar berpindah minimal satu cell.
var slide_moved: bool = false


# ==================================================
# INPUT
# ==================================================

# Elytra memakai input sendiri supaya selama
# sedang meluncur tidak bisa dibelokkan.
func _physics_process(
	_delta: float
) -> void:
	if not is_alive:
		return

	if not is_active:
		return

	if board == null:
		return


	# ==================================================
	# CURRENTLY SLIDING
	# ==================================================

	# Selama Elytra masih meluncur:
	#
	# ↓ → ↑ ← semuanya diabaikan.
	#
	# Dia WAJIB terus ke arah awal sampai
	# bertemu sesuatu.
	if is_sliding:
		return


	# ==================================================
	# START NEW SLIDE
	# ==================================================

	var direction: Vector2i = (
		get_just_pressed_direction()
	)

	if direction == Vector2i.ZERO:
		return

	move_one_tile(
		direction
	)


# Hanya membaca input yang BARU ditekan.
#
# Bukan tombol yang sedang ditahan.
func get_just_pressed_direction() -> Vector2i:
	if Input.is_action_just_pressed(
		"ui_up"
	):
		return Vector2i.UP

	if Input.is_action_just_pressed(
		"ui_down"
	):
		return Vector2i.DOWN

	if Input.is_action_just_pressed(
		"ui_left"
	):
		return Vector2i.LEFT

	if Input.is_action_just_pressed(
		"ui_right"
	):
		return Vector2i.RIGHT

	return Vector2i.ZERO


# ==================================================
# START SLIDE
# ==================================================

# Override movement GridCharacter.
#
# Fungsi ini cuma MEMULAI slide.
# Movement selanjutnya diteruskan otomatis.
func move_one_tile(
	direction: Vector2i
) -> void:
	if board == null:
		return

	if not is_alive:
		return

	if is_sliding:
		return

	if direction == Vector2i.ZERO:
		return

	slide_direction = direction

	slide_moved = false

	is_sliding = true

	# Seluruh perjalanan Elytra adalah SATU TURN.
	board.begin_turn()

	print(
		"ELYTRA START SLIDE | ",
		name,
		" | Direction: ",
		slide_direction
	)

	_continue_slide()


# ==================================================
# CONTINUE SLIDE
# ==================================================

func _continue_slide() -> void:
	if board == null:
		_finish_slide()
		return


	# ==================================================
	# DIED DURING SLIDE
	# ==================================================

	if not is_alive:
		_finish_slide()
		return


	var next_cell: Vector2i = (
		grid_position
		+ slide_direction
	)

	var target_object = board.get_object_at(
		next_cell
	)


	# ==================================================
	# EMPTY CELL
	# ==================================================

	if target_object == null:
		_slide_one_step()
		return


	# ==================================================
	# BEETLE
	# ==================================================

	# Beetle tidak mati dan tidak terdorong.
	#
	# Elytra berhenti SATU TILE sebelumnya.
	if target_object is BeetleCharacter:
		print(
			"ELYTRA HIT BEETLE | ",
			name,
			" berhenti sebelum ",
			target_object.name
		)

		_finish_slide()
		return


	# ==================================================
	# ELYTRA VS ELYTRA
	# ==================================================

	# Belum menentukan mechanic final.
	# Untuk sekarang menjadi blocker.
	if target_object is ElytraCharacter:
		print(
			"ELYTRA HIT ELYTRA | Stop."
		)

		_finish_slide()
		return


	# ==================================================
	# FRIENDLY CHARACTER
	# ==================================================

	if target_object is GridCharacter:
		var character := (
			target_object
			as GridCharacter
		)

		if not character.is_alive:
			_finish_slide()
			return


		print(
			"ELYTRA HIT CHARACTER | ",
			name,
			" → ",
			character.name
		)


		# Character selain Beetle mati.
		var defeated: bool = (
			character.defeat()
		)

		if not defeated:
			_finish_slide()
			return


		# Character sudah unregister dari Board.
		# Elytra masuk ke cell bekas Character.
		_slide_one_step(
			true
		)

		return


	# ==================================================
	# ENEMY
	# ==================================================

	if target_object is GridEnemy:
		var enemy := (
			target_object
			as GridEnemy
		)

		if not enemy.is_alive:
			_finish_slide()
			return


		print(
			"ELYTRA HIT ENEMY | ",
			name,
			" → ",
			enemy.name
		)


		# Enemy mati.
		var defeated_enemy: bool = (
			enemy.defeat()
		)

		if not defeated_enemy:
			_finish_slide()
			return


		# Masuk ke cell bekas Enemy.
		# Setelah itu STOP.
		_slide_one_step(
			true
		)

		return


	# ==================================================
	# WALL / BOX / CLOSED DOOR / BLOCKER
	# ==================================================

	print(
		"ELYTRA HIT BLOCKER | ",
		target_object.name
	)

	_finish_slide()


# ==================================================
# MOVE ONE TILE
# ==================================================

# stop_after_step:
#
# false:
# setelah tween selesai, terus meluncur.
#
# true:
# setelah tween selesai, slide selesai.
#
# Dipakai ketika Elytra menghantam
# Character atau Enemy.
func _slide_one_step(
	stop_after_step: bool = false
) -> void:
	if board == null:
		_finish_slide()
		return

	if not is_alive:
		_finish_slide()
		return


	var target_cell: Vector2i = (
		grid_position
		+ slide_direction
	)


	# Cell harus sudah kosong.
	if board.is_occupied(
		target_cell
	):
		_finish_slide()
		return


	# ==================================================
	# VISUAL START
	# ==================================================

	var old_visual_position: Vector2 = (
		sprite.global_position
	)


	# ==================================================
	# LOGICAL MOVE
	# ==================================================

	var success: bool = board.move_object(
		grid_position,
		target_cell,
		self
	)

	if not success:
		_finish_slide()
		return


	grid_position = target_cell

	global_position = board.grid_to_world(
		grid_position
	)

	slide_moved = true


	# ==================================================
	# HAZARD MAY HAVE KILLED ELYTRA
	# ==================================================

	# board.move_object() emit object_moved.
	#
	# Jadi Spike / Pit bisa membunuh Elytra
	# SEBELUM kita sampai sini.
	if not is_alive:
		_finish_slide()
		return


	# ==================================================
	# VISUAL TWEEN
	# ==================================================

	if move_tween:
		move_tween.kill()


	# Root sudah pindah ke cell baru.
	#
	# Sprite dikembalikan ke posisi visual lama
	# lalu bergerak satu tile.
	sprite.global_position = (
		old_visual_position
	)


	move_tween = create_tween()

	move_tween.set_process_mode(
		Tween.TWEEN_PROCESS_PHYSICS
	)

	move_tween.tween_property(
		sprite,
		"global_position",
		global_position,
		SLIDE_STEP_DURATION
	).set_trans(
		Tween.TRANS_LINEAR
	)


	# ==================================================
	# AFTER ONE TILE
	# ==================================================

	if stop_after_step:
		move_tween.finished.connect(
			_finish_slide
		)

	else:
		move_tween.finished.connect(
			_continue_slide
		)


# ==================================================
# FINISH SLIDE
# ==================================================

func _finish_slide() -> void:
	if not is_sliding:
		return


	is_sliding = false

	slide_direction = Vector2i.ZERO


	# ==================================================
	# TURN RESULT
	# ==================================================

	if slide_moved:
		# Semua tile yang dilewati,
		# kill dan hazard adalah SATU turn.
		board.commit_turn()

	else:
		# Kalau blocker tepat di depan
		# dan Elytra tidak bergerak sama sekali,
		# jangan buat turn palsu.
		board.cancel_turn()


	slide_moved = false


	print(
		"ELYTRA STOP | ",
		name,
		" | Cell: ",
		grid_position
	)


# ==================================================
# MOVEMENT STATE
# ==================================================

# Override supaya Level juga tahu Elytra
# masih bergerak walaupun sedang berada
# di sela-sela tween tile.
func is_moving() -> bool:
	if is_sliding:
		return true

	return (
		move_tween != null
		and move_tween.is_running()
	)
